from decimal import Decimal

from fastapi import APIRouter, Form, HTTPException, Query

from database import get_connection
from services.customer.customer_service import get_account_status, next_sequence

router = APIRouter(tags=["주문 관리"])


@router.post("/orders",summary="선택한 상품 주문 생성")
def create_order(
    customer_id: str = Form(..., min_length=1, max_length=30),
    cosmetic_id: str = Form(..., min_length=1, max_length=100),
    quantity: int = Form(..., gt=0, le=100),
):
    conn = None
    try:
        conn = get_connection()
        conn.begin()
        with conn.cursor() as curs:
            #고객 번호 조회
            curs.execute(
                """
                SELECT customer_id, address
                FROM customers
                WHERE customer_id = %s
                FOR UPDATE
                """,
                (customer_id,),
            )
            customer = curs.fetchone()
            if customer is None:
                raise HTTPException(404, "존재하지 않는 고객입니다.")
            if get_account_status(curs, customer_id) != "ACTIVE":
                raise HTTPException(409, "주문 가능한 고객 상태가 아닙니다.")
            if not customer["address"] or not customer["address"].strip():
                raise HTTPException(400, "배송지 주소를 먼저 등록하세요.")

            #선택한 상품의 이름, 최신 판매 가격, 최신 판매 상태를 조회한다.
            curs.execute(
                """
                SELECT c.cosmetic_name AS product_name,
                    (
                        SELECT ph.sale_price
                        FROM cosmetic_price_history AS ph
                        WHERE ph.cosmetic_id = c.cosmetic_id
                        ORDER BY ph.changed_on DESC,
                            CAST(SUBSTRING_INDEX(ph.change_id, '_', -1) AS UNSIGNED) DESC
                        LIMIT 1
                    ) AS sale_price,
                    (
                        SELECT sh.sale_status
                        FROM cosmetic_sale_status_history AS sh
                        WHERE sh.cosmetic_id = c.cosmetic_id
                        ORDER BY sh.changed_on DESC,
                            CAST(SUBSTRING_INDEX(sh.change_id, '_', -1) AS UNSIGNED) DESC
                        LIMIT 1
                    ) AS sale_status
                FROM cosmetics AS c
                WHERE c.cosmetic_id = %s
                FOR UPDATE
                """,
                (cosmetic_id,),
            )
            product = curs.fetchone()
            if product is None:
                raise HTTPException(404, "존재하지 않는 상품입니다.")
            if product["sale_status"] != "ON_SALE" or product["sale_price"] is None:
                raise HTTPException(409, "현재 주문할 수 없는 상품입니다.")
            unit_price = Decimal(str(product["sale_price"]))
            if unit_price < 0:
                raise HTTPException(409, "상품 가격을 확인하세요.")

            # 선택한 상품의 구매 가능한 입고 재고를 조회
            curs.execute(
                """
                SELECT inventory_id, stock_quantity, sale_option
                FROM product_inventory
                WHERE cosmetic_id = %s
                AND inventory_status = 'MAINTAIN'
                AND stock_quantity > 0
                AND (expires_on IS NULL OR expires_on >= CURRENT_DATE())
                ORDER BY expires_on IS NULL, expires_on, received_on, inventory_id
                FOR UPDATE
                """,
                (cosmetic_id,),
            )
            inventories = curs.fetchall()
            if sum(int(item["stock_quantity"]) for item in inventories) < quantity:
                raise HTTPException(409, "구매 가능한 재고수량이 부족합니다.")

            order_seq = next_sequence(curs, "order")
            order_id = f"ord_{order_seq}"
            # 주문 번호, 고객 번호, 배송지를 저장
            curs.execute(
                """
                INSERT INTO orders (
                    order_id, customer_id, order_seq, order_status, shipping_address
                )
                VALUES (%s, %s, %s, 'PENDING', %s)
                """,
                (order_id, customer_id, order_seq, customer["address"]),
            )

            remaining = quantity
            for item_seq, inventory in enumerate(inventories, start=1):
                item_quantity = min(remaining, int(inventory["stock_quantity"]))
            #     # 이번 입고 재고에서 주문에 배정한 수량만큼 차감한다.
            #     # 남은 수량이 충분한 경우에만 갱신하여 음수 재고를 방지한다.
                curs.execute(
                    """
                    UPDATE product_inventory
                    SET stock_quantity = stock_quantity - %s
                    WHERE inventory_id = %s AND stock_quantity >= %s
                    """,
                    (item_quantity, inventory["inventory_id"], item_quantity),
                )
                if curs.rowcount != 1:
                    raise HTTPException(409, "재고가 변경되어 주문할 수 없습니다.")
                # 주문에 배정된 재고 번호, 구매 수량, 구매 당시 단가와
                # 판매 옵션을 order_items에 저장한다. 입고 재고별로 한 행씩 저장한다.
                curs.execute(
                    """
                    INSERT INTO order_items (
                        order_item_id, order_id, order_item_seq, inventory_id,
                        purchase_quantity, purchase_unit_price, sale_option
                    )
                    VALUES (%s, %s, %s, %s, %s, %s, %s)
                    """,
                    (
                        f"{order_id}_{item_seq}", order_id, item_seq,
                        inventory["inventory_id"], item_quantity, unit_price,
                        inventory["sale_option"],
                    ),
                )
                remaining -= item_quantity
                if remaining == 0:
                    break
        # 주문 저장과 재고 차감이 모두 성공했을 때만 DB에 반영한다.
        conn.commit()
        return {
            "result": "OK",
            "order_id": order_id,
            "customer_id": customer_id,
            "cosmetic_id": cosmetic_id,
            "product_name": product["product_name"],
            "quantity": quantity,
            "unit_price": unit_price,
            "total_amount": unit_price * quantity,
            "shipping_address": customer["address"],
            "order_status": "PENDING",
        }
    except Exception:
        if conn is not None:
            conn.rollback()
        raise
    finally:
        if conn is not None:
            conn.close()

