from datetime import date, datetime
from typing import Literal
from pydantic import BaseModel, Field
from pydantic import model_validator
from decimal import Decimal

# 발주 목록 조회
class ApprovalListItem(BaseModel):
    approval_id: str
    cosmetic_id: str
    cosmetic_name: str
    approval_seq: int
    target_stock_snapshot: int
    current_stock_snapshot: int
    requested_quantity: int
    approval_content: str
    requested_on: date
    approval_status: str | None = None
    decision_id: str | None = None
    decision_status: str | None = None
    employee_id: str | None = None
    decided_at: datetime | None = None
    manufacturer_id: str | None = None
    manufacturer_name: str | None = None
    category_id: str | None = None
    cosmetic_name_seq: int | None = None
    volume_text: str | None = None
    unit_cost: Decimal | None = None
    purchase_order_id: str | None = None
    order_quantity: int | None = None

class ApprovalDecisionRequest(BaseModel):
    employee_id: str = Field(
        min_length=1,
        max_length=48,
        description="결재 처리 관리자 ID",
    )

    decision_status: Literal["APPROVED", "REJECTED"] = Field(
        description="결재 상태 (승인 또는 반려)",
    )

    manufacturer_id: str | None = Field(default=None, min_length=1, max_length=48)
    order_quantity: int | None = Field(default=None, gt=0, le=4294967295)
    unit_supply_price: Decimal | None = Field(default=None, gt=0, max_digits=12, decimal_places=2)

    @model_validator(mode="after")
    def check_order_details(self):
        if self.decision_status == "APPROVED" and (
            self.manufacturer_id is None or self.order_quantity is None or self.unit_supply_price is None
        ):
            raise ValueError("승인 시 발주처, 발주 수량, 공급 단가가 필요합니다.")
        if self.decision_status == "REJECTED" and any(
            value is not None for value in (self.manufacturer_id, self.order_quantity, self.unit_supply_price)
        ):
            raise ValueError("반려 시 발주 정보를 입력할 수 없습니다.")
        return self
