from fastapi import APIRouter, Depends
import schemas.staff.orders as order_schema
import services.staff.staff_service as staff_service

router = APIRouter(
    prefix="/staff",
    tags=["직원"],
)

#현재 활성화 중인 주문 목록 조회
@router.get(
    "/available",
    response_model=order_schema.OrderListResponse
)
def get_available_orders(
    query: order_schema.OrderListQuery = Depends()
):
    rows = staff_service.get_available_order_list_from_page(
        page=query.page,
        count=query.count,
        asc=query.asc
    )

    return {"orders": rows}

@router.get(
    "/orders/{order_id}/items",
    response_model=list[order_schema.OrderItemResponse]
)
def get_order_items(order_id: str):
    return staff_service.get_items_from_order(order_id)