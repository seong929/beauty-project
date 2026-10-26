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




