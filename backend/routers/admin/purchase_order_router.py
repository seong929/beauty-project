
from fastapi import APIRouter
from schemas.admin.purchase_order_schema import (PurchaseOrderCreateRequest, PurchaseOrderCreateResponse, PurchaseOrderListResponse)
from services.admin.purchase_order_service import (create_purchase_order, get_purchase_order_list)


router = APIRouter(
    prefix="/admin/purchase-orders",
    tags=["본사 관리자 - 발주 관리"],
)


@router.post(
    "",
    response_model=PurchaseOrderCreateResponse,
    status_code=201,
    summary="발주 등록"
)
def register_purchase_order(
    data: PurchaseOrderCreateRequest,
):
    return create_purchase_order(data)



@router.get(
    "",
    response_model=list[PurchaseOrderListResponse],
    summary="발주 목록 조회"
)
def read_purchase_order_list():
    return get_purchase_order_list()
