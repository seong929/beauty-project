
from datetime import date, datetime
from pydantic import BaseModel


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
