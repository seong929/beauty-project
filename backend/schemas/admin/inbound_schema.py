from datetime import date
from pydantic import BaseModel, Field, model_validator


class InboundCreateRequest(BaseModel):
    purchase_order_id: str
    employee_id: str
    inbound_quantity: int = Field(gt=0)
    inbound_on: date
    expires_on: date | None = None

    @model_validator(mode="after")
    def validate_expiry(self):
        if self.expires_on is not None and self.expires_on < self.inbound_on:
            raise ValueError("사용기한은 입고일보다 빠를 수 없습니다.")
        return self


class InboundCreateResponse(BaseModel):
    inbound_id: str
    inventory_id: str
    purchase_order_id: str
    inbound_seq: int
    inbound_quantity: int
    total_received_quantity: int
    remaining_quantity: int
    purchase_status: str
    message: str
