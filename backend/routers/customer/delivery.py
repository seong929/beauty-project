from fastapi import APIRouter, HTTPException, Query

from database import get_connection

router = APIRouter(tags=["고객 배송 조회"])


# 고객별 배송 조회
@router.get("/customer_delivery_select", summary="고객 배송 조회")
def customer_delivery_select(
    customer_id: str = Query(..., min_length=1, max_length=64, pattern=r"\S"),
    order_id: str | None = Query(None, min_length=1, max_length=48, pattern=r"\S"),
    delivery_id: str | None = Query(None, min_length=1, max_length=80, pattern=r"\S"),
):
    conn = get_connection()
    try:
        with conn.cursor() as curs:
            sql = """
                SELECT o.customer_id,
                    o.order_id,
                    o.order_status,
                    o.ordered_at,
                    o.shipping_address,
                    d.delivery_id,
                    d.delivery_status,
                    d.shipped_at,
                    d.arrived_at,
                    c.carrier_name,
                    c.phone AS carrier_phone,
                    CASE
                        WHEN d.delivery_id IS NULL THEN '배송 정보 등록 전'
                        ELSE NULL
                    END AS delivery_message
                FROM orders AS o
                LEFT JOIN delivery_information AS d ON d.order_id = o.order_id
                LEFT JOIN carriers AS c ON c.carrier_id = d.carrier_id
                WHERE o.customer_id = %s
            """
            params = [customer_id]

            if order_id is not None:
                sql += " AND o.order_id = %s"
                params.append(order_id)
            if delivery_id is not None:
                sql += " AND d.delivery_id = %s"
                params.append(delivery_id)
            sql += " ORDER BY o.ordered_at DESC, o.order_id DESC, d.shipped_at DESC, d.delivery_id DESC"

            curs.execute(sql, tuple(params))
            rows = curs.fetchall()
            if not rows and (order_id is not None or delivery_id is not None):
                raise HTTPException(404, "해당 고객의 주문 또는 배송 정보를 찾을 수 없습니다.")
        return {"result": rows}
    finally:
        conn.close()
