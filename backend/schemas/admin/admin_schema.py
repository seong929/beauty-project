
from decimal import Decimal
from typing import Literal

from pydantic import BaseModel, Field, ConfigDict


class CosmeticCreateRequest(BaseModel):
    model_config = ConfigDict(
        str_strip_whitespace=True,
        extra="forbid",
    )

    cosmetic_name: str = Field(
        min_length=1,
        max_length=200,
        description="상품명",
    )

    manufacturer_id: str = Field(
        min_length=1,
        max_length=48,
        description="제조사 ID",
    )

    category_id: str = Field(
        min_length=1,
        max_length=48,
        description="카테고리 ID",
    )

    employee_id: str = Field(
        min_length=1,
        max_length=48,
        description="등록 담당 관리자 ID",
    )

    sale_price: Decimal = Field(
        ge=0,
        max_digits=12,
        decimal_places=2,
        description="판매 가격",
    )

    unit_cost: Decimal = Field(
        ge=0,
        max_digits=12,
        decimal_places=2,
        description="상품 원가",
    )

    volume_text: str = Field(
        min_length=1,
        max_length=50,
        description="상품 용량 (예: 50ml)",
    )

    sale_status: Literal["ON_SALE", "DISCONTINUED"] = Field(
        default="ON_SALE",
        description="판매 상태",
    )

    min_stock_qty: int = Field(
        ge=0,
        le=4294967295,
        description="최소 재고 수량",
    )

    target_stock_qty: int = Field(
        ge=0,
        le=4294967295,
        description="목표 재고 수량",
    )


class CosmeticCreateResponse(BaseModel):
    cosmetic_id: str
    registration_id: str
    message: str