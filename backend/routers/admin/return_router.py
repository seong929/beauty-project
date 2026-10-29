from fastapi import APIRouter, Depends
from schemas.admin.return_schema import (ReturnDecisionRequest, ReturnPickupRequest, ReturnPickupStatusRequest, ReturnReceiveRequest, ReturnInspectionRequest)
from services.admin.return_service import (get_return_list, decide_return, assign_return_pickup, update_return_pickup_status, receive_return, complete_return_inspection)
from services.staff.staff_auth_service import require_authenticated_staff, require_matching_employee


router = APIRouter(
    prefix="/admin",
    tags=["본사 관리자"],
)

# 반품 요청 목록 조회
@router.get(
    "/returns",
    summary="반품 요청 목록 조회",
)
def read_return_list(employee: dict = Depends(require_authenticated_staff)):
    return get_return_list()

# 반품 승인 및 반려
@router.patch(
    "/returns/{return_id}/decision",
    summary="반품 승인 및 반려",
)
def update_return_decision(
    return_id: str,
    data: ReturnDecisionRequest,
    employee: dict = Depends(require_authenticated_staff),
):
    require_matching_employee(employee, data.employee_id)
    return decide_return(return_id, data)

# 기존 배송업체에 반품 회수 요청
@router.post(
    "/returns/{return_id}/pickup",
    summary="반품 회수 요청",
)
def create_return_pickup(
    return_id: str,
    data: ReturnPickupRequest,
    employee: dict = Depends(require_authenticated_staff),
):
    require_matching_employee(employee, data.employee_id)
    return assign_return_pickup(
        return_id,
        data.employee_id,
    )

# 반품 회수 상태 변경
@router.patch(
    "/returns/{return_id}/pickup-status",
    summary="반품 회수 상태 변경",
)
def change_return_pickup_status(
    return_id: str,
    data: ReturnPickupStatusRequest,
    employee: dict = Depends(require_authenticated_staff),
):
    require_matching_employee(employee, data.employee_id)
    return update_return_pickup_status(
        return_id,
        data,
    )


# 본사 반품 상품 수령
@router.patch(
    "/returns/{return_id}/receive",
    summary="반품 상품 본사 수령",
)
def receive_return_item(
    return_id: str,
    data: ReturnReceiveRequest,
    employee: dict = Depends(require_authenticated_staff),
):
    require_matching_employee(employee, data.employee_id)
    return receive_return(
        return_id,
        data.employee_id,
    )


# 반품 상품 검수 완료
@router.patch(
    "/returns/{return_id}/inspection",
    summary="반품 검수 및 완료 처리",
)
def inspect_return_item(
    return_id: str,
    data: ReturnInspectionRequest,
    employee: dict = Depends(require_authenticated_staff),
):
    require_matching_employee(employee, data.employee_id)
    return complete_return_inspection(
        return_id,
        data,
    )
