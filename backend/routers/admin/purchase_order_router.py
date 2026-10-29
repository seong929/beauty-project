
from fastapi import APIRouter, Depends, HTTPException, status
from schemas.admin.purchase_order_schema import (PurchaseOrderCreateRequest, PurchaseOrderCreateResponse, PurchaseOrderListResponse)
from services.admin.purchase_order_service import (create_purchase_order, get_purchase_order_list)
from services.staff.staff_auth_service import require_staff


router = APIRouter(
    prefix="/admin/purchase-orders",
    tags=["본사 관리자 - 발주 관리"],
)

# 관리자 권한 확인
def require_admin(
    employee: dict = Depends(require_staff),
):
    if employee["employee_role"] != "ADMIN":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="관리자만 발주 관리 기능을 사용할 수 있습니다.",
        )

    return employee

@router.post(
    "",
    response_model=PurchaseOrderCreateResponse,
    status_code=201,
    summary="발주 등록"
)
def register_purchase_order(
    data: PurchaseOrderCreateRequest,
    employee: dict = Depends(require_admin),
):
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
