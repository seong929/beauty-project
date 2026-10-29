
import logging

from enum import Enum
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Path, Query

import services.staff.staff_inventory_service as staff_inventory_service
from services.staff.staff_auth_service import require_staff

from schemas.staff.inventory import (
    InventoryStatus,
    SaleOption,
    DiscardInventoryRequest
)

logger = logging.getLogger(__name__)

router = APIRouter(
    prefix="/staff",
    tags=["직원-재고"],
    dependencies=[Depends(require_staff)]
)

class InventoryFilterStatus(str, Enum):
    MAINTAIN = "MAINTAIN"
    HOLD = "HOLD"
    DISCARD = "DISCARD"
    DISCARD_COMPLETED = "DISCARD_COMPLETED"


class InventoryOrderBy(str, Enum):
    RECEIVED_ON = "received_on"
    EXPIRES_ON = "expires_on"


@router.get(
    "/cosmetics/{cosmetic_id}/inventory",
    summary="화장품 옵션별 재고 목록 조회",
    description="""
    특정 화장품 ID에 연결된 재고 목록을 조회합니다.

    **필터**
    - `inventory_status`: 재고 상태
      - MAINTAIN: 유지
      - HOLD: 보류
      - DISCARD: 폐기 대기 (수량 >= 1)
      - DISCARD_COMPLETED: 폐기 완료 (수량 = 0)
    - `sale_option`: 판매 옵션
      - NORMAL: 일반
      - NEAR_EXPIRY: 사용기한 임박

    필터를 생략하면 해당 조건을 적용하지 않습니다.
    두 필터를 모두 지정하면 AND 조건으로 검색합니다.

    **정렬**
    - `order_by`: 입고일(received_on) 또는 사용기한(expires_on)
    - `asc`: true이면 오름차순, false이면 내림차순

    기본 정렬은 입고일 내림차순입니다.

    **반환 정보**
    - 재고 ID
    - 화장품 ID
    - 재고 수량
    - 입고일
    - 사용기한
    - 재고 상태
    - 판매 옵션
    """,
    responses={
        400: {"description": "잘못된 조회 조건"},
        422: {"description": "요청 매개변수 검증 실패"},
        500: {"description": "재고 조회 중 서버 오류"},
        503: {"description": "데이터베이스 연결 실패"}
    }
)
def get_inventory_by_cosmetic_id(
    cosmetic_id: Annotated[
        str,
        Path(
            min_length=1,
            description="재고를 조회할 화장품 옵션 ID"
        )
    ],
    inventory_status: Annotated[
        InventoryFilterStatus | None,
        Query(description="재고 상태 필터 (생략 시 전체)")
    ] = None,
    sale_option: Annotated[
        SaleOption | None,
        Query(description="판매 옵션 필터 (생략 시 전체)")
    ] = None,
    order_by: Annotated[
        InventoryOrderBy,
        Query(description="정렬 기준: 입고일 또는 사용기한")
    ] = InventoryOrderBy.RECEIVED_ON,
    asc: Annotated[
        bool,
        Query(description="true: 오름차순, false: 내림차순")
    ] = False
):
    try:
        return staff_inventory_service.get_inventory_by_cosmetic_id(
            cosmetic_id=cosmetic_id,
            inventory_status=(
                inventory_status.value
                if inventory_status is not None
                else None
            ),
            sale_option=(
                sale_option.value
                if sale_option is not None
                else None
            ),
            order_by=order_by.value,
            asc=asc
        )

    except HTTPException:
        raise

    except Exception:
        logger.exception(
            "재고 목록 조회 중 예상치 못한 오류: cosmetic_id=%s",
            cosmetic_id
        )
        raise HTTPException(
            status_code=500,
            detail="재고 목록 조회 중 서버 오류가 발생했습니다."
        )

@router.get(
    "/inventory/by-status",
    summary="상태별 재고 분류 및 필터 조회",
    description=(
        "MAINTAIN, HOLD, DISCARD(수량>0), DISCARD_COMPLETED(수량=0) 상태별 재고 수량을 "
        "집계하고 조건에 맞는 재고 목록을 반환합니다."
    )
)
def get_inventory_grouped_by_status(
    inventory_status: InventoryFilterStatus | None = Query(
        default=None,
        description="조회할 재고 상태"
    ),
    cosmetic_id: str | None = Query(
        default=None,
        description="화장품 옵션 ID"
    ),
    sale_option: SaleOption | None = Query(
        default=None,
        description="판매 옵션"
    ),
    page: int = Query(default=1, ge=1, description="페이지 번호 (1부터)"),
    count: int = Query(default=20, ge=1, le=100, description="한 페이지의 재고 수"),
    descending: bool = Query(default=True, description="true: DISCARD부터, false: MAINTAIN부터")
):
    return staff_inventory_service.get_inventory_grouped_by_status(
        inventory_status=(
            inventory_status.value
            if inventory_status is not None else None
        ),
        cosmetic_id=cosmetic_id,
        sale_option=(
            sale_option.value
            if sale_option is not None else None
        ),
        page=page,
        count=count,
        descending=descending,
    )


@router.patch(
    "/inventory/{inventory_id}/discard",
    summary="DISCARD 재고 폐기 및 수량 차감",
    description=(
        "inventory_id를 기준으로 DISCARD 상태의 "
        "재고 수량을 차감합니다."
    ),
    responses={
        404: {"description": "재고 없음"},
        409: {"description": "재고 상태 불일치 또는 수량 부족"},
        503: {"description": "DB 연결 실패"}
    }
)
def discard_inventory(
    inventory_id: Annotated[
        str,
        Path(
            min_length=1,
            description="폐기할 재고 ID"
        )
    ],
    body: DiscardInventoryRequest
):
    return staff_inventory_service.discard_inventory_stock(
        inventory_id=inventory_id,
        quantity=body.quantity
    )



@router.get("/inventory/{inventory_id}/inbound", summary="재고 배치별 입고 이력 조회")
def get_inventory_inbound_history(
    inventory_id: str = Path(min_length=1, description="재고 배치 ID"),
):
    return staff_inventory_service.get_inventory_inbound_history(inventory_id)


@router.get("/inventory/{inventory_id}/outbounds", summary="재고 배치별 출고 예약·확정 이력 조회")
def get_inventory_outbound_history(
    inventory_id: str = Path(min_length=1, description="재고 배치 ID"),
    page: int = Query(default=1, ge=1, description="페이지 번호"),
    count: int = Query(default=20, ge=1, le=100, description="페이지당 출고 내역 건수"),
):
    return staff_inventory_service.get_inventory_outbound_history(inventory_id, page, count)


@router.get("/inventory/{inventory_id}", summary="재고 배치 상세 조회")
def get_inventory_detail(
    inventory_id: str = Path(min_length=1, description="재고 배치 ID"),
):
    return staff_inventory_service.get_inventory_detail(inventory_id)
