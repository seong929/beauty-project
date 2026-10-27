
from fastapi import APIRouter, Depends

from schemas.admin.outbound_schema import (OutboundCreateRequest, OutboundCreateResponse)
from services.admin.outbound_service import create_outbound
from services.staff.staff_auth_service import require_staff


router = APIRouter(
    prefix="/admin/outbounds",
    tags=["본사 직원 - 출고 관리"],
    dependencies=[Depends(require_staff)],
)


@router.post(
    "",
    response_model=OutboundCreateResponse,
    status_code=201,
    summary="고객 주문 상품 출고 처리",
)
def register_outbound(data: OutboundCreateRequest):
    return create_outbound(data)
