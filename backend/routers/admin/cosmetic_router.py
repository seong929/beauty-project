from fastapi import APIRouter, Depends

from schemas.admin.cosmetic_schema import (CosmeticCreateRequest, CosmeticCreateResponse)
from services.admin.cosmetic_service import create_cosmetic
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