# 고객 주문 취소
@router.post("/orders_cancel", summary="고객 주문 취소")
def cancel_order(
    order_id: str = Query(..., min_length=1, max_length=48, pattern=r"\S"),
    customer_id: str = Query(..., min_length=1, max_length=64, pattern=r"\S"),
):
    conn = None
    try:
        conn = get_connection()
        conn.begin()
        with conn.cursor() as curs:
            # 주문된 정보를 가져온다
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
                raise HTTPException(403, "본인의 주문만 취소할 수 있습니다.")
            if order["order_status"] not in ("PENDING", "PAID"):
                raise HTTPException(409, "결제 대기 또는 결제 완료 상태의 주문만 취소할 수 있습니다.")

            # 배송 정보가 등록된 주문인지 확인한다.
            curs.execute(
                """
                SELECT delivery_id
                FROM delivery_information
                WHERE order_id = %s
                LIMIT 1
                FOR UPDATE
                """,
                (order_id,),
            )
            if curs.fetchone() is not None:
                raise HTTPException(409, "배송 준비가 시작된 주문은 취소할 수 없습니다.")

            # 주문상품은 삭제하지 않고 취소 내역과 함께 보존한다.
            curs.execute(
                """
                SELECT inventory_id, purchase_quantity
                FROM order_items
                WHERE order_id = %s
                ORDER BY inventory_id, order_item_seq
                FOR UPDATE
                """,
                (order_id,),
            )
            items = curs.fetchall()
            if not items:
                raise HTTPException(409, "취소할 주문상품이 없습니다.")

            inventory_quantities = {}
            for item in items:
                inventory_id = item["inventory_id"]
                quantity = int(item["purchase_quantity"])
                if not inventory_id or quantity <= 0:
                    raise HTTPException(409, "주문상품의 재고 번호와 수량을 확인하세요.")
                inventory_quantities[inventory_id] = (
                    inventory_quantities.get(inventory_id, 0) + quantity
                )

            for inventory_id in sorted(inventory_quantities, key=str):
                quantity = inventory_quantities[inventory_id]
                if quantity > 4294967295:
                    raise HTTPException(409, "복구할 재고 수량이 허용 범위를 초과합니다.")
                
                # 제고 수량을 다시 돌려 놓는다.
                curs.execute(
                    """
                    UPDATE product_inventory
                    SET stock_quantity = stock_quantity + %s
                    WHERE inventory_id = %s AND stock_quantity <= %s
                    """,
                    (quantity, inventory_id, 4294967295 - quantity),
                )
                if curs.rowcount != 1:
                    raise HTTPException(409, "재고 복구에 실패하여 주문을 취소할 수 없습니다.")

            # 고객의 배송 상태 변경
            curs.execute(
                """
                UPDATE orders
                SET order_status = 'CANCELLED'
                WHERE order_id = %s AND customer_id = %s
                AND order_status IN ('PENDING', 'PAID')
                """,
                (order_id, customer_id),
            )
            if curs.rowcount != 1:
                raise HTTPException(409, "주문 상태가 변경되어 취소할 수 없습니다.")

        conn.commit()
        return {
            "result": "OK",
            "message": "주문이 취소되었습니다.",
            "order_id": order_id,
            "customer_id": customer_id,
            "order_status": "CANCELLED",
            "restored_quantity": sum(inventory_quantities.values()),
        }
    except Exception:
        if conn is not None:
            conn.rollback()
        raise
    finally:
        if conn is not None:
            conn.close()
