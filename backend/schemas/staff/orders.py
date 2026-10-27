
from datetime import datetime, date
from enum import Enum
from decimal import Decimal

from pydantic import BaseModel, Field, ConfigDict


# 주문 상태
class OrderStatus(str, Enum):
    PENDING = "PENDING"
    PAID = "PAID"
    PREPARING = "PREPARING"
    SHIPPED = "SHIPPED"
    DELIVERED = "DELIVERED"
    CANCELLED = "CANCELLED"
    RETURNED = "RETURNED"


# 상품 판매 옵션
class SaleOption(str, Enum):
    NORMAL = "NORMAL"
    NEAR_EXPIRY = "NEAR_EXPIRY"


# 주문 생성 요청
class OrderCreate(BaseModel):
    customer_id: str = Field(
        description="주문을 생성하는 고객의 고유 ID",
        examples=["customer_001"]
    )

    shipping_address: str = Field(
        min_length=1,
        max_length=500,
        description="상품을 배송받을 주소",
        examples=["서울특별시 강남구 테헤란로 123"]
    )


# 주문 상태 변경 요청
class OrderStatusUpdate(BaseModel):
    order_status: OrderStatus = Field(
        description=(
            "변경할 주문 상태. "
            "PENDING: 주문 대기, "
            "PAID: 결제 완료, "
            "PREPARING: 상품 준비 중, "
            "SHIPPED: 배송 중, "
            "DELIVERED: 배송 완료, "
            "CANCELLED: 주문 취소, "
            "RETURNED: 반품 완료"
        ),
        examples=["SHIPPED"]
    )


# 주문 조회 응답
class OrderResponse(BaseModel):
    order_id: str = Field(
        description="주문 고유 번호",
        examples=["ord_910071"]
    )

    customer_id: str = Field(
        description="주문한 고객의 고유 ID",
        examples=["customer_001"]
    )

    order_seq: int = Field(
        description="주문 생성 순번",
        examples=[910071]
    )

    order_status: OrderStatus = Field(
        description="현재 주문 처리 상태"
    )

    ordered_at: datetime = Field(
        description="주문 생성 일시"
    )

    shipping_address: str = Field(
        description="배송지 주소"
    )

    model_config = ConfigDict(from_attributes=True)


# 주문 목록 조회 조건
class OrderListQuery(BaseModel):
    page: int = Field(
        default=1,
        ge=1,
        description="조회할 페이지 번호 (1부터 시작)"
    )

    count: int = Field(
        default=20,
        ge=1,
        le=100,
        description="페이지당 조회할 주문 개수 (1~100개)"
    )

    asc: bool = Field(
        default=False,
        description=(
            "주문 순번 정렬 방향. "
            "true: 오름차순, false: 내림차순"
        )
    )


# 주문 목록 응답
class OrderListResponse(BaseModel):
    orders: list[OrderResponse] = Field(
        description="조회 조건에 해당하는 주문 목록"
    )


# 주문에 포함된 구매 상품 정보
class OrderItemResponse(BaseModel):
    order_item_id: str = Field(
        description="주문 상품 항목 고유 ID"
    )

    purchase_quantity: int = Field(
        description="해당 상품의 구매 수량"
    )

    purchase_unit_price: Decimal = Field(
        description="구매 당시 상품 1개의 판매 가격"
    )

    sale_option: SaleOption = Field(
        description=(
            "상품 판매 옵션. "
            "NORMAL: 일반 판매, "
            "NEAR_EXPIRY: 유통기한 임박 상품"
        )
    )

    used_points: int = Field(
        description="해당 주문 상품에 사용된 포인트"
    )

    earned_points: int = Field(
        description="해당 주문 상품에서 적립된 포인트"
    )

    inventory_id: str = Field(
        description="구매 상품이 속한 재고의 고유 ID"
    )

    expires_on: date | None = Field(
        description="해당 상품 재고의 유통기한"
    )

    cosmetic_id: str = Field(
        description="화장품의 고유 ID"
    )

    cosmetic_name: str = Field(
        description="화장품 이름"
    )

    model_config = ConfigDict(from_attributes=True)
