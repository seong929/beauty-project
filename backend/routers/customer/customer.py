from fastapi import APIRouter, Form, HTTPException, Query
import pymysql
from pwdlib import PasswordHash

from database import get_connection
from services.customer.customer_service import (
    append_account_status,
    get_account_status,
    next_sequence,
)

router = APIRouter(tags=["고객"])
password_hasher = PasswordHash.recommended()


@router.get("/customer/test")
def delivery_test():
    return {"message": "고객 API 연결 성공"}


# 고객 등록(회원 가입)
@router.post("/customers_upload", tags=["고객 관리"], summary="고객 등록")
def customeres_upload(
    login_id: str = Form(..., ),
    password: str = Form(..., ),
    customer_name: str = Form(...,),
    email: str = Form(...,),
    address: str = Form(...,),
    phone_number: str = Form("",)
    ):

    try:
        hashed_password = password_hasher.hash(password)
        conn = get_connection()

        with conn.cursor() as curs:
            sql = """
                INSERT INTO customers (
                    login_id,
                    password_hash,
                    customer_name,
                    email,
                    address,
                    phone_number
                )
                VALUES (%s, %s, %s, %s, %s, %s)
            """

            curs.execute(sql, (
                login_id,
                hashed_password,
                customer_name,
                email,
                address,
                phone_number or None,
            ))

            customer_id = curs.lastrowid

        conn.commit()
        conn.close()

        return {
            "result": "OK",
            "customer_id": customer_id,
            "customer_name": customer_name,
        }

    except Exception as e:
        return {'result' : 'Error'}
    
    
# 고객 정보 조회
@router.get("/customers_select", tags=["고객 조회"], summary="고객 조회")
def customers_select():
    conn = get_connection()
    try:
        with conn.cursor() as curs:
            curs.execute(
                """
                SELECT customer_id,
                    customer_name,
                    phone AS phone_number,
                    address
                FROM customers
                ORDER BY customer_id
                """
            )
            rows = curs.fetchall()
        return {"result": rows}
    finally:
        conn.close()


# 고객 정보 수정
@router.put("/customers_update", tags=["고객 관리"], summary="고객 정보 수정")
def customer_update(
    customer_id: str = Query(..., min_length=1, max_length=64, pattern=r"\S"),
    customer_name: str = Form(..., min_length=1, max_length=100),
    email: str = Form(..., min_length=1, max_length=255),
    address: str = Form(..., min_length=1, max_length=500),
    phone_number: str = Form(..., min_length=1, max_length=30),
):
    conn = None
    try:
        conn = get_connection()
        conn.begin()
        with conn.cursor() as curs:
            curs.execute(
                "SELECT customer_id FROM customers WHERE customer_id = %s FOR UPDATE",
                (customer_id,),
            )
            if curs.fetchone() is None:
                raise HTTPException(404, "존재하지 않는 고객입니다.")
            curs.execute(
                """
                UPDATE customers
                SET customer_name = %s, email = %s, address = %s, phone = %s
                WHERE customer_id = %s
                """,
                (customer_name,
                email,
                address,
                phone_number,
                customer_id),
            )
        conn.commit()
        conn.close()
        return {"result": "OK",
                "message": "고객 정보가 수정되었습니다."
                }
    except Exception as e:
        return{'result' : 'Error'}




# 고객 삭제
@router.post("/customers_delect",tags=["고객 삭제"],
                        summary="고객 휴먼 상태 및 회원 탈퇴",
                        )
async def customer_delect(
    seq : int = Form(...)):
    try:
        conn = get_connection()
        curs = conn.cursor()
        sql = """ UPDATE customers
                    SET account_status = 'WITHDRAWN',
                    withdrawn_at = NOW()
                    WHERE customer_id = %s
                    AND account_status <> 'WITHDRAWN'"""
        curs.execute(sql, (seq))
        conn.commit()
        conn.close()
        return{'result' : 'OK',
                "message" : '고객이 없거나 이미 탈퇴한 회원입니다.'}
    except Exception as e:
        return{'result' : 'Error',
                "message" : '회원 탈퇴가 처리되었습니다.'}



# 고객 상품 조회
@router.get("/customers_categories_search", tags=["고객 상품 조회"], summary="고객 상품 조회")
def customers_categories():
    conn = get_connection()
    try:
        with conn.cursor() as curs:
            curs.execute(
                """
SELECT
                    c.cosmetic_id,
                    c.cosmetic_name,
                    m.manufacturer_name,
                    cat.category_name,

                    -- 최신 용량
                    (
                        SELECT vh.volume_text
                        FROM cosmetic_volume_history AS vh
                        WHERE vh.cosmetic_id = c.cosmetic_id
                        ORDER BY
                            vh.changed_on DESC,
                            CAST(
                                SUBSTRING_INDEX(vh.change_id, '_', -1)
                                AS UNSIGNED
                            ) DESC
                        LIMIT 1
                    ) AS volume_text,

                    -- 최신 판매 가격
                    (
                        SELECT ph.sale_price
                        FROM cosmetic_price_history AS ph
                        WHERE ph.cosmetic_id = c.cosmetic_id
                        ORDER BY
                            ph.changed_on DESC,
                            CAST(
                                SUBSTRING_INDEX(ph.change_id, '_', -1)
                                AS UNSIGNED
                            ) DESC
                        LIMIT 1
                    ) AS sale_price,

                    COALESCE(i.available_quantity, 0)
                        AS available_quantity,

                    CASE
                        WHEN COALESCE(i.available_quantity, 0) > 0
                            THEN '구매 가능'
                        ELSE '품절'
                    END AS availability

                FROM cosmetics AS c

                JOIN manufacturers AS m
                    ON m.manufacturer_id = c.manufacturer_id

                JOIN categories AS cat
                    ON cat.category_id = c.category_id

                -- 판매 가능한 입고별 재고 합산
                LEFT JOIN (
                    SELECT
                        cosmetic_id,
                        SUM(stock_quantity) AS available_quantity
                    FROM product_inventory
                    WHERE inventory_status = 'MAINTAIN'
                    AND stock_quantity > 0
                    AND (
                        expires_on IS NULL
                        OR expires_on >= CURDATE()
                      )
                    GROUP BY cosmetic_id
                ) AS i
                    ON i.cosmetic_id = c.cosmetic_id

                -- 최신 판매 상태가 판매 중인 상품만 조회
                WHERE (
                    SELECT sh.sale_status
                    FROM cosmetic_sale_status_history AS sh
                    WHERE sh.cosmetic_id = c.cosmetic_id
                    ORDER BY
                        sh.changed_on DESC,
                        CAST(
                            SUBSTRING_INDEX(sh.change_id, '_', -1)
                            AS UNSIGNED
                        ) DESC
                    LIMIT 1
                ) = 'ON_SALE'

                ORDER BY c.cosmetic_name, c.cosmetic_id
                """
            )
            rows = curs.fetchall()
        return {"result": rows}
    finally:
        conn.close()
