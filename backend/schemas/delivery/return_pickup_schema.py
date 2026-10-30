from datetime import date
from pydantic import BaseModel


class ReturnPickupItem(BaseModel):
    return_id: str
    order_id: str
    order_item_id: str
    shipping_address: str
    return_reason: str
    return_quantity: int
    return_status: str
    pickup_status: str
    requested_on: date
    pickup_requested_on: date | None = None
    pickup_completed_on: date | None = None
