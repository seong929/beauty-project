
from fastapi import APIRouter, Depends
from schemas.admin.purchase_order_schema import (PurchaseOrderCreateRequest, PurchaseOrderCreateResponse, PurchaseOrderListResponse)
from services.admin.purchase_order_service import (create_purchase_order, get_purchase_order_list)
from services.staff.staff_auth_service import require_staff, require_admin


router = APIRouter(
    prefix="/admin/purchase-orders",
    tags=["본사 관리자 - 발주 관리"],
)


@router.post("", response_model=PurchaseOrderCreateResponse, status_code=201,
             summary="기존 승인 품의의 발주 복구", deprecated=True)
def register_purchase_order(
    data: PurchaseOrderCreateRequest,
    employee: dict = Depends(require_admin),
):
    # 기존에 승인되었지만 발주가 없는 품의만 복구한다.
    # 신규 승인은 품의 결재 API에서 발주와 함께 생성된다.
    return create_purchase_order(data)

@router.get(
    "",
    response_model=list[PurchaseOrderListResponse],
    summary="발주 목록 조회"
)
def read_purchase_order_list(
    employee: dict = Depends(require_staff)
):
    return get_purchase_order_list()
