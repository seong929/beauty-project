from typing import Literal
from pydantic import BaseModel, Field, ConfigDict


# 반품 승인 및 반려 요청
class ReturnDecisionRequest(BaseModel):
    employee_id: str = Field(
        ...,
        min_length=1,
        max_length=48,
    )
    return_status: Literal["APPROVED", "REJECTED"]


# 반품 회수 요청
class ReturnPickupRequest(BaseModel):
    employee_id: str = Field(
        ...,
        min_length=1,
        max_length=48,
    )

# 반품 회수 상태 변경 요청
class ReturnPickupStatusRequest(BaseModel):
    employee_id: str = Field(
        ...,
        min_length=1,
        max_length=48,
    )
    pickup_status: Literal["COLLECTED", "FAILED"]

# 반품 상품 본사 수령 요청
class ReturnReceiveRequest(BaseModel):
    employee_id: str = Field(
        ...,
        min_length=1,
        max_length=48,
    )

# 반품 상품 검수 완료 요청
class ReturnInspectionRequest(BaseModel):
    employee_id: str = Field(
        ...,
        min_length=1,
        max_length=48,
    )
    inspection_result: str = Field(
        ...,
        min_length=1,
        max_length=500,
    )


class ReturnRefundStatusRequest(BaseModel):
    """내부 환불 업무 상태를 기록한다. 외부 결제 취소는 수행하지 않는다."""

    model_config = ConfigDict(extra="forbid")
    employee_id: str = Field(min_length=1, max_length=48)
    expected_refund_status: Literal["PENDING", "PROCESSING", "FAILED"]
    refund_status: Literal["PROCESSING", "FAILED", "COMPLETED"]
