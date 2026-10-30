"""고객 주문 조회 및 상품 결제(장바구니 등록 여부와 무관)."""
from fastapi import APIRouter, Query, HTTPException
from pydantic import BaseModel, Field, ConfigDict, model_validator
from enum import Enum
from decimal import Decimal
import logging
import pymysql
import re

from database import get_connection
from services.customer.point_service import MAX_POINTS, change_points, purchase_points

router = APIRouter(tags=["주문 관리"])

logger = logging.getLogger(__name__)

class SaleOption(str, Enum):
    NORMAL = "NORMAL"
    NEAR_EXPIRY = "NEAR_EXPIRY"


class CheckoutItem(BaseModel):
    model_config = ConfigDict(extra="forbid")
    cosmetic_id: str = Field(min_length=1, max_length=160)
    quantity: int = Field(gt=0, le=10000)
    sale_option: SaleOption = Field(description="NORMAL: 일반 / NEAR_EXPIRY: 사용기한 임박")


class CheckoutRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    customer_id: str = Field(min_length=1, max_length=64)
    shipping_address: str = Field(min_length=1, max_length=500)
    shipping_recipient: str | None = Field(default=None, min_length=1, max_length=100)
    shipping_phone: str | None = Field(default=None, min_length=1, max_length=30)
    delivery_request: str | None = Field(default=None, max_length=200)
    points_to_use: int = Field(default=0, strict=True, ge=0, le=MAX_POINTS)
    items: list[CheckoutItem] = Field(min_length=1)

    @model_validator(mode="after")
    def validate_items(self):
        keys = [item.cosmetic_id for item in self.items]
        if len(keys) != len(set(keys)):
            raise ValueError("동일 화장품이 중복되었습니다. 상품별 수량을 하나로 합쳐주세요.")
        if not self.shipping_address.strip():
            raise ValueError("배송지 주소를 입력해야 합니다.")
        if self.shipping_recipient is not None and not self.shipping_recipient.strip():
            raise ValueError('수령인을 입력해 주세요.')
        if self.shipping_phone is not None and (
            not re.fullmatch(r'\+?[0-9\s()-]+', self.shipping_phone.strip())
            or len(re.sub(r'\D', '', self.shipping_phone)) < 7
        ):
            raise ValueError('수령인 연락처를 확인해 주세요.')
        return self



def next_sequence(cursor, scope_name):
    """호출자의 DB 트랜잭션 안에서 순번을 할당합니다."""
    cursor.execute(
        """INSERT INTO id_counters (scope_name, `last_value`)
           VALUES (%s, LAST_INSERT_ID(1))
           ON DUPLICATE KEY UPDATE
               `last_value` = LAST_INSERT_ID(`last_value` + 1)""",
        (scope_name,),
    )
    cursor.execute("SELECT LAST_INSERT_ID() AS seq")
    return cursor.fetchone()["seq"]


def get_account_status(cursor, customer_id):
    cursor.execute(
        """SELECT account_status FROM customer_account_status_history
           WHERE customer_id = %s ORDER BY changed_on DESC,
           CAST(SUBSTRING(status_history_id, 5) AS UNSIGNED) DESC LIMIT 1""",
        (customer_id,),
    )
    row = cursor.fetchone()
    return row["account_status"] if row else "ACTIVE"



