from fastapi import APIRouter, Depends

from schemas.admin.cosmetic_schema import (CosmeticCreateRequest, CosmeticCreateResponse, CosmeticSaleStatusRequest, CosmeticDetailsUpdate)
from services.admin.cosmetic_details_service import update_cosmetic_details
from services.admin.cosmetic_service import create_cosmetic, change_sale_status
from services.staff.staff_auth_service import require_admin, require_matching_employee


router = APIRouter(
    prefix="/admin",
    tags=["본사 관리자"],
)

@router.post(
    "/cosmetics",
    response_model=CosmeticCreateResponse,
    status_code=201,
    summary="화장품 등록",
)
def register_cosmetic(data: CosmeticCreateRequest, employee: dict = Depends(require_admin)):
    require_matching_employee(employee, data.employee_id)
    return create_cosmetic(data)


@router.patch('/cosmetics/{cosmetic_id}/sale-status', summary='상품 판매 상태 변경')
def update_sale_status(cosmetic_id: str, data: CosmeticSaleStatusRequest, employee: dict = Depends(require_admin)):
    return change_sale_status(cosmetic_id, employee['employee_id'], data.sale_status)


@router.patch('/cosmetics/{cosmetic_id}', summary='상품 옵션 정보 변경')
def update_details(cosmetic_id: str, data: CosmeticDetailsUpdate, employee: dict = Depends(require_admin)):
    return update_cosmetic_details(cosmetic_id, employee['employee_id'], data)
