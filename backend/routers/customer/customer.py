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
    login_id: str = Form(..., min_length=1),
    password: str = Form(..., min_length=1),
    customer_name: str = Form(..., min_length=1),
    email: str = Form(..., min_length=1),
    address: str = Form(...,),
    phone_number: str = Form(..., min_length=1)
    ):
    conn = None

    try:
        hashed_password = password_hasher.hash(password)
        conn = get_connection()
        conn.begin()

        with conn.cursor() as curs:
            customer_id = f"cus_{next_sequence(curs, 'customer')}"

            curs.execute(
                """
                INSERT INTO customers (
                    customer_id,
                    login_id,
                    password_hash,
                    customer_name,
                    email,
                    address,
                    phone
                )
                VALUES (%s, %s, %s, %s, %s, %s, %s)
                """,
                (
                    customer_id,
                    login_id,
                    hashed_password,
                    customer_name,
                    email,
                    address,
                    phone_number,
                ),
            )

            append_account_status(curs, customer_id, "ACTIVE")

        conn.commit()

        return {
            "result": "OK",
            "customer_id": customer_id,
            "customer_name": customer_name,
        }

    except pymysql.IntegrityError as e:
        if conn is not None:
            conn.rollback()

        if e.args and e.args[0] == 1062:
            raise HTTPException(
                status_code=409,
                detail="이미 사용 중인 아이디 또는 이메일입니다.",
            )

        raise HTTPException(
            status_code=400,
            detail="고객 등록 중 데이터 오류가 발생했습니다.",
        )

    except Exception:
        if conn is not None:
            conn.rollback()

        raise HTTPException(
            status_code=500,
            detail="고객 등록 중 오류가 발생했습니다.",
        )

    finally:
        if conn is not None:
            conn.close()
    
    
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
                raise HTTPException(status_code=404, detail="존재하지 않는 고객입니다.",)
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
        return {"result": "OK",
                "message": "고객 정보가 수정되었습니다."
                }
    except HTTPException:
        if conn is not None:
            conn.rollback()
        raise

    except pymysql.IntegrityError as e:
        if conn is not None:
            conn.rollback()

        if e.args and e.args[0] == 1062:
            raise HTTPException(
                status_code=409,
                detail="이미 사용 중인 이메일입니다.",
            )

        raise HTTPException(
            status_code=400,
            detail="고객정보 수정 중 데이터 오류가 발생했습니다.",
        )

    except Exception:
        if conn is not None:
            conn.rollback()

        raise HTTPException(
            status_code=500,
            detail="고객정보 수정 중 오류가 발생했습니다.",
        )

    finally:
        if conn is not None:
            conn.close()




# 고객 삭제
@router.post("/customers_delect",tags=["고객 삭제"],
                        summary="고객 휴먼 상태 및 회원 탈퇴",
                        )
async def customer_delect(
    seq : str = Form(..., min_length=1)
    ):
    conn = None
    try:
        conn = get_connection()
        conn.begin()

        with conn.cursor() as curs:
            curs.execute(
                """
                SELECT customer_id, customer_name, address
                FROM customers
                WHERE customer_id = %s
                FOR UPDATE
                """,
                (seq,),
            )

            if curs.fetchone() is None:
                raise HTTPException(
                    status_code=404,
                    detail="존재하지 않는 고객입니다.",
                )

            status = get_account_status(curs, seq)

            if status == "WITHDRAWN":
                raise HTTPException(
                    status_code=409,
                    detail="이미 탈퇴한 고객입니다.",
                )

            append_account_status(curs, seq, "WITHDRAWN")

        conn.commit()

        return {
            "result": "OK",
            "message": "회원탈퇴가 완료되었습니다.",
        }

    except HTTPException:
        if conn is not None:
            conn.rollback()
        raise

    except Exception:
        if conn is not None:
            conn.rollback()

        raise HTTPException(
            status_code=500,
            detail="회원탈퇴 처리 중 오류가 발생했습니다.",
        )

    finally:
        if conn is not None:
            conn.close()

