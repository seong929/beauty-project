from fastapi import APIRouter, Depends
from schemas.staff.orders import (OrderListQuery, OrderListResponse)
import services.staff.staff_service as staff_service

router = APIRouter(
    prefix="/staff",
    tags=["직원"],
)

#현재 활성화 중인 주문 목록 조회
@router.get(
    "/available",
    response_model=OrderListResponse
)
def get_available_orders(
    query: OrderListQuery = Depends()
):
    rows = staff_service.get_available_order_list_from_page(
        page=query.page,
        count=query.count,
        asc=query.asc
    )

    return {"orders": rows}