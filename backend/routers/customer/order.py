from fastapi import APIRouter, Form, HTTPException, Query

from database import get_connection
from services.customer.customer_service import get_account_status, next_sequence

router = APIRouter(tags=["주문 관리"])


# 고객 주문 내역 조회
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
