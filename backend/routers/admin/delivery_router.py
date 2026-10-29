
from fastapi import APIRouter, Depends, HTTPException, status

from schemas.delivery.delivery_schema import DeliveryListItem
from services.delivery.delivery_service import get_admin_delivery_list
from services.staff.staff_auth_service import require_staff


router = APIRouter(
    prefix="/admin",
    tags=["본사 관리자"],
)


# 본사 관리자 전체 배송 현황 조회
@router.get(
    "/deliveries",
    response_model=list[DeliveryListItem],
    summary="본사 관리자 전체 배송 현황 조회",
)
def read_admin_delivery_list(
    employee: dict = Depends(require_staff),
):
    # 1. 관리자 권한 확인
    if employee["employee_role"] != "ADMIN":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="관리자만 전체 배송 현황을 조회할 수 있습니다.",
        )

    # 2. 전체 배송 목록 조회
    return get_admin_delivery_list()
