
from fastapi import APIRouter

from schemas.admin.approval_schema import (ApprovalListItem, ApprovalDecisionRequest)
from services.admin.approval_service import (get_approval_list, decide_approval)


router = APIRouter(
    prefix="/admin",
    tags=["본사 관리자"],
    )

# 발주 목록 조회
@router.get(
    "/approvals",
    response_model=list[ApprovalListItem],
    summary="품의 목록 조회",
    )
def read_approval_list():
    return get_approval_list()

# 발주 승인 및 반려
@router.patch(
        "/approvals/{approval_id}/decision", 
        summary="품의 승인 및 반려"
    )
def update_approval_decision(
    approval_id: str,
    data: ApprovalDecisionRequest,
):
    return decide_approval(approval_id, data)