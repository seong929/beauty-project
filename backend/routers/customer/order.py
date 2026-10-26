from fastapi import APIRouter, Form, HTTPException, Query

from database import get_connection
from services.customer.customer_service import get_account_status, next_sequence

router = APIRouter(tags=["주문 관리"])


# order.py의 주문 등록 흐름과 폼 이름을 유지하고 현재 스키마에 맞춰 이식.
@router.post("/orders", summary="고객 주문 등록")
def create_order(
    customer_id: str = Form(..., min_length=1, max_length=64, pattern=r"\S"),
    inventory_id: str = Form(..., min_length=1, max_length=280, pattern=r"\S"),
    quantity: int = Form(..., gt=0, le=4294967295),
):
    conn = None
    try:
        conn = get_connection()
        conn.begin()
        with conn.cursor() as curs:
            # ① 고객 확인: 탈퇴 API와 같은 고객 행을 잠근 뒤 최신 상태를 확인.
            curs.execute(
                """
                SELECT customer_id, customer_name, address
                FROM customers WHERE customer_id = %s FOR UPDATE
                """,
                (customer_id,),
            )
            customer = curs.fetchone()
            if customer is None or get_account_status(curs, customer_id) != "ACTIVE":
                raise HTTPException(404, "구매 가능한 고객정보가 없습니다.")
            if not customer["address"] or not customer["address"].strip():
                raise HTTPException(400, "배송지 주소를 먼저 등록하세요.")

            # ② 판매 가능한 재고 잠금. 가격/판매 상태는 각각의 최신 이력 사용.
            curs.execute(
                """
                SELECT i.inventory_id, i.sale_option, c.cosmetic_name AS product_name,
                    (
                        SELECT ph.sale_price FROM cosmetic_price_history AS ph
                        WHERE ph.cosmetic_id = i.cosmetic_id
                        ORDER BY ph.changed_on DESC,
                            CAST(SUBSTRING(ph.change_id, 5) AS UNSIGNED) DESC
                        LIMIT 1
                    ) AS sale_price,
                    (
                        SELECT sh.sale_status FROM cosmetic_sale_status_history AS sh
                        WHERE sh.cosmetic_id = i.cosmetic_id
                        ORDER BY sh.changed_on DESC,
                            CAST(SUBSTRING(sh.change_id, 5) AS UNSIGNED) DESC
                        LIMIT 1
                    ) AS sale_status
                FROM product_inventory AS i
                JOIN cosmetics AS c ON c.cosmetic_id = i.cosmetic_id
                WHERE i.inventory_id = %s
                  AND i.inventory_status = 'MAINTAIN'
                  AND (i.expires_on IS NULL OR i.expires_on > CURRENT_DATE())
                FOR UPDATE
                """,
                (inventory_id,),
            )
            product = curs.fetchone()
            if (product is None or product["sale_status"] != "ON_SALE"
                    or product["sale_price"] is None):
                raise HTTPException(400, "판매 가능한 상품 재고가 없습니다.")

            # ③ 현재 스키마에는 예약 수량이 없으므로 같은 트랜잭션에서 차감.
            curs.execute(
                """
                SELECT stock_quantity
                FROM product_inventory
                WHERE inventory_id = %s
                FOR UPDATE
                """,
                (inventory_id,),
            )
            stock = curs.fetchone()

            if stock is None or stock["stock_quantity"] < quantity:
                raise HTTPException(
                    status_code=409,
                    detail="구매 가능한 재고수량이 부족합니다.",
                )
            total_amount = product["sale_price"] * quantity

            # ④ 주문 등록: 전역 순번으로 ord_<순번> 발급.
            order_seq = next_sequence(curs, "order")
            order_id = f"ord_{order_seq}"
            curs.execute(
                """
                INSERT INTO orders (
                    order_id, customer_id, order_seq, order_status, shipping_address
                )
                VALUES (%s, %s, %s, 'PENDING', %s)
                """,
                (order_id, customer_id, order_seq, customer["address"]),
            )

            # ⑤ 주문상품 등록: 원본 API처럼 한 요청에서 재고 한 종류를 주문.
            curs.execute(
                """
                INSERT INTO order_items (
                    order_item_id, order_id, order_item_seq, inventory_id,
                    purchase_quantity, purchase_unit_price, sale_option
                )
                VALUES (%s, %s, 1, %s, %s, %s, %s)
                """,
                (f"{order_id}_1", order_id, inventory_id, quantity,
                 product["sale_price"], product["sale_option"]),
            )
        conn.commit()
        return {
            "result": "OK",
            "order_id": order_id,
            "customer_name": customer["customer_name"],
            "product_name": product["product_name"],
            "quantity": quantity,
            "total_amount": total_amount,
            "order_status": "PENDING",
        }
    except Exception:
        if conn is not None:
            conn.rollback()
        raise
    finally:
        if conn is not None:
            conn.close()


@router.get("/orders", summary="고객별 주문 조회")
def get_orders(
    customer_id: str = Query(..., min_length=1, max_length=64, pattern=r"\S"),
):
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
