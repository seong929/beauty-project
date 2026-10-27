
import logging

from typing import Annotated
from fastapi import APIRouter, HTTPException, Query, Path

import services.staff.staff_cosmetics_service as staff_cosmetics_service

logger = logging.getLogger(__name__)

router = APIRouter(
    prefix="/staff",
    tags=["직원-화장품"]
)


# 옵션별 중복을 제거한 화장품 목록 조회
@router.get(
    "/cosmetics/distinct",
    summary="화장품 종류 목록 조회",
    description="""
    옵션별 중복을 제거한 화장품 목록을 페이지 단위로 조회합니다.

    **조회 기능**
    - 동일한 화장품 이름과 카테고리의 중복 제거
    - 카테고리 ID를 이용한 필터링
    - 페이지 번호 및 페이지당 조회 개수 설정
    - 화장품 이름 기준 오름차순 정렬

    **조회 조건**
    - `category_id` 생략: 전체 카테고리 조회
    - `category_id` 입력: 해당 카테고리만 조회
    - `page`: 조회할 페이지 (기본값 1)
    - `count`: 페이지당 조회 개수 (기본값 20, 최대 100)

    상품 관리 및 재고 관리 화면에서 공통으로 사용합니다.
    """,
    responses={
        400: {"description": "잘못된 페이지 번호 또는 조회 개수"},
        422: {"description": "요청 매개변수 검증 실패"},
        500: {"description": "화장품 목록 조회 중 서버 오류"},
        503: {"description": "데이터베이스 연결 실패"}
    }
)
def get_distinct_cosmetics(
    page: Annotated[
        int,
        Query(
            ge=1,
            description="조회할 페이지 번호 (1부터 시작)"
        )
    ] = 1,

    count: Annotated[
        int,
        Query(
            ge=1,
            le=100,
            description="페이지당 조회할 화장품 종류 개수 (1~100)"
        )
    ] = 20,

    category_id: Annotated[
        str | None,
        Query(
            min_length=1,
            description="조회할 카테고리 ID (생략 시 전체 조회)"
        )
    ] = None
):
    try:
        return staff_cosmetics_service.get_distinct_cosmetics(
            page=page,
            count=count,
            category_id=category_id
        )

    except HTTPException:
        raise

    except Exception:
        logger.exception(
            "화장품 종류 목록 조회 중 예상치 못한 오류: "
            "page=%s, count=%s, category_id=%s",
            page,
            count,
            category_id
        )
        raise HTTPException(
            status_code=500,
            detail="화장품 목록 조회 중 서버 오류가 발생했습니다."
        )

# 특정 화장품 이름에 해당하는 옵션별 상품 목록 조회
@router.get(
    "/cosmetics/{cosmetic_name}/options",
    summary="화장품 옵션별 상품 목록 조회",
    description="""
    화장품 이름을 기준으로 등록된 모든 옵션별 상품을 조회합니다.

    **조회 방식**
    - 입력된 `cosmetic_name`과 동일한 이름의 화장품 검색
    - 옵션별로 구분된 개별 화장품 정보 반환
    - 각 옵션의 `cosmetic_id` 및 상품 정보 조회

    **활용 목적**
    - 상품 관리 화면에서 화장품 선택 시 옵션 목록 표시
    - 재고 관리 화면에서 화장품 선택 시 옵션 목록 표시

    실제 재고 수량이나 입고 이력은 조회하지 않습니다.
    """,
    responses={
        400: {"description": "화장품 이름이 입력되지 않음"},
        404: {"description": "해당 이름의 화장품이 존재하지 않음"},
        422: {"description": "요청 매개변수 검증 실패"},
        500: {"description": "화장품 옵션 조회 중 서버 오류"},
        503: {"description": "데이터베이스 연결 실패"}
    }
)
def get_cosmetic_options(
    cosmetic_name: Annotated[
        str,
        Path(
            min_length=1,
            description="옵션 목록을 조회할 화장품 이름"
        )
    ]
):
    try:
        return staff_cosmetics_service.get_cosmetic_options(
            cosmetic_name=cosmetic_name
        )

    except HTTPException:
        raise

    except Exception:
        logger.exception(
            "화장품 옵션 조회 중 예상치 못한 오류: cosmetic_name=%s",
            cosmetic_name
        )
        raise HTTPException(
            status_code=500,
            detail="화장품 옵션 조회 중 서버 오류가 발생했습니다."
        )