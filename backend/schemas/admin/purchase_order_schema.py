
from decimal import Decimal
from pydantic import BaseModel, Field
from datetime import date


class PurchaseOrderCreateRequest(BaseModel):
    approval_id: str
    manufacturer_id: str
    unit_supply_price: Decimal = Field(gt=0)


class PurchaseOrderCreateResponse(BaseModel):
    purchase_order_id: str
    approval_id: str
    purchase_order_seq: int
    manufacturer_id: str
    order_quantity: int
    unit_supply_price: Decimal
    order_total_amount: Decimal
    purchase_status: str
    message: str

class PurchaseOrderListResponse(BaseModel):
    purchase_order_id: str
    approval_id: str
    purchase_order_seq: int
    manufacturer_id: str
    manufacturer_name: str
    cosmetic_id: str
    cosmetic_name: str
    ordered_on: date
    order_quantity: int
    purchase_status: str
    unit_supply_price: Decimal
    order_total_amount: Decimal