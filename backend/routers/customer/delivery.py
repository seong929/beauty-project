from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel, ConfigDict, Field, field_validator
import pymysql
import re

from database import get_connection

router = APIRouter(tags=["고객 배송 관리"])


class ShippingAddressUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)

    customer_id: str = Field(min_length=1, max_length=64)
    order_id: str = Field(min_length=1, max_length=48)
    shipping_address: str = Field(min_length=1, max_length=500)
    shipping_recipient: str | None = Field(default=None, min_length=1, max_length=100)
    shipping_phone: str | None = Field(default=None, min_length=1, max_length=30)
    delivery_request: str | None = Field(default=None, max_length=200)

    @field_validator("customer_id", "order_id", "shipping_address")
    @classmethod
    def reject_blank(cls, value):
        if not value.strip():
            raise ValueError("빈 값은 입력할 수 없습니다.")
        return value

    @field_validator('shipping_recipient', 'shipping_phone')
    @classmethod
    def validate_contact(cls, value, info):
        if value is None:
            return value
        if not value.strip():
            raise ValueError('수령인과 연락처를 입력해 주세요.')
        if info.field_name == 'shipping_phone' and (
            not re.fullmatch(r'\+?[0-9\s()-]+', value) or len(re.sub(r'\D', '', value)) < 7
        ):
            raise ValueError('수령인 연락처를 확인해 주세요.')
        return value


@router.put("/customer_delivery_update", summary="고객 주문 배송지 수정")
def customer_delivery_update(data: ShippingAddressUpdate):
    conn = None
    try:
        conn = get_connection()
        conn.begin()
        with conn.cursor() as curs:
            # 고객의 주문인지 확인하고 출고 처리와 동시에 수정되지 않도록 주문을 잠근다.
            curs.execute(
                """SELECT order_id, order_status FROM orders
                   WHERE order_id = %s AND customer_id = %s FOR UPDATE""",
                (data.order_id, data.customer_id),
            )
            order = curs.fetchone()
            if order is None:
                raise HTTPException(404, "해당 고객의 주문을 찾을 수 없습니다.")
            if order["order_status"] not in {"PENDING", "PAID", "PREPARING"}:
                raise HTTPException(409, "출고 전인 주문만 배송지를 변경할 수 있습니다.")

            # 배송 정보는 출고 시 생성되므로 등록된 배송 건이 하나라도 있으면 변경을 막는다.
            curs.execute(
                """SELECT delivery_id FROM delivery_information
                   WHERE order_id = %s LIMIT 1 FOR UPDATE""",
                (data.order_id,),
            )
            if curs.fetchone() is not None:
                raise HTTPException(409, "이미 출고 처리된 주문은 배송지를 변경할 수 없습니다.")

            # 회원 기본 주소가 아니라 선택한 주문의 배송 주소만 수정한다.
            curs.execute(
                """UPDATE orders SET shipping_address = %s,
                     shipping_recipient = COALESCE(%s, shipping_recipient),
                     shipping_phone = COALESCE(%s, shipping_phone),
                     delivery_request = COALESCE(%s, delivery_request)
                   WHERE order_id = %s AND customer_id = %s""",
                (data.shipping_address, data.shipping_recipient, data.shipping_phone,
                 data.delivery_request, data.order_id, data.customer_id),
            )
        conn.commit()
        return {
            "result": "OK", "order_id": data.order_id,
            "customer_id": data.customer_id,
            "shipping_address": data.shipping_address,
            **({"shipping_recipient": data.shipping_recipient} if data.shipping_recipient is not None else {}),
            **({"shipping_phone": data.shipping_phone} if data.shipping_phone is not None else {}),
            **({"delivery_request": data.delivery_request} if data.delivery_request is not None else {}),
            "message": "주문 배송지를 변경했습니다.",
        }
    except HTTPException:
        if conn is not None:
            conn.rollback()
        raise
    except pymysql.MySQLError:
        if conn is not None:
            conn.rollback()
        raise HTTPException(503, "배송지 변경을 처리하지 못했습니다. 다시 조회해 주세요.") from None
    finally:
        if conn is not None:
            conn.close()


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
                    o.shipping_recipient,
                    o.shipping_phone,
                    o.delivery_request,
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
