
from fastapi import APIRouter, Depends, HTTPException, status

from schemas.admin.approval_schema import (ApprovalListItem, ApprovalDecisionRequest)
from services.admin.approval_service import (get_approval_list, decide_approval)
from services.staff.staff_auth_service import require_staff


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
def read_approval_list():
    return get_approval_list()

# 품의 승인 및 반려
@router.patch(
        "/approvals/{approval_id}/decision", 
        summary="품의 승인 및 반려"
    )
def update_approval_decision(
    approval_id: str,
    data: ApprovalDecisionRequest,
    employee: dict = Depends(require_staff),
):
    # 1. 관리자 권한 확인
    if employee["employee_role"] != "ADMIN":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="관리자만 품의를 승인하거나 반려할 수 있습니다.",
        )

    # 2. 로그인한 관리자와 요청한 관리자 일치 여부 확인
    if employee["employee_id"] != data.employee_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="로그인한 관리자와 결재 요청자가 일치하지 않습니다.",
        )
    return decide_approval(approval_id, data)