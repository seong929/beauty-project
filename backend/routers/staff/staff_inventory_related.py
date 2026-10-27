
import logging

from enum import Enum
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Path, Query

import services.staff.staff_inventory_service as staff_inventory_service
from services.staff.staff_auth_service import require_staff

logger = logging.getLogger(__name__)

router = APIRouter(
    prefix="/staff",
    tags=["직원-재고"],
    dependencies=[Depends(require_staff)]
)


class InventoryStatus(str, Enum):
    MAINTAIN = "MAINTAIN"
    HOLD = "HOLD"
    DISCARD = "DISCARD"


class SaleOption(str, Enum):
    NORMAL = "NORMAL"
    NEAR_EXPIRY = "NEAR_EXPIRY"


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
      - DISCARD: 폐기
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
        InventoryStatus | None,
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
