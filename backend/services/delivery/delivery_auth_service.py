
"""배송업체 담당자 로그인 및 JWT 인증."""

import logging
import os
from datetime import datetime, timedelta, timezone

import jwt
import pymysql
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pwdlib import PasswordHash
from pwdlib.exceptions import UnknownHashError

from database import get_connection

logger = logging.getLogger(__name__)

password_hasher = PasswordHash.recommended()
bearer_scheme = HTTPBearer(auto_error=False)

JWT_ISSUER = "cosmetics-management"
JWT_AUDIENCE = "cosmetics-management-delivery"
JWT_ALGORITHM = "HS256"
TOKEN_LIFETIME_SECONDS = 60 * 60


def authenticate_carrier(login_id: str, password: str) -> dict:
    """배송업체 계정의 아이디와 비밀번호를 검증한다."""

    invalid = HTTPException(
        status_code=401,
        detail="아이디 또는 비밀번호가 올바르지 않습니다.",
        headers={"WWW-Authenticate": "Bearer"},
    )

    try:
        conn = get_connection()
    except pymysql.MySQLError:
        logger.exception("배송업체 로그인 DB 연결 실패")
        raise HTTPException(
            status_code=503,
            detail="인증 데이터베이스 연결에 실패했습니다.",
        ) from None

    try:
        with conn.cursor() as cursor:
            cursor.execute(
                """
                SELECT
                    ca.account_id,
                    ca.carrier_id,
                    ca.password_hash
                FROM carrier_accounts AS ca
                JOIN carriers AS c
                    ON ca.carrier_id = c.carrier_id
                WHERE ca.login_id = %s
                """,
                (login_id,),
            )
            account = cursor.fetchone()

    except pymysql.MySQLError:
        logger.exception("배송업체 계정 조회 실패")
        raise HTTPException(
            status_code=503,
            detail="배송업체 인증 정보를 조회하지 못했습니다.",
        ) from None

    finally:
        conn.close()

    if account is None:
        raise invalid

    try:
        verified = password_hasher.verify(
            password,
            account["password_hash"],
        )
    except (ValueError, TypeError, UnknownHashError):
        logger.warning("유효하지 않은 배송업체 비밀번호 해시")
        raise invalid from None

    if not verified:
        raise invalid

    return {
        "account_id": account["account_id"],
        "carrier_id": account["carrier_id"],
    }


def issue_carrier_token(account_id: str) -> dict:
    """배송업체 전용 JWT를 발급한다."""

    secret = os.getenv("DELIVERY_JWT_SECRET", "")

    if len(secret.encode("utf-8")) < 32:
        raise HTTPException(
            status_code=503,
            detail="배송업체 인증 서비스가 설정되지 않았습니다.",
        )

    now = datetime.now(timezone.utc)

    payload = {
        "sub": account_id,
        "iss": JWT_ISSUER,
        "aud": JWT_AUDIENCE,
        "iat": int(now.timestamp()),
        "exp": int(
            (now + timedelta(seconds=TOKEN_LIFETIME_SECONDS))
            .timestamp()
        ),
    }

    return {
        "access_token": jwt.encode(
            payload,
            secret,
            algorithm=JWT_ALGORITHM,
        ),
        "token_type": "bearer",
        "expires_in": TOKEN_LIFETIME_SECONDS,
    }


def require_carrier(
    credentials: HTTPAuthorizationCredentials | None = Depends(
        bearer_scheme
    ),
) -> dict:
    """JWT를 검증하고 현재 배송업체 계정을 DB에서 확인한다."""

    unauthorized = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="유효한 배송업체 인증이 필요합니다.",
        headers={"WWW-Authenticate": "Bearer"},
    )

    if credentials is None:
        raise unauthorized

    secret = os.getenv("DELIVERY_JWT_SECRET", "")

    if len(secret.encode("utf-8")) < 32:
        raise HTTPException(
            status_code=503,
            detail="배송업체 인증 서비스가 설정되지 않았습니다.",
        )

    try:
        payload = jwt.decode(
            credentials.credentials,
            secret,
            algorithms=[JWT_ALGORITHM],
            audience=JWT_AUDIENCE,
            issuer=JWT_ISSUER,
            options={
                "require": [
                    "sub", "exp", "iat", "iss", "aud"
                ],
            },
        )

        account_id = payload.get("sub")
        issued_at = payload.get("iat")
        expires_at = payload.get("exp")

        if (
            not isinstance(account_id, str)
            or not account_id.startswith("ca_")
            or len(account_id) > 48
            or type(issued_at) is not int
            or type(expires_at) is not int
            or not 0 < expires_at - issued_at <= TOKEN_LIFETIME_SECONDS
        ):
            raise unauthorized

    except jwt.InvalidTokenError:
        raise unauthorized from None

    try:
        conn = get_connection()
    except pymysql.MySQLError:
        logger.exception("배송업체 인증 DB 연결 실패")
        raise HTTPException(
            status_code=503,
            detail="인증 데이터베이스 연결에 실패했습니다.",
        ) from None

    try:
        with conn.cursor() as cursor:
            cursor.execute(
                """
                SELECT
                    ca.account_id,
                    ca.carrier_id,
                    c.carrier_name
                FROM carrier_accounts AS ca
                JOIN carriers AS c
                    ON ca.carrier_id = c.carrier_id
                WHERE ca.account_id = %s
                """,
                (account_id,),
            )

            account = cursor.fetchone()

    except pymysql.MySQLError:
        logger.exception("배송업체 권한 확인 실패")
        raise HTTPException(
            status_code=503,
            detail="배송업체 권한 확인에 실패했습니다.",
        ) from None

    finally:
        conn.close()

    if account is None:
        raise HTTPException(
            status_code=403,
            detail="배송업체 접근 권한이 없습니다.",
        )

    return account
