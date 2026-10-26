from datetime import datetime
from pydantic import BaseModel
from typing import Literal

class DeliveryListItem(BaseModel):
    delivery_id: str
    order_id: str
    delivery_seq: int
    carrier_name: str
    shipping_address: str
    ordered_at: datetime
    delivery_status: str
    shipped_at: datetime | None = None
    arrived_at: datetime | None = None

# 배송 상태 변경 요청
class DeliveryStatusUpdateRequest(BaseModel):
    delivery_status: Literal[
        "IN_TRANSIT",   # 배송 중
        "DELIVERED",    # 배송 완료
        "FAILED",       # 배송 실패
        "RETURNING",    # 반송 중
    ]