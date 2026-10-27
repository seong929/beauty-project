
import logging

from typing import Annotated
from fastapi import APIRouter, Depends, HTTPException, Query

import schemas.staff.orders as order_schema
import services.staff.staff_order_service as staff_order_service

logger = logging.getLogger(__name__)

router = APIRouter(
    prefix="/staff",
    tags=["직원"],
)


# 현재 활성화 중인 선택한 상태들의 주문 목록 조회
@router.get(
    "/order/available",
    response_model=order_schema.OrderListResponse
)
def get_available_orders(
    query: order_schema.OrderListQuery = Depends(),

    statuses: Annotated[
        list[order_schema.OrderStatus] | None,
        Query(description="조회할 주문 상태 (다중 선택 가능)")
    ] = None,

    customer_id: Annotated[
        str | None,
        Query(description="특정 고객의 주문만 조회")
    ] = None
):
    try:
        rows = staff_order_service.get_available_order_list_from_page(
        page=query.page,
        count=query.count,
        asc=query.asc,
        statuses=(
            [status.value for status in statuses]
            if statuses else None
        ),
        customer_id=customer_id
        )

        return {"orders": rows}

    except HTTPException:
        raise

    except Exception:
        logger.exception("주문 목록 조회 중 예상치 못한 오류")
        raise HTTPException(
            status_code=500,
            detail="주문 목록 조회 중 서버 오류가 발생했습니다."
        )


# 특정 주문에 포함된 구매 상품 목록 조회
@router.get(
    "/orders/{order_id}/items",
    response_model=list[order_schema.OrderItemResponse]
)
def get_order_items(order_id: str):
    try:
        return staff_order_service.get_items_from_order(order_id)

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
