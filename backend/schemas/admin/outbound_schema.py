
from pydantic import BaseModel, Field


class OutboundCreateRequest(BaseModel):
    order_id: str = Field(min_length=1, max_length=48)
    carrier_id: str = Field(min_length=1, max_length=48)


class OutboundCreateResponse(BaseModel):
    delivery_id: str
    order_id: str
    delivery_seq: int
    carrier_id: str
    order_status: str
    delivery_status: str
    message: str
