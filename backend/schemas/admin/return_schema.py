from typing import Literal
from pydantic import BaseModel, Field


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
