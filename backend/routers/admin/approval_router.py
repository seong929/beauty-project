
from fastapi import APIRouter, Depends

from schemas.admin.approval_schema import (ApprovalListItem, ApprovalDecisionRequest)
from services.admin.approval_service import (get_approval_list, decide_approval)
from services.staff.staff_auth_service import require_admin, require_matching_employee


router = APIRouter(
    prefix="/admin",
    tags=["본사 관리자"],
    )

# 품의 목록 조회
@router.get(
    "/approvals",
    response_model=list[ApprovalListItem],
    summary="품의 목록 조회",
    )
def read_approval_list(employee: dict = Depends(require_admin)):
    return get_approval_list()

# 품의 승인 및 반려
@router.patch(
        "/approvals/{approval_id}/decision", 
        summary="품의 승인 및 반려"
    )
def update_approval_decision(
    approval_id: str,
    data: ApprovalDecisionRequest,
    employee: dict = Depends(require_admin),
):
    require_matching_employee(employee, data.employee_id)
    return decide_approval(approval_id, data)
