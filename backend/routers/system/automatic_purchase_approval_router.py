
from fastapi import APIRouter, Depends

from services.staff.staff_auth_service import require_staff
from services.system.automatic_approval_service import (
    create_automatic_approvals
)


router = APIRouter(
    prefix="/system/automatic-approvals",
    tags=["시스템 자동 품의"]
)


@router.post(
    "/run",
    summary="재고 부족 화장품 자동 품의 생성",
    description=(
        "기존 품의에 등록된 화장품을 대상으로 "
        "현재 재고량과 최소 재고량을 비교하여 "
        "목표 재고량까지 보충하는 품의를 생성합니다."
    ),
    dependencies=[Depends(require_staff)]
)
def run_automatic_approvals():
    return create_automatic_approvals()
