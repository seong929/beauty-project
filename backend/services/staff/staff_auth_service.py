"""직원용 API의 JWT 인증 및 현재 DB 권한 확인."""
import logging
import os
import secrets
import time
from fastapi import Request

import jwt
import pymysql
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from database import get_connection

logger = logging.getLogger(__name__)
bearer_scheme = HTTPBearer(auto_error=False)
# 개발용 라우터가 import될 때만 활성화되는 임시 세션.
_tmp_enabled = False
_tmp_sessions = {}
_TMP_COOKIE = "tmp_staff_session"


def enable_tmp_staff_auth():
    global _tmp_enabled
    _tmp_enabled = True


def create_tmp_staff_session(employee_id: str) -> str:
    if not _tmp_enabled:
        raise HTTPException(status_code=404, detail="테스트 인증 비활성화")
    token = secrets.token_urlsafe(32)
    _tmp_sessions[token] = (employee_id, time.monotonic() + 3600)
    return token


def _get_tmp_employee_id(request: Request) -> str | None:
    if not _tmp_enabled or not request.client or request.client.host not in ("127.0.0.1", "::1"):
        return None
    token = request.cookies.get(_TMP_COOKIE)
    if not token:
        return None
    record = _tmp_sessions.get(token)
    if not record:
        return None
    employee_id, expires_at = record
    if time.monotonic() > expires_at:
        _tmp_sessions.pop(token, None)
        return None
    return employee_id

JWT_ISSUER = "cosmetics-management"
JWT_AUDIENCE = "cosmetics-management-staff"
JWT_ALGORITHM = "HS256"
MAX_TOKEN_AGE_SECONDS = 12 * 60 * 60


def require_staff(
    request: Request,
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
) -> dict:
    """서명·만료 검증 후 employees.employee_role을 DB에서 다시 조회한다."""
    unauthorized = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="유효한 직원 인증이 필요합니다.",
        headers={"WWW-Authenticate": "Bearer"},
    )
    tmp_employee_id = _get_tmp_employee_id(request) if credentials is None else None
    if credentials is None and tmp_employee_id is None:
        raise unauthorized

    if tmp_employee_id is not None:
        employee_id = tmp_employee_id
    else:
        employee_id = None

    if employee_id is None:
        secret = os.getenv("STAFF_JWT_SECRET", "")
        if len(secret.encode("utf-8")) < 32:
            logger.error("STAFF_JWT_SECRET 환경변수가 안전하게 설정되지 않았습니다.")
            raise HTTPException(status_code=503, detail="인증 서비스가 설정되지 않았습니다.")

        try:
            payload = jwt.decode(
                credentials.credentials,
                secret,
                algorithms=[JWT_ALGORITHM],
                audience=JWT_AUDIENCE,
                issuer=JWT_ISSUER,
                options={"require": ["sub", "exp", "iat", "iss", "aud"]},
            )
            employee_id = payload.get("sub")
            issued_at = payload.get("iat")
            expires_at = payload.get("exp")
            if (
                not isinstance(employee_id, str)
                or not employee_id.startswith("E_")
                or len(employee_id) > 48
                or type(issued_at) is not int
                or type(expires_at) is not int
                or not 0 < expires_at - issued_at <= MAX_TOKEN_AGE_SECONDS
            ):
                raise unauthorized
        except jwt.InvalidTokenError:
            raise unauthorized from None

    try:
        conn = get_connection()
    except pymysql.MySQLError:
        logger.exception("직원 인증 중 DB 연결 실패")
        raise HTTPException(status_code=503, detail="인증 데이터베이스 연결에 실패했습니다.")

    try:
        with conn.cursor() as cursor:
            cursor.execute(
                """
                SELECT employee_id, employee_role
                FROM employees
                WHERE employee_id = %s
                """,
                (employee_id,),
            )
            employee = cursor.fetchone()
    except pymysql.MySQLError:
        logger.exception("직원 인증 중 DB 조회 실패")
        raise HTTPException(status_code=503, detail="직원 권한 확인에 실패했습니다.")
    finally:
        conn.close()

    if not employee or employee["employee_role"] not in ("STAFF", "ADMIN"):
        raise HTTPException(status_code=403, detail="직원 API 접근 권한이 없습니다.")
    return employee


# 백엔드에 이미 있는 pwdlib[argon2] 해시 검증기를 재사용한다.
from datetime import datetime, timedelta, timezone
from pwdlib import PasswordHash

_password_hasher = PasswordHash.recommended()
TOKEN_LIFETIME_SECONDS = 60 * 60  # 1시간


def authenticate_employee(login_id: str, password: str) -> dict:
    """로그인 ID와 저장된 비밀번호 해시를 검증. 호출자가 employee_id를 선택할 수 없다."""
    try:
        conn = get_connection()
    except pymysql.MySQLError:
        logger.exception("직원 로그인 중 DB 연결 실패")
        raise HTTPException(status_code=503, detail="인증 데이터베이스 연결에 실패했습니다.")

    try:
        with conn.cursor() as cursor:
            cursor.execute(
                """SELECT employee_id, employee_role, password_hash
                   FROM employees WHERE login_id = %s""",
                (login_id,),
            )
            employee = cursor.fetchone()
    except pymysql.MySQLError:
        logger.exception("직원 로그인 중 DB 조회 실패")
        raise HTTPException(status_code=503, detail="직원 인증 정보를 조회하지 못했습니다.")
    finally:
        conn.close()

    # 사용자 존재 여부/비밀번호 오류는 외부에 동일하게 응답한다.
    invalid = HTTPException(
        status_code=401,
        detail="로그인 정보가 올바르지 않습니다.",
        headers={"WWW-Authenticate": "Bearer"},
    )
    if not employee:
        raise invalid
    try:
        verified = _password_hasher.verify(password, employee["password_hash"])
    except (ValueError, TypeError):
        # 개발용 시드의 __DEMO_HASH... 등 유효하지 않은 해시 처리
        logger.warning("직원 계정에 유효하지 않은 비밀번호 해시가 저장되어 있습니다.")
        raise invalid from None
    if not verified:
        raise invalid
    if employee["employee_role"] not in ("STAFF", "ADMIN"):
        raise HTTPException(status_code=403, detail="직원 API 접근 권한이 없습니다.")
    return {"employee_id": employee["employee_id"], "employee_role": employee["employee_role"]}


def issue_staff_token(employee_id: str) -> dict:
    """서명된 짧은 수명의 JWT를 생성. 역할은 토큰이 아닌 DB에서 매 요청 확인한다."""
    secret = os.getenv("STAFF_JWT_SECRET", "")
    if len(secret.encode("utf-8")) < 32:
        logger.error("STAFF_JWT_SECRET 환경변수가 안전하게 설정되지 않았습니다.")
        raise HTTPException(status_code=503, detail="인증 서비스가 설정되지 않았습니다.")
    now = datetime.now(timezone.utc)
    payload = {
        "sub": employee_id,
        "iss": JWT_ISSUER,
        "aud": JWT_AUDIENCE,
        "iat": int(now.timestamp()),
        "exp": int((now + timedelta(seconds=TOKEN_LIFETIME_SECONDS)).timestamp()),
    }
    return {
        "access_token": jwt.encode(payload, secret, algorithm=JWT_ALGORITHM),
        "token_type": "bearer",
        "expires_in": TOKEN_LIFETIME_SECONDS,
    }
