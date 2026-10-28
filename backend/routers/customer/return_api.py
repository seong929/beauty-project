"""고객 반품 신청: 주문상품 단위 반품 요청을 등록합니다."""
import logging

import pymysql
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field, ConfigDict

from database import get_connection

router = APIRouter(tags=["반품 관리"])
logger = logging.getLogger(__name__)


class ReturnRequestCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")
    order_item_id: str = Field(min_length=1, max_length=72)
    return_reason: str = Field(min_length=1, max_length=500)
    return_quantity: int = Field(gt=0)


@router.post("/return_requests", status_code=201, summary="주문상품 반품 신청")
def create_return_request(data: ReturnRequestCreate):
    reason = data.return_reason.strip()
    if not reason:
        raise HTTPException(status_code=422, detail="반품 사유를 입력해야 합니다.")

    conn = None
    try:
        conn = get_connection()
        conn.begin()
        with conn.cursor() as cur:
            # 동일 주문상품의 동시 반품 신청을 직렬화합니다.
            cur.execute(
                """SELECT oi.order_item_id, oi.purchase_quantity, o.order_status
                   FROM order_items AS oi
                   JOIN orders AS o ON o.order_id = oi.order_id
                   WHERE oi.order_item_id = %s
                   FOR UPDATE""",
                (data.order_item_id,),
            )
            item = cur.fetchone()
            if item is None:
                raise HTTPException(status_code=404, detail="주문상품을 찾을 수 없습니다.")
            if item["order_status"] not in ("SHIPPED", "DELIVERED", "RETURNED"):
                raise HTTPException(status_code=409, detail="배송된 주문상품만 반품 신청할 수 있습니다.")

            cur.execute(
                """SELECT COALESCE(MAX(return_seq), 0) AS last_seq,
                          COALESCE(SUM(CASE WHEN return_status <> 'REJECTED'
                                            THEN return_quantity ELSE 0 END), 0) AS requested_qty
                   FROM return_requests
                   WHERE order_item_id = %s""",
                (data.order_item_id,),
            )
            summary = cur.fetchone()
            available = int(item["purchase_quantity"]) - int(summary["requested_qty"])
            if data.return_quantity > available:
                raise HTTPException(
                    status_code=409,
                    detail=f"반품 가능 수량을 초과했습니다. 남은 수량: {max(available, 0)}",
                )

            return_seq = int(summary["last_seq"]) + 1
            return_id = f"ret_{data.order_item_id}_{return_seq}"
            if len(return_id) > 100:
                raise HTTPException(status_code=409, detail="반품 번호가 DB 길이 제한을 초과했습니다.")

            cur.execute(
                """INSERT INTO return_requests
                      (return_id, order_item_id, return_seq,
                       requested_on, return_reason, return_quantity,
                       return_status, refund_status, pickup_status,
                       pickup_requested_on, pickup_completed_on,
                       headquarters_received_on, inspection_result)
                   VALUES (%s, %s, %s, CURDATE(), %s, %s,
                           'REQUESTED', 'PENDING', 'WAITING',
                           NULL, NULL, NULL, NULL)""",
                (return_id, data.order_item_id, return_seq, reason, data.return_quantity),
            )

            cur.execute("SELECT requested_on FROM return_requests WHERE return_id = %s", (return_id,))
            requested_on = cur.fetchone()["requested_on"]

        conn.commit()
        return {
            "return_id": return_id,
            "order_item_id": data.order_item_id,
            "return_seq": return_seq,
            "return_reason": reason,
            "return_quantity": data.return_quantity,
            "requested_on": requested_on.isoformat(),
            "return_status": "REQUESTED",
            "refund_status": "PENDING",
            "pickup_status": "WAITING",
        }
    except HTTPException:
        if conn is not None:
            conn.rollback()
        raise
    except pymysql.MySQLError:
        if conn is not None:
            conn.rollback()
        logger.exception("반품 신청 SQL 실패: order_item_id=%s", data.order_item_id)
        raise HTTPException(status_code=500, detail="반품 신청 DB 처리 중 오류가 발생했습니다.")
    finally:
        if conn is not None:
            conn.close()
