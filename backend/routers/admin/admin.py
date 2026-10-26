from fastapi import APIRouter, status
from schemas.admin.admin_schema import (CosmeticCreateRequest, CosmeticCreateResponse)
from services.admin.admin_service import create_cosmetic

router = APIRouter(
    prefix="/admin",
    tags=["본사 관리자"],
)


@router.get("/test")
def admin_test():
    return {"message": "관리자 API 연결 성공"}

@router.post(
    "/cosmetics",
    response_model=CosmeticCreateResponse,
    status_code=status.HTTP_201_CREATED,
)
def register_cosmetic(data: CosmeticCreateRequest):
    return create_cosmetic(data)