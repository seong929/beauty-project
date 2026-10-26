
from fastapi import APIRouter

from schemas.admin.approval_schema import ApprovalListItem
from services.admin.approval_service import get_approval_list


router = APIRouter(
    prefix="/admin",
    tags=["본사 관리자"],
)

# 등록된 품의 목록과 결재 상태 반환
@router.get(
    "/approvals",
    response_model=list[ApprovalListItem],
)
def read_approval_list():
    return get_approval_list()
