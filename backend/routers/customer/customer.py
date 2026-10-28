from fastapi import APIRouter, Form, HTTPException, Query
import pymysql
from pwdlib import PasswordHash

from database import get_connection
router = APIRouter(tags=["고객"])

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


def append_account_status(cursor, customer_id, account_status):
    seq = next_sequence(cursor, "history:customer_account_status_history")
    cursor.execute(
        """INSERT INTO customer_account_status_history
           (status_history_id, customer_id, changed_on, account_status)
           VALUES (%s, %s, CURRENT_DATE(), %s)""",
        (f"csh_{seq}", customer_id, account_status),
    )

password_hasher = PasswordHash.recommended()


@router.get("/customer/test")
def delivery_test():
    return {"message": "고객 API 연결 성공"}


# 고객 등록(회원 가입)
@router.post("/customer_upload",summary="고객 등록")
def customeres_upload(
    customer_id: str = Form(...,min_length=1, max_length=60),
    login_id: str = Form(...,min_length=2,max_length=60 ),
    password: str = Form(...,min_length=8,max_length=20 ),
    customer_name: str = Form(...,min_length=2,max_length=30),
    email: str = Form(...,max_length=100),
    address: str = Form(...,max_length=100),
    phone: str = Form(...,min_length=1,max_length=30)
    ):

    hashed_password = password_hasher.hash(password)
    conn = get_connection()
    try:
        conn.begin()
        with conn.cursor() as curs:
            curs.execute(
                """INSERT INTO customers (
                    customer_id, login_id, password_hash,
                    customer_name, email, address, phone
                ) VALUES (%s, %s, %s, %s, %s, %s, %s)""",
                (customer_id, login_id, hashed_password,
                 customer_name, email, address, phone),
            )
            append_account_status(curs, customer_id, "ACTIVE")
        conn.commit()
        return {"result": "OK", "customer_id": customer_id,
                "message": "회원 가입 완료"}
    except pymysql.err.IntegrityError:
        conn.rollback()
        raise HTTPException(409, "중복된 고객 ID, 로그인 ID 또는 이메일입니다.")
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


# 고객 정보 조회
@router.get("/customer_select",summary="고객 조회")
def customer_select():
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
@router.put("/customer_update",summary="고객 정보 수정")
def customer_update(
    customer_id: str = Query(..., min_length=1, max_length=60),
    customer_name: str = Form(..., min_length=1, max_length=30),
    email: str = Form(..., min_length=1, max_length=200),
    address: str = Form(..., min_length=1, max_length=200),
    phone: str = Form(..., min_length=1, max_length=30),
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
                SET customer_name = %s,
                email = %s,
                address = %s,
                phone = %s
                WHERE customer_id = %s
                """,
                (customer_name,
                email,
                address,
                phone,
                customer_id,))
            
        conn.commit()
        return {"result": "OK",
                "message": "고객 정보가 수정되었습니다."
                }
    except Exception:
        if conn is not None:
            conn.rollback()
        raise

    finally:
        if conn is not None:
            conn.close()



# 고객 탈퇴
@router.post("/customer_delect",summary="고객 휴먼 상태 및 회원 탈퇴")
def customer_delect(customer_id: str = Form(..., min_length=1, max_length=64)):
    conn = get_connection()
    try:
        conn.begin()
        with conn.cursor() as curs:
            curs.execute(
                "SELECT customer_id FROM customers WHERE customer_id=%s FOR UPDATE",
                (customer_id,),
            )
            if curs.fetchone() is None:
                raise HTTPException(404, "존재하지 않는 고객입니다.")
            if get_account_status(curs, customer_id) == "WITHDRAWN":
                raise HTTPException(409, "이미 탈퇴 처리된 고객입니다.")
            append_account_status(curs, customer_id, "WITHDRAWN")
        conn.commit()
        return {"result": "OK", "message": "회원 탈퇴가 처리되었습니다."}
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()
