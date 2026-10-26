
from fastapi import APIRouter
from schemas.admin.purchase_order_schema import (PurchaseOrderCreateRequest, PurchaseOrderCreateResponse)
from services.admin.purchase_order_service import (create_purchase_order)


router = APIRouter(
    prefix="/admin/purchase-orders",
    tags=["본사 관리자 - 발주 관리"],
)


@router.post(
    "",
    response_model=PurchaseOrderCreateResponse,
    status_code=201,
)
def register_purchase_order(
    data: PurchaseOrderCreateRequest,
):
    return create_purchase_order(data)
