from fastapi import APIRouter

from schemas.admin.cosmetic_schema import (CosmeticCreateRequest, CosmeticCreateResponse)
from services.admin.cosmetic_service import create_cosmetic


router = APIRouter(
    prefix="/admin",
    tags=["본사 관리자"],
)

@router.post(
    "/cosmetics",
    response_model=CosmeticCreateResponse,
    status_code=201,
)
def register_cosmetic(data: CosmeticCreateRequest):
    return create_cosmetic(data)
