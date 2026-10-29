
from fastapi import APIRouter
from pydantic import BaseModel, Field

from services.delivery.delivery_auth_service import (
    authenticate_carrier,
    issue_carrier_token,
)


router = APIRouter(
    prefix="/delivery/auth",
    tags=["배송업체 인증"],
)


# 배송업체 로그인 요청
class CarrierLoginRequest(BaseModel):
    login_id: str = Field(min_length=1, max_length=100)
    password: str = Field(min_length=1)


# 배송업체 로그인 응답
class CarrierLoginResponse(BaseModel):
    access_token: str
    token_type: str
    expires_in: int
    account_id: str
    carrier_id: str


# 배송업체 로그인
@router.post(
    "/login",
    response_model=CarrierLoginResponse,
    summary="배송업체 담당자 로그인",
)
def login_carrier(data: CarrierLoginRequest):
    # 1. 로그인 아이디와 비밀번호 검증
    account = authenticate_carrier(
        login_id=data.login_id,
        password=data.password,
    )

    # 2. 배송업체 전용 JWT 발급
    token = issue_carrier_token(
        account_id=account["account_id"],
    )

    # 3. 로그인 결과 반환
    return {
        **token,
        "account_id": account["account_id"],
        "carrier_id": account["carrier_id"],
    }
