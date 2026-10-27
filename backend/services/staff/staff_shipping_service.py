"""PREPARING -> SHIPPED 주문 전환과 주문 품목 재고 차감을 원자적으로 수행."""
import logging

import pymysql
from fastapi import HTTPException
from database import get_connection

logger = logging.getLogger(__name__)


def ship_order_and_decrease_stock(order_id: str) -> dict:
    """모든 주문 항목의 수량만큼 재고 차감. 실패 시 주문/재고 전부 rollback."""
    if not order_id or not order_id.strip():
        raise HTTPException(status_code=400, detail="주문 번호를 입력해야 합니다.")

    try:
        conn = get_connection()
    except pymysql.MySQLError:
        logger.exception("출고 처리: DB 연결 실패")
        raise HTTPException(status_code=503, detail="데이터베이스 연결에 실패했습니다.")

    try:
        # get_connection()은 autocommit=False. 여기서 하나의 트랜잭션 시작.
        with conn.cursor() as cursor:
            # 동일 주문 동시 출고 직렬화
            cursor.execute(
                "SELECT order_status FROM orders WHERE order_id = %s FOR UPDATE",
                (order_id,),
            )
            order = cursor.fetchone()
            if order is None:
                raise HTTPException(status_code=404, detail="존재하지 않는 주문입니다.")
            if order["order_status"] != "PREPARING":
                raise HTTPException(
                    status_code=409,
                    detail="PREPARING 상태의 주문만 출고할 수 있습니다.",
                )

            # 잠긴 주문의 상품을 읽고 동일 재고 묶음을 합산
            cursor.execute(
                """
                SELECT inventory_id, SUM(purchase_quantity) AS quantity
                FROM order_items
                WHERE order_id = %s
                GROUP BY inventory_id
                ORDER BY inventory_id
                """,
                (order_id,),
            )
            items = cursor.fetchall()
            if not items:
                raise HTTPException(status_code=409, detail="출고할 주문 상품이 없습니다.")

            deductions = []
            # 모든 작업이 같은 트랜잭션. 정렬된 재고 잠금으로 데드락 위험 감소.
            for item in items:
                inventory_id = item["inventory_id"]
                quantity = int(item["quantity"])
                if quantity <= 0:
                    raise HTTPException(status_code=409, detail="올바르지 않은 주문 수량입니다.")

                cursor.execute(
                    """
                    SELECT stock_quantity, inventory_status
                    FROM product_inventory
                    WHERE inventory_id = %s
                    FOR UPDATE
                    """,
                    (inventory_id,),
                )
                stock = cursor.fetchone()
                if stock is None:
                    raise HTTPException(
                        status_code=409,
                        detail=f"재고가 존재하지 않습니다: {inventory_id}",
                    )
                if stock["inventory_status"] != "MAINTAIN":
                    raise HTTPException(
                        status_code=409,
                        detail=f"출고할 수 없는 재고 상태입니다: {inventory_id}",
                    )
                if int(stock["stock_quantity"]) < quantity:
                    raise HTTPException(
                        status_code=409,
                        detail=f"출고 재고가 부족합니다: {inventory_id}",
                    )

                cursor.execute(
                    """
                    UPDATE product_inventory
                    SET stock_quantity = stock_quantity - %s
                    WHERE inventory_id = %s
                      AND inventory_status = 'MAINTAIN'
                      AND stock_quantity >= %s
                    """,
                    (quantity, inventory_id, quantity),
                )
                if cursor.rowcount != 1:
                    raise HTTPException(
                        status_code=409, detail=f"재고 차감에 실패했습니다: {inventory_id}"
                    )
                deductions.append({"inventory_id": inventory_id, "quantity": quantity})

            # 재고 차감 완료 시에만 주문 상태 변경. 하나라도 실패하면 전체 rollback.
            cursor.execute(
                """
                UPDATE orders SET order_status = 'SHIPPED'
                WHERE order_id = %s AND order_status = 'PREPARING'
                """,
                (order_id,),
            )
            if cursor.rowcount != 1:
                raise HTTPException(status_code=409, detail="주문 상태 변경에 실패했습니다.")

        conn.commit()
        return {
            "order_id": order_id,
            "previous_status": "PREPARING",
            "order_status": "SHIPPED",
            "deductions": deductions,
            "message": "주문 출고 및 재고 차감이 완료되었습니다.",
        }
    except HTTPException:
        conn.rollback()
        raise
    except pymysql.MySQLError:
        conn.rollback()
        logger.exception("주문 출고 SQL 실패: order_id=%s", order_id)
        raise HTTPException(status_code=500, detail="출고 처리 중 데이터베이스 오류가 발생했습니다.")
    except Exception:
        conn.rollback()
        logger.exception("주문 출고 예상치 못한 실패: order_id=%s", order_id)
        raise HTTPException(status_code=500, detail="출고 처리 중 서버 오류가 발생했습니다.")
    finally:
        conn.close()
