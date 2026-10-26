from datetime import date, datetime
from typing import Literal
from pydantic import BaseModel, Field

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

class ApprovalDecisionRequest(BaseModel):
    employee_id: str = Field(
        min_length=1,
        max_length=48,
        description="결재 처리 관리자 ID",
    )

    decision_status: Literal["APPROVED", "REJECTED"] = Field(
        description="결재 상태 (승인 또는 반려)",
    )
