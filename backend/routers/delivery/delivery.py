from fastapi import APIRouter
from schemas.delivery.delivery_schema import (DeliveryListItem, DeliveryStatusUpdateRequest)
from services.delivery.delivery_service import (get_delivery_list, update_delivery_status)

router = APIRouter(
    prefix="/delivery",
    tags=["배송업체"],
)


@router.get("/test")
def delivery_test():
    return {"message": "배송업체 API 연결 성공"}

# 배송 목록 조회
@router.get(
    "/deliveries",
    response_model=list[DeliveryListItem],
)
def read_delivery_list():
    return get_delivery_list()

# 배송 상태 변경
@router.patch("/deliveries/{delivery_id}/status")
def change_delivery_status(
    delivery_id: str,
    data: DeliveryStatusUpdateRequest,
):
    return update_delivery_status(delivery_id, data)