from enum import Enum
from pydantic import BaseModel, Field


class InventoryStatus(str, Enum):
    MAINTAIN = "MAINTAIN"
    HOLD = "HOLD"
    DISCARD = "DISCARD"


class SaleOption(str, Enum):
    NORMAL = "NORMAL"
    NEAR_EXPIRY = "NEAR_EXPIRY"


class DiscardInventoryRequest(BaseModel):
    quantity: int = Field(
        gt=0,
        description="실제로 폐기할 재고 수량 (1 이상)"
    )
