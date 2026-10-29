
import logging
from datetime import datetime, timedelta
import calendar

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
from services.staff.staff_auth_service import require_staff
from routers.staff.staff_auth_related import router as staff_auth_router

logger = logging.getLogger(__name__)

router = APIRouter(
    prefix="/staff",
    tags=["직원-주문"],
)


# 주문 생성일 범위: 연/월/일/시/분을 계층적으로 지정합니다.
def _date_edge(
    label: str, year: int | None, month: int | None, day: int | None,
    hour: int | None, minute: int | None, *, upper: bool
) -> datetime | None:
    parts = (year, month, day, hour, minute)
    if all(part is None for part in parts):
        return None
    # 하위 단위가 있으면 상위 단위가 모두 있어야 합니다.
    if year is None or (month is None and any(p is not None for p in parts[2:])) \
            or (day is None and any(p is not None for p in parts[3:])) \
            or (hour is None and minute is not None):
        raise HTTPException(
            status_code=422,
            detail=f"{label}: 연 → 월 → 일 → 시 → 분 순으로 입력해야 합니다. 상위 단위를 생략할 수 없습니다."
        )
    if not (1 <= year <= 9998):
        raise HTTPException(status_code=422, detail=f"{label}: 연도는 1~9998 범위여야 합니다.")
    if month is not None and not (1 <= month <= 12):
        raise HTTPException(status_code=422, detail=f"{label}: 월은 1~12 범위여야 합니다.")
    if day is not None and not (1 <= day <= calendar.monthrange(year, month)[1]):
        raise HTTPException(status_code=422, detail=f"{label}: 해당 월에 존재하지 않는 날짜입니다.")
    if hour is not None and not (0 <= hour <= 23):
        raise HTTPException(status_code=422, detail=f"{label}: 시는 0~23 범위여야 합니다.")
    if minute is not None and not (0 <= minute <= 59):
        raise HTTPException(status_code=422, detail=f"{label}: 분은 0~59 범위여야 합니다.")

    start = datetime(year, month or 1, day or 1, hour or 0, minute or 0)
    if not upper:
        return start
    # 종료 범위는 사용자가 지정한 마지막 단위 전체를 포함시킵니다.
    if month is None:
        return datetime(year + 1, 1, 1)
    if day is None:
        return datetime(year + 1, 1, 1) if month == 12 else datetime(year, month + 1, 1)
    if hour is None:
        return start + timedelta(days=1)
    if minute is None:
        return start + timedelta(hours=1)
    return start + timedelta(minutes=1)


# 현재 활성화 중인 선택한 상태들의 주문 목록 조회
@router.get(
    "/order/available",
    response_model=order_schema.OrderListResponse,
    dependencies=[Depends(require_staff)],
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
    - start_/end_ 의 연·월·일·시·분을 선택적으로 지정해 주문 생성일 범위를 조회합니다.
    - 하위 단위 생략 시 그 상위 단위 전체를 포함하며, 상위 단위 누락은 422 오류입니다.
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
        Query(description="특정 고객의 주문만 조회할 경우 고객 ID 입력")
    ] = None,
    start_year: int | None = Query(default=None, description="시작 연도"),
    start_month: int | None = Query(default=None, description="시작 월 (연 필수)"),
    start_day: int | None = Query(default=None, description="시작 일 (연/월 필수)"),
    start_hour: int | None = Query(default=None, description="시작 시 (연/월/일 필수)"),
    start_minute: int | None = Query(default=None, description="시작 분 (시 필수)"),
    end_year: int | None = Query(default=None, description="종료 연도"),
    end_month: int | None = Query(default=None, description="종료 월 (연 필수)"),
    end_day: int | None = Query(default=None, description="종료 일 (연/월 필수)"),
    end_hour: int | None = Query(default=None, description="종료 시 (연/월/일 필수)"),
    end_minute: int | None = Query(default=None, description="종료 분 (시 필수)"),
):
    start_at = _date_edge(
        "시작", start_year, start_month, start_day, start_hour, start_minute, upper=False
    )
    end_before = _date_edge(
        "종료", end_year, end_month, end_day, end_hour, end_minute, upper=True
    )
    if start_at is not None and end_before is not None and start_at >= end_before:
        raise HTTPException(status_code=422, detail="시작 시각은 종료 범위의 끝보다 빨라야 합니다.")

    try:
        rows = staff_order_service.get_available_order_list_from_page(
            page=query.page,
            count=query.count,
            asc=query.asc,
            statuses=(
                [status.value for status in statuses]
                if statuses else None
            ),
            customer_id=customer_id,
            start_at=start_at,
            end_before=end_before,
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
    dependencies=[Depends(require_staff)],
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
    dependencies=[Depends(require_staff)],
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
    dependencies=[Depends(require_staff)],
    description="""
    특정 주문의 주문 상태를 변경합니다.

    **허용되는 유일한 일반 상태 변경**
    - `PAID -> PREPARING`: 직원이 결제 완료된 주문의 상품 준비 시작

    **이 API에서 금지되는 상태 변경**
    - PENDING -> PAID: 결제 흐름 전용
    - PREPARING -> SHIPPED: 전용 출고 API
    - SHIPPED -> DELIVERED: 배송 상태 확인/완료 처리 전용
    - CANCELLED / RETURNED: 취소·환불·반품 전용
    - 상태 되돌리기 및 그 외 임의 변경

    변경 가능한 상태와 현재 상태를 모두 서버에서 검사합니다.
    다른 상태 변경 요청은 409 Conflict로 거절합니다.
    """,
    responses={
        400: {"description": "주문 번호가 올바르지 않음"},
        404: {"description": "해당 주문이 존재하지 않음"},
        409: {"description": "허용되지 않는 주문 상태 변경"},
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
