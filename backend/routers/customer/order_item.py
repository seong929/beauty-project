"""고객 결제 주문의 배송 전 취소. 단품 주문 생성은 /orders_pay로 통합."""
from fastapi import APIRouter, Query, HTTPException
import logging
import pymysql
from database import get_connection
from services.customer.point_service import change_points

router = APIRouter(tags=["주문 관리"])
logger = logging.getLogger(__name__)
MAX_STOCK = 4294967295

def cancel_paid_order(customer_id: str, order_id: str) -> dict:
    conn = None
    try:
        conn = get_connection()
        conn.begin()
        with conn.cursor() as cur:
            # 배송도 동일 주문 행을 먼저 잠가 결제/출고/취소를 직렬화한다.
            cur.execute(
                """SELECT order_id, customer_id, order_status, used_points
                   FROM orders WHERE order_id = %s FOR UPDATE""",
                (order_id,),
            )
            order = cur.fetchone()
            if order is None:
                raise HTTPException(404, "존재하지 않는 주문입니다.")
            if order["customer_id"] != customer_id:
                raise HTTPException(403, "본인의 주문만 취소할 수 있습니다.")
            if order["order_status"] not in ("PAID",):
                raise HTTPException(409, "결제 완료(PAID) 및 배송 시작 전의 주문만 취소할 수 있습니다.")

            cur.execute(
                """SELECT delivery_id FROM delivery_information
                   WHERE order_id = %s LIMIT 1 FOR UPDATE""", (order_id,)
            )
            if cur.fetchone() is not None:
                raise HTTPException(409, "배송 정보가 등록된 주문은 취소할 수 없습니다.")

            cur.execute(
                """SELECT oi.order_item_id, oi.inventory_id, oi.purchase_quantity, oi.earned_points,
                          so.outbound_quantity, so.delivery_id, so.outbound_on
                     FROM order_items AS oi
                     LEFT JOIN stock_outbounds AS so
                       ON so.order_item_id = oi.order_item_id
                    WHERE oi.order_id = %s
                    ORDER BY oi.inventory_id, oi.order_item_seq FOR UPDATE""",
                (order_id,),
            )
            items = cur.fetchall()
            if not items:
                raise HTTPException(409, "주문 상품이 존재하지 않습니다.")
            for item in items:
                if (item["outbound_quantity"] is None
                        or item["delivery_id"] is not None
                        or item["outbound_on"] is not None
                        or int(item["outbound_quantity"]) != int(item["purchase_quantity"])):
                    raise HTTPException(409, "출고 예약 상태가 일치하지 않아 취소할 수 없습니다.")

            recovered_points = sum(int(item.get('earned_points') or 0) for item in items)
            restored_points = int(order.get('used_points') or 0)
            # 사용한 포인트를 먼저 돌려준 뒤 이 주문에서 적립한 포인트를 회수한다.
            change_points(cur, customer_id, order_id, restored_points, event='RESTORE')
            change_points(cur, customer_id, order_id, -recovered_points)
            restored = 0
            for item in items:
                quantity = int(item["purchase_quantity"])
                cur.execute(
                    """UPDATE product_inventory
                          SET stock_quantity = stock_quantity + %s
                        WHERE inventory_id = %s AND stock_quantity <= %s""",
                    (quantity, item["inventory_id"], MAX_STOCK - quantity),
                )
                if cur.rowcount != 1:
                    raise HTTPException(409, "재고 복구에 실패했습니다.")
                restored += quantity

            # 3. 주문 상품 기록은 보존하고 출고 예약 행만 삭제한다.
            cur.execute(
                """DELETE so FROM stock_outbounds AS so
                   JOIN order_items AS oi ON oi.order_item_id = so.order_item_id
                   WHERE oi.order_id = %s AND so.delivery_id IS NULL
                     AND so.outbound_on IS NULL""",
                (order_id,),
            )
            if cur.rowcount != len(items):
                raise HTTPException(409, "출고 예약 삭제 수량이 일치하지 않습니다.")
            cur.execute(
                """UPDATE orders SET order_status = 'CANCELLED'
                   WHERE order_id = %s AND order_status = 'PAID'""", (order_id,)
            )
            if cur.rowcount != 1:
                raise HTTPException(409, "주문 상태 변경에 실패했습니다.")

        conn.commit()
        return {
            "result": "OK", "order_id": order_id,
            "order_status": "CANCELLED", "restored_quantity": restored,
            "deleted_outbound_count": len(items),
            "recovered_points": recovered_points,
            "restored_points": restored_points,
        }
    except HTTPException:
        if conn is not None:
            conn.rollback()
        raise
    except pymysql.MySQLError:
        if conn is not None:
            conn.rollback()
        logger.exception("주문 취소 DB 실패: %s", order_id)
        raise HTTPException(500, "주문 취소 중 DB 오류가 발생했습니다.")
    except Exception:
        if conn is not None:
            conn.rollback()
        logger.exception("주문 취소 실패: %s", order_id)
        raise
    finally:
        if conn is not None:
            conn.close()



@router.post("/orders_cancel", summary="결제 완료 주문 취소·재고 복구·출고예약 삭제")
def cancel_order(
    order_id: str = Query(..., min_length=1, max_length=48),
    customer_id: str = Query(..., min_length=1, max_length=64),
):
    return cancel_paid_order(customer_id=customer_id, order_id=order_id)
