
import logging

from fastapi import APIRouter, Depends, HTTPException

import schemas.staff.orders as order_schema
import services.staff.staff_service as staff_service

logger = logging.getLogger(__name__)

router = APIRouter(
    prefix="/staff",
    tags=["직원"],
)


# 현재 활성화 중인 주문 목록 조회
@router.get(
    "/orders/available",
    response_model=order_schema.OrderListResponse
)
def get_available_orders(
    query: order_schema.OrderListQuery = Depends()
):
    try:
        rows = staff_service.get_available_order_list_from_page(
            page=query.page,
            count=query.count,
            asc=query.asc
        )

        return {"orders": rows}

    except HTTPException:
        # 서비스에서 발생한 400, 500, 503 오류를 그대로 전달
        raise

    except Exception:
        logger.exception("활성 주문 목록 조회 중 예상치 못한 오류")
        raise HTTPException(
            status_code=500,
            detail="활성 주문 목록을 불러오는 중 서버 오류가 발생했습니다."
        )


# 특정 주문에 포함된 구매 상품 목록 조회
@router.get(
    "/orders/{order_id}/items",
    response_model=list[order_schema.OrderItemResponse]
)
def get_order_items(order_id: str):
    try:
        return staff_service.get_items_from_order(order_id)

    except HTTPException:
        # 서비스에서 발생한 오류를 그대로 전달
        raise

    except Exception:
        logger.exception(
            "주문 상품 조회 중 예상치 못한 오류: order_id=%s",
            order_id
        )
        raise HTTPException(
            status_code=500,
            detail="주문 상품 정보를 불러오는 중 서버 오류가 발생했습니다."
        )
