
from datetime import datetime
from enum import Enum

from pydantic import BaseModel, Field, ConfigDict


class OrderStatus(str, Enum):
    PENDING = "PENDING"
    PAID = "PAID"
    PREPARING = "PREPARING"
    SHIPPED = "SHIPPED"
    DELIVERED = "DELIVERED"
    CANCELLED = "CANCELLED"
    RETURNED = "RETURNED"


# 주문 생성 요청
class OrderCreate(BaseModel):
    customer_id: str
    shipping_address: str = Field(
        min_length=1,
        max_length=500
    )


# 주문 상태 변경 요청
class OrderStatusUpdate(BaseModel):
    order_status: OrderStatus


# 주문 조회 응답
class OrderResponse(BaseModel):
    order_id: str
    customer_id: str
    order_seq: int
    order_status: OrderStatus
    ordered_at: datetime
    shipping_address: str

    model_config = ConfigDict(from_attributes=True)


# 주문 목록 조회 조건
class OrderListQuery(BaseModel):
    page: int = Field(default=1, ge=1)
    count: int = Field(default=20, ge=1, le=100)
    asc: bool = False


# 주문 목록 응답
class OrderListResponse(BaseModel):
    orders: list[OrderResponse]