def checkout_cart(data: CheckoutRequest) -> dict:
    customer_id = data.customer_id.strip()
    address = data.shipping_address.strip()
    conn = None
    try:
        conn = get_connection()
        conn.begin()
        with conn.cursor() as cur:
            # 고객 행을 장바구니 변경 및 동일 고객의 중복 결제에 대한 직렬화 지점으로 사용.
            cur.execute(
                "SELECT customer_id, points_balance, customer_name, phone FROM customers WHERE customer_id = %s FOR UPDATE",
                (customer_id,),
            )
            buyer = cur.fetchone()
            if buyer is None:
                raise HTTPException(404, "존재하지 않는 고객입니다.")
            recipient = data.shipping_recipient.strip() if data.shipping_recipient is not None else buyer.get('customer_name')
            phone = data.shipping_phone.strip() if data.shipping_phone is not None else buyer.get('phone')
            delivery_request = (data.delivery_request or '').strip()
            if get_account_status(cur, customer_id) != "ACTIVE":
                raise HTTPException(409, "활성 고객만 결제할 수 있습니다.")

            cur.execute(
                """SELECT cosmetic_id FROM cart_items
                   WHERE customer_id = %s ORDER BY cosmetic_id FOR UPDATE""",
                (customer_id,),
            )
            cart_ids = {row["cosmetic_id"] for row in cur.fetchall()}
            selected_ids = {item.cosmetic_id for item in data.items}
            # 장바구니 외의 상품도 바로 구매할 수 있다.
            # 결제 성공 시 실제 장바구니에 있는 주문 상품만 삭제한다.
            cart_purchased_ids = sorted(cart_ids & selected_ids)

            # 상품별 가격·판매상태를 DB에서 확인. 입력 가격은 신뢰하지 않는다.
            products = {}
            for cosmetic_id in sorted(selected_ids):
                cur.execute(
                    """SELECT c.cosmetic_name,
                           (SELECT sh.sale_status
                              FROM cosmetic_sale_status_history AS sh
                             WHERE sh.cosmetic_id = c.cosmetic_id
                             ORDER BY sh.changed_on DESC,
                                      CAST(SUBSTRING_INDEX(sh.change_id, '_', -1) AS UNSIGNED) DESC
                             LIMIT 1) AS sale_status,
                           (SELECT ph.sale_price
                              FROM cosmetic_price_history AS ph
                             WHERE ph.cosmetic_id = c.cosmetic_id
                             ORDER BY ph.changed_on DESC,
                                      CAST(SUBSTRING_INDEX(ph.change_id, '_', -1) AS UNSIGNED) DESC
                             LIMIT 1) AS sale_price
                       FROM cosmetics AS c WHERE c.cosmetic_id = %s FOR UPDATE""",
                    (cosmetic_id,),
                )
                product = cur.fetchone()
                if not product or product["sale_status"] != "ON_SALE" or product["sale_price"] is None:
                    raise HTTPException(409, f"판매할 수 없는 화장품: {cosmetic_id}")
                price = Decimal(str(product["sale_price"]))
                if price < 0:
                    raise HTTPException(409, f"상품 가격이 올바르지 않습니다: {cosmetic_id}")
                products[cosmetic_id] = (product["cosmetic_name"], price)

            # 포인트는 기존 보유 잔액과 서버가 계산한 상품 금액까지만 사용한다.
            goods_amount = sum((products[item.cosmetic_id][1] * item.quantity for item in data.items), Decimal('0'))
            used_points = data.points_to_use
            if used_points > int(buyer.get('points_balance') or 0):
                raise HTTPException(409, '보유 포인트가 부족합니다. 잔액을 다시 확인해 주세요.')
            if used_points > goods_amount:
                raise HTTPException(409, '포인트는 상품 금액을 초과해 사용할 수 없습니다.')

            # 1. orders 생성 -> 이후 order_items에 order_id + seq 사용.
            order_seq = int(next_sequence(cur, "order"))
            order_id = f"ord_{order_seq}"
            cur.execute(
                """INSERT INTO orders
                   (order_id, customer_id, order_seq, order_status, shipping_address,
                    shipping_recipient, shipping_phone, delivery_request, used_points)
                   VALUES (%s, %s, %s, 'PAID', %s, %s, %s, %s, %s)""",
                (order_id, customer_id, order_seq, address, recipient, phone, delivery_request, used_points),
            )

            total = Decimal("0")
            earned_points = 0
            seq = 0
            purchased = []

            # 인벤토리 잠금 순서를 일정하게 유지해 동시 고객 결제 충돌을 최소화한다.
            for item in sorted(data.items, key=lambda x: x.cosmetic_id):
                option = item.sale_option.value
                name, price = products[item.cosmetic_id]
                cur.execute(
                    """SELECT inventory_id, stock_quantity
                         FROM product_inventory
                        WHERE cosmetic_id = %s AND sale_option = %s
                          AND inventory_status = 'MAINTAIN'
                          AND stock_quantity > 0
                          AND (expires_on IS NULL OR expires_on >= CURRENT_DATE())
                        ORDER BY expires_on IS NULL, expires_on, received_on, inventory_id
                        FOR UPDATE""",
                    (item.cosmetic_id, option),
                )
                batches = cur.fetchall()
                if sum(int(row["stock_quantity"]) for row in batches) < item.quantity:
                    raise HTTPException(
                        409, f"재고 부족: {item.cosmetic_id} ({option})"
                    )

                remaining = item.quantity
                for batch in batches:
                    if remaining == 0:
                        break
                    count = min(remaining, int(batch["stock_quantity"]))
                    if count <= 0:
                        continue
                    inv_id = batch["inventory_id"]
                    cur.execute(
                        """UPDATE product_inventory
                              SET stock_quantity = stock_quantity - %s
                            WHERE inventory_id = %s AND stock_quantity >= %s
                              AND inventory_status = 'MAINTAIN'""",
                        (count, inv_id, count),
                    )
                    if cur.rowcount != 1:
                        raise HTTPException(409, "결제 도중 재고가 변경되었습니다.")

                    seq += 1
                    order_item_id = f"{order_id}_{seq}"
                    total += price * count
                    line_points = purchase_points(max(Decimal('0'), total - used_points)) - earned_points
                    earned_points += line_points
                    cur.execute(
                        """INSERT INTO order_items
                           (order_item_id, order_id, order_item_seq, inventory_id,
                            purchase_quantity, purchase_unit_price, sale_option, earned_points)
                           VALUES (%s, %s, %s, %s, %s, %s, %s, %s)""",
                        (order_item_id, order_id, seq, inv_id, count, price, option, line_points),
                    )
                    cur.execute('''INSERT INTO stock_outbounds
                        (order_item_id, inventory_id, delivery_id, outbound_quantity, outbound_on)
                        VALUES (%s, %s, NULL, %s, NULL)''', (order_item_id, inv_id, count))
                    remaining -= count
                    purchased.append({
                        "order_item_id": order_item_id,
                        "cosmetic_id": item.cosmetic_id,
                        "cosmetic_name": name,
                        "inventory_id": inv_id,
                        "quantity": count,
                        "sale_option": option,
                        "unit_price": price,
                        "earned_points": line_points,
                    })

            # 먼저 사용 포인트를 차감한 뒤 실제 결제 금액의 10%를 적립한다.
            change_points(cur, customer_id, order_id, -used_points, event='USE')
            change_points(cur, customer_id, order_id, earned_points)

            # 2. 결제 성공 시 주문한 상품 중 장바구니에 있던 상품만 삭제.
            # 주문 생성·재고 차감·장바구니 삭제는 동일 트랜잭션에서 처리한다.
            if cart_purchased_ids:
                placeholders = ", ".join(["%s"] * len(cart_purchased_ids))
                cur.execute(
                    f"DELETE FROM cart_items WHERE customer_id = %s "
                    f"AND cosmetic_id IN ({placeholders})",
                    (customer_id, *cart_purchased_ids),
                )
                if cur.rowcount != len(cart_purchased_ids):
                    raise HTTPException(409, "장바구니가 변경되어 결제를 완료할 수 없습니다.")

        conn.commit()
        return {
            "result": "OK", "order_id": order_id,
            "customer_id": customer_id, "order_status": "PAID",
            "shipping_address": address, "total_amount": total,
            "shipping_recipient": recipient, "shipping_phone": phone,
            "delivery_request": delivery_request,
            "earned_points": earned_points,
            "used_points": used_points,
            "payment_amount": total - used_points,
            "points_balance": int(buyer.get('points_balance') or 0) - used_points + earned_points,
            "items": purchased,
            "cart_cleared": len(cart_ids - selected_ids) == 0,
            "cart_removed_cosmetic_ids": cart_purchased_ids,
            "payment_note": "결제 완료 상태 저장(외부 결제 승인 연동 없음)",
        }
    except HTTPException:
        if conn is not None:
            conn.rollback()
        raise
    
    except pymysql.MySQLError as exc:
        if conn is not None:
            conn.rollback()

        logger.exception("결제 SQL 실패: customer_id=%s", customer_id)

        raise HTTPException(
            status_code=500,
            detail="결제 처리 중 DB 오류가 발생했습니다.",
        ) from exc

    except Exception:
        if conn is not None:
            conn.rollback()

        logger.exception("결제 실패: customer_id=%s", customer_id)
        raise

    finally:
        if conn is not None:
            conn.close()






