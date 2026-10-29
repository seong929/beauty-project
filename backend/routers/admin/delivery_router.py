
from fastapi import APIRouter, Depends

from schemas.delivery.delivery_schema import DeliveryListItem
from services.delivery.delivery_service import get_admin_delivery_list
from services.staff.staff_auth_service import require_admin


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
    employee: dict = Depends(require_admin),
):
    return get_admin_delivery_list()
