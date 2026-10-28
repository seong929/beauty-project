
from fastapi import APIRouter

from schemas.delivery.carrier_schema import (CarrierCreateRequest, CarrierCreateResponse)
from services.delivery.carrier_service import create_carrier


router = APIRouter(
    prefix="/admin",
    tags=["본사 관리자"],
)


@router.post(
    "/carriers",
    response_model=CarrierCreateResponse,
    status_code=201,
    summary="배송업체 등록",
)
def register_carrier(data: CarrierCreateRequest):
    return create_carrier(data)