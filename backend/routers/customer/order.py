from decimal import Decimal

from fastapi import APIRouter, HTTPException, Query
from database import get_connection

router = APIRouter(tags=["주문 관리"])

# 고객별 주문 조회
@router.get("/orders", summary="고객별 주문 조회")
def get_orders(customer_id: str):
    
    conn = get_connection()
    
    try:
        
        with conn.cursor() as curs:
            curs.execute(
                """
                SELECT o.order_id, o.ordered_at AS order_date,
                    c.customer_id, c.customer_name,
                    p.cosmetic_name AS product_name, oi.inventory_id,
                    oi.purchase_quantity AS quantity,
                    oi.purchase_unit_price AS unit_price,
                       oi.purchase_quantity * oi.purchase_unit_price AS item_amount,
                    (
                        SELECT SUM(items.purchase_quantity * items.purchase_unit_price)
                        FROM order_items AS items WHERE items.order_id = o.order_id
                    ) AS order_total_amount,
                    o.order_status
                FROM orders AS o
                JOIN customers AS c ON c.customer_id = o.customer_id
                JOIN order_items AS oi ON oi.order_id = o.order_id
                JOIN product_inventory AS i ON i.inventory_id = oi.inventory_id
                JOIN cosmetics AS p ON p.cosmetic_id = i.cosmetic_id
                WHERE o.customer_id = %s
                ORDER BY o.ordered_at DESC, o.order_seq DESC, oi.order_item_seq
                """,
                (customer_id,),
            )
            rows = curs.fetchall()
        return {"results": rows}
    finally:
        conn.close()
        


# 고객별 주문 결제
@router.post("/orders_pay", summary="주문 결제")
def order_pay(
    order_id: str = Query(..., min_length=1, max_length=30),
    customer_id: str = Query(..., min_length=1, max_length=30),
):
    conn = None
    try:
        conn = get_connection()
        conn.begin()
        with conn.cursor() as curs:
            # 주문 조회 및 동시 처리 방지를 위한 잠금
            curs.execute(
                """
                SELECT order_id, customer_id, order_status
                FROM orders
                WHERE order_id = %s
                FOR UPDATE
                """,
                (order_id,),
            )
            order = curs.fetchone()
            if order is None:
                raise HTTPException(404, "존재하지 않는 주문입니다.")
            if str(order["customer_id"]) != customer_id:
                raise HTTPException(403, "본인의 주문만 결제할 수 있습니다.")
            if order["order_status"] != "PENDING":
                raise HTTPException(409, "결제 대기 중인 주문만 결제할 수 있습니다.")

            # 주문한 결제금액한 표기
            curs.execute(
                """
                SELECT
                    purchase_quantity,
                    purchase_unit_price
                FROM order_items
                WHERE order_id = %s
                FOR UPDATE
                """,
                (order_id,),
            )
            items = curs.fetchall()
            if not items:
                raise HTTPException(409, "주문에 포함된 상품이 없습니다.")

            total_amount = Decimal("0")
            for item in items:
                quantity = int(item["purchase_quantity"])
                unit_price = Decimal(str(item["purchase_unit_price"]))
                if quantity <= 0 or unit_price < 0:
                    raise HTTPException(409, "주문 상품의 수량과 가격을 확인하세요.")
                total_amount += quantity * unit_price

            # 이미 처리된 주문은 다시 결제할 수 없도록 상태 조건을 함께 적용한다.
            curs.execute(
                """
                UPDATE orders
                SET order_status = 'PAID'
                WHERE order_id = %s
                  AND order_status = 'PENDING'
                """,
                (order_id,),
            )
            if curs.rowcount != 1:
                raise HTTPException(409, "주문 상태가 변경되어 결제할 수 없습니다.")

        # 결제 완료 상태를 저장한다.
        conn.commit()
        return {
            "result": "OK",
            "order_id": order_id,
            "customer_id": customer_id,
            "order_status": "PAID",
            "total_amount": total_amount,
            "payment_amount": total_amount,
        }
    except Exception:
        if conn is not None:
            conn.rollback()
        raise
    finally:
        if conn is not None:
            conn.close()
