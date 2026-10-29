from fastapi import APIRouter, Depends
from schemas.delivery.delivery_schema import (DeliveryListItem, DeliveryStatusUpdateRequest)
from services.delivery.delivery_service import (get_delivery_list, update_delivery_status)
from services.delivery.delivery_auth_service import require_carrier

router = APIRouter(
    prefix="/delivery",
    tags=["배송업체"],
)


@router.get(
        "/test",
        summary="배송업체 테스트"
    )
def delivery_test():
    return {"message": "배송업체 API 연결 성공"}

# 배송 목록 조회
@router.get(
    "/deliveries",
    response_model=list[DeliveryListItem],
    summary="배송 목록 조회"
)
def read_delivery_list(
    carrier: dict = Depends(require_carrier)
):
    return get_delivery_list(
        carrier_id=carrier["carrier_id"]
    )

# 배송 상태 변경
@router.patch(
        "/deliveries/{delivery_id}/status",
        summary="배송 상태 변경"
    )
def change_delivery_status(
    delivery_id: str,
    data: DeliveryStatusUpdateRequest,
    carrier: dict = Depends(require_carrier)
):
    return update_delivery_status(
        delivery_id=delivery_id,
        data=data,
        carrier_id=carrier["carrier_id"],
    )