@router.get("/orders", summary="고객별 주문 및 주문상품 조회")
def get_orders(customer_id: str = Query(..., min_length=1, max_length=64)):
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute(
                """SELECT o.order_id, o.ordered_at AS order_date,
                          o.customer_id, o.shipping_address, o.order_status,
                          o.shipping_recipient, o.shipping_phone, o.delivery_request,
                          o.used_points,
                          oi.order_item_id, oi.order_item_seq,
                          c.cosmetic_id, c.cosmetic_name AS product_name,
                          oi.inventory_id, oi.sale_option,
                          oi.purchase_quantity AS quantity,
                          oi.earned_points,
                          oi.purchase_unit_price AS unit_price,
                          oi.purchase_quantity * oi.purchase_unit_price AS item_amount,
                          (SELECT SUM(x.purchase_quantity * x.purchase_unit_price)
                             FROM order_items AS x WHERE x.order_id = o.order_id)
                             AS order_total_amount,
                          so.delivery_id, so.outbound_on
                     FROM orders AS o
                     LEFT JOIN order_items AS oi ON oi.order_id = o.order_id
                     LEFT JOIN product_inventory AS pi ON pi.inventory_id = oi.inventory_id
                     LEFT JOIN cosmetics AS c ON c.cosmetic_id = pi.cosmetic_id
                     LEFT JOIN stock_outbounds AS so ON so.order_item_id = oi.order_item_id
                    WHERE o.customer_id = %s
                    ORDER BY o.order_seq DESC, oi.order_item_seq""",
                (customer_id,),
            )
            return {"results": cur.fetchall()}
    finally:
        conn.close()


@router.post("/orders_pay", summary="상품 결제 및 주문 생성")
def order_pay(data: CheckoutRequest):
    """요청한 상품을 결제하고 장바구니에 있던 구매 상품만 제거."""
    return checkout_cart(data)

# 기존 main.py가 routers.customer.order만 등록한 경우에도 취소 API 사용 가능.
# main.py에서 order_item.router를 별도 등록하지 마세요(중복 경로 방지).
from routers.customer.order_item import router as order_item_router
router.include_router(order_item_router)
