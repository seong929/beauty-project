
import logging

from typing import Annotated
from fastapi import (
    APIRouter,
    Depends,
    HTTPException,
    Query,
    Path
)

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
    response_model=order_schema.OrderListResponse,
    summary="주문 목록 조회",
    description="""
    진행 중인 주문 목록을 페이지 단위로 조회합니다.

    **조회 기능**
    - 주문 상태에 따른 필터링 (복수 선택 가능)
    - 특정 고객 ID에 따른 필터링
    - 주문 번호 기준 오름차순 및 내림차순 정렬
    - 페이지 번호 및 페이지당 조회 개수 설정

    **조회 조건**
    - 상태를 선택하지 않으면 기본적으로 진행 중인 주문만 조회합니다.
    - 여러 상태를 선택하면 해당 상태의 주문을 통합하여 조회합니다.
    - 고객 ID를 지정하면 해당 고객의 주문만 조회합니다.
    - 모든 조회 결과에는 페이지네이션이 적용됩니다.
    """,
    responses={
        400: {"description": "잘못된 페이지 번호 또는 조회 개수"},
        422: {"description": "요청 매개변수 검증 실패"},
        500: {"description": "주문 목록 조회 중 서버 오류"},
        503: {"description": "데이터베이스 연결 실패"}
    }
)
def get_available_orders(
    query: order_schema.OrderListQuery = Depends(),

    statuses: Annotated[
        list[order_schema.OrderStatus] | None,
        Query(
            description="조회할 주문 상태 (여러 상태 동시 선택 가능)"
        )
    ] = None,

    customer_id: Annotated[
        str | None,
        Query(
            description="특정 고객의 주문만 조회할 경우 고객 ID 입력"
        )
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
    response_model=list[order_schema.OrderItemResponse],
    summary="주문에 포함된 구매 상품 목록 조회",
    description="""
    특정 주문에 포함된 구매 상품들의 상세 정보를 조회합니다.

    **조회 정보**
    - 주문 상품 ID
    - 구매 수량 및 구매 당시 단가
    - 판매 옵션
    - 사용 및 적립 포인트
    - 상품 재고 ID 및 유통기한
    - 화장품 ID 및 상품명

    하나의 주문에 여러 상품이 포함된 경우
    해당 주문의 모든 구매 상품을 배열로 반환합니다.
    """,
    responses={
        400: {"description": "주문 번호가 올바르지 않음"},
        422: {"description": "요청 매개변수 검증 실패"},
        500: {"description": "주문 상품 조회 중 서버 오류"},
        503: {"description": "데이터베이스 연결 실패"}
    }
)
def get_order_items(
    order_id: Annotated[
        str,
        Path(description="구매 상품 목록을 조회할 주문 번호")
    ]
):
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


# 특정 주문의 상세 정보 조회
@router.get(
    "/orders/{order_id}",
    summary="주문 상세 정보 조회",
    description="""
    주문 번호를 이용하여 특정 주문의 상세 정보를 조회합니다.

    **조회 정보**
    - 주문 번호
    - 고객 ID
    - 주문 순번
    - 주문 상태
    - 주문 일시
    - 배송지 주소

    주문 상세 페이지에 진입할 때 사용하는 API입니다.

    구매 상품의 개별 정보는
    `GET /staff/orders/{order_id}/items` API에서 조회합니다.
    """,
    responses={
        400: {"description": "주문 번호가 올바르지 않음"},
        404: {"description": "해당 주문이 존재하지 않음"},
        500: {"description": "주문 상세 조회 중 서버 오류"},
        503: {"description": "데이터베이스 연결 실패"}
    }
)
def get_order_detail(
    order_id: Annotated[
        str,
        Path(description="상세 정보를 조회할 주문 번호")
    ]
):
    try:
        return staff_order_service.get_order_detail(order_id)

    except HTTPException:
        raise

    except Exception:
        logger.exception(
            "주문 상세 조회 중 예상치 못한 오류: order_id=%s",
            order_id
        )
        raise HTTPException(
            status_code=500,
            detail="주문 상세 정보를 불러오는 중 서버 오류가 발생했습니다."
        )


# 특정 주문 상태 변경
@router.patch(
    "/orders/{order_id}/status",
    summary="주문 상태 변경",
    description="""
    특정 주문의 주문 상태를 변경합니다.

    **변경 가능한 상태**
    - `PENDING`: 주문 대기
    - `PAID`: 결제 완료
    - `PREPARING`: 상품 준비 중
    - `SHIPPED`: 배송 중
    - `DELIVERED`: 배송 완료
    - `CANCELLED`: 주문 취소
    - `RETURNED`: 반품 완료

    **처리 방식**
    - 주문 번호로 변경 대상을 확인합니다.
    - 요청한 상태로 주문 상태를 변경합니다.
    - 변경에 성공하면 갱신된 주문 정보를 반환합니다.
    - 오류 발생 시 데이터베이스 변경을 취소합니다.

    현재 구현에서는 주문 상태 간 전환 순서를
    별도로 제한하지 않습니다.
    """,
    responses={
        400: {"description": "주문 번호가 올바르지 않음"},
        404: {"description": "해당 주문이 존재하지 않음"},
        409: {"description": "이미 동일한 주문 상태로 설정됨"},
        422: {"description": "주문 상태 입력값 검증 실패"},
        500: {"description": "주문 상태 변경 중 서버 오류"},
        503: {"description": "데이터베이스 연결 실패"}
    }
)
def update_order_status(
    order_id: Annotated[
        str,
        Path(description="상태를 변경할 주문 번호")
    ],
    request: order_schema.OrderStatusUpdate
):
    try:
        return staff_order_service.update_order_status(
            order_id=order_id,
            order_status=request.order_status.value
        )

    except HTTPException:
        raise

    except Exception:
        logger.exception(
            "주문 상태 변경 중 서버 오류: order_id=%s",
            order_id
        )
        raise HTTPException(
            status_code=500,
            detail="주문 상태 변경 중 서버 오류가 발생했습니다."
        )
