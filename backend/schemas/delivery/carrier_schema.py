from pydantic import BaseModel, Field


class CarrierCreateRequest(BaseModel):
    carrier_id: str = Field(min_length=1, max_length=48, pattern=r"^car_[a-z0-9]+(_[a-z0-9]+)*$")
    carrier_name: str = Field(min_length=1, max_length=150)
    phone: str | None = Field(default=None, max_length=30)


class CarrierCreateResponse(BaseModel):
    carrier_id: str
    carrier_name: str
    phone: str | None
    message: str