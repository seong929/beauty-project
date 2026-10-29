from fastapi import APIRouter, Form, HTTPException, Query
import pymysql
import secrets
from pwdlib import PasswordHash
from pwdlib.exceptions import UnknownHashError

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
_login_dummy_hash = password_hasher.hash(secrets.token_urlsafe(32))


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


# 고객 로그인
@router.post("/customer_login", summary="고객 로그인")
def customer_login(
    login_id: str = Form(..., min_length=2, max_length=60),
    password: str = Form(..., min_length=1, max_length=200),
):
    invalid_login = HTTPException(401, "아이디 또는 비밀번호가 올바르지 않습니다.")
    conn = None
    try:
        conn = get_connection()
        with conn.cursor() as curs:
            # 로그인 ID로 고객 정보와 가입 시 저장한 비밀번호 해시를 조회한다.
            curs.execute(
                """SELECT customer_id, login_id, password_hash, customer_name,
                          email, address, phone, gender, points_balance
                   FROM customers WHERE login_id = %s LIMIT 1""",
                (login_id.strip(),),
            )
            customer = curs.fetchone()

            # 없는 계정도 해시 검증을 거쳐 계정 존재 여부에 따른 시간 차를 줄인다.
            stored_hash = customer["password_hash"] if customer else _login_dummy_hash
            try:
                verified = password_hasher.verify(password, stored_hash)
            except (UnknownHashError, TypeError, ValueError):
                verified = False
            if customer is None or not verified:
                raise invalid_login

            # 최신 계정 상태를 확인한다. 탈퇴 등 비활성 계정은 로그인하지 못한다.
            account_status = get_account_status(curs, customer["customer_id"])
            if account_status != "ACTIVE":
                raise HTTPException(403, "로그인할 수 없는 계정입니다. 고객센터에 문의해 주세요.")

        # 비밀번호와 해시를 제외한 고객 정보만 프런트엔드에 전달한다.
        profile = {
            field: customer[field]
            for field in (
                "customer_id", "login_id", "customer_name", "email",
                "address", "phone", "gender", "points_balance",
            )
        }
        profile["account_status"] = account_status
        return {"result": "OK", "customer": profile, "message": "로그인 완료"}
    except pymysql.MySQLError:
        raise HTTPException(503, "로그인 서버에 연결할 수 없습니다. 잠시 후 다시 시도해 주세요.") from None
    finally:
        if conn is not None:
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
        return {
            "result": "OK",
            "message": "고객 정보가 수정되었습니다."
        }

    except pymysql.err.IntegrityError:
        if conn is not None:
            conn.rollback()
        raise HTTPException(
            status_code=409,
            detail="이미 사용 중인 이메일입니다."
        )

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
