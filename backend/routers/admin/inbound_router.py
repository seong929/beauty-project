
from fastapi import APIRouter
from schemas.admin.inbound_schema import (InboundCreateRequest, InboundCreateResponse)
from services.admin.inbound_service import create_inbound


router = APIRouter(
    prefix="/admin/inbounds",
    tags=["본사 직원 - 입고 관리"],
)


@router.post(
    "",
    response_model=InboundCreateResponse,
    status_code=201,
    summary="발주 상품 입고 등록",
)
def register_inbound(data: InboundCreateRequest):
    return create_inbound(data)
