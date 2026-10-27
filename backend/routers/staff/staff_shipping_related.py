"""직원 전용 주문 출고 API."""
from typing import Annotated
from fastapi import APIRouter, Depends, Path
from services.staff.staff_auth_service import require_staff
from services.staff.staff_shipping_service import ship_order_and_decrease_stock

router = APIRouter(tags=["직원-출고"], dependencies=[Depends(require_staff)])


@router.post(
    "/orders/{order_id}/ship",
    summary="주문 출고 및 재고 차감",
    description=(
        "PREPARING 주문을 SHIPPED로 변경하고 주문 상품별 재고를 차감합니다. "
        "주문 상태 변경과 모든 재고 차감은 하나의 트랜잭션으로 처리되어, "
        "하나라도 실패하면 모든 변경을 취소합니다. 중복 출고는 허용하지 않습니다."
    ),
    responses={
        401: {"description": "직원 인증 필요"},
        403: {"description": "직원 권한 없음"},
        404: {"description": "주문 없음"},
        409: {"description": "주문 상태 오류, 재고 부족 또는 출고 불가"},
        500: {"description": "DB/서버 처리 오류"},
        503: {"description": "DB 연결 실패"},
    },
)
def ship_order(
    order_id: Annotated[str, Path(min_length=1, description="출고할 주문 번호")]
):
    return ship_order_and_decrease_stock(order_id)
