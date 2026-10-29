
from fastapi import APIRouter, Depends, HTTPException, status
from schemas.admin.inbound_schema import (InboundCreateRequest, InboundCreateResponse)
from services.admin.inbound_service import create_inbound
from services.staff.staff_auth_service import require_staff


router = APIRouter(
    prefix="/admin/inbounds",
    tags=["본사 직원 및 관리자 - 입고 관리"],
)


@router.post(
    "",
    response_model=InboundCreateResponse,
    status_code=201,
    summary="발주 상품 입고 등록",
)
def register_inbound(
    data: InboundCreateRequest,
    employee: dict = Depends(require_staff),
):
    # 1. 본사 직원 및 관리자 권한 확인
    if employee["employee_role"] not in ("STAFF", "ADMIN"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="본사 직원 또는 관리자만 입고 처리할 수 있습니다.",
        )

    # 2. 로그인 직원과 요청 직원 ID 일치 확인
    if employee["employee_id"] != data.employee_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="로그인한 직원 정보가 일치하지 않습니다.",
        )

    # 3. 입고 처리
    return create_inbound(data)
