from fastapi import HTTPException

from database import get_connection
from schemas.admin.inbound_schema import InboundCreateRequest


def create_inbound(data: InboundCreateRequest):
    conn = get_connection()

    try:
        with conn.cursor() as cursor:
            # 1. 본사 직원 권한 확인
            cursor.execute(
                """
                SELECT employee_role
                FROM employees
                WHERE employee_id = %s
                """,
                (data.employee_id,),
            )
            employee = cursor.fetchone()

            if employee is None:
                raise HTTPException(
                    status_code=404,
                    detail="존재하지 않는 직원입니다.",
                )

            if employee["employee_role"] not in ("STAFF", "ADMIN"):
                raise HTTPException(
                    status_code=403,
                    detail="본사 직원 또는 관리자만 입고 처리할 수 있습니다.",
                )

            # 2. 발주 조회 및 잠금
            cursor.execute(
                """
                SELECT
                    po.purchase_order_id,
                    po.order_quantity,
                    po.purchase_status,
                    a.cosmetic_id
                FROM purchase_orders AS po
                JOIN approvals AS a
                    ON po.approval_id = a.approval_id
                WHERE po.purchase_order_id = %s
                FOR UPDATE
                """,
                (data.purchase_order_id,),
            )
            purchase_order = cursor.fetchone()

            if purchase_order is None:
                raise HTTPException(
                    status_code=404,
                    detail="존재하지 않는 발주입니다.",
                )

            if purchase_order["purchase_status"] not in (
                "ORDERED",
                "PARTIALLY_RECEIVED",
            ):
                raise HTTPException(
                    status_code=409,
                    detail="입고 처리할 수 없는 발주 상태입니다.",
                )

            # 3. 기존 입고 수량 및 마지막 순번 조회
            cursor.execute(
                """
                SELECT
                    COALESCE(SUM(inbound_quantity), 0) AS total_received,
                    COALESCE(MAX(inbound_seq), 0) AS last_seq
                FROM inbound_history
                WHERE purchase_order_id = %s
                """,
                (data.purchase_order_id,),
            )
            inbound_summary = cursor.fetchone()

            total_received = int(inbound_summary["total_received"])
            last_seq = int(inbound_summary["last_seq"])

            # 4. 발주 수량 초과 방지
            order_quantity = int(purchase_order["order_quantity"])
            new_total = total_received + data.inbound_quantity

            if new_total > order_quantity:
                raise HTTPException(
                    status_code=409,
                    detail="입고 수량이 남은 발주 수량을 초과합니다.",
                )

            # 5. 입고 ID 및 재고 ID 생성
            inbound_seq = last_seq + 1
            inbound_id = (
                f"{data.purchase_order_id}_{inbound_seq}"
            )
            inventory_id = f"inv_{inbound_id}"

            # 6. 재고 생성
            cursor.execute(
                """
                INSERT INTO product_inventory (
                    inventory_id,
                    cosmetic_id,
                    stock_quantity,
                    received_on,
                    expires_on,
                    inventory_status,
                    sale_option
                )
                VALUES (
                    %s, %s, %s, %s, %s,
                    'MAINTAIN', 'NORMAL'
                )
                """,
                (
                    inventory_id,
                    purchase_order["cosmetic_id"],
                    data.inbound_quantity,
                    data.inbound_on,
                    data.expires_on,
                ),
            )

            # 7. 입고 이력 저장
            cursor.execute(
                """
                INSERT INTO inbound_history (
                    inbound_id,
                    inventory_id,
                    purchase_order_id,
                    inbound_seq,
                    inbound_quantity,
                    inbound_on
                )
                VALUES (%s, %s, %s, %s, %s, %s)
                """,
                (
                    inbound_id,
                    inventory_id,
                    data.purchase_order_id,
                    inbound_seq,
                    data.inbound_quantity,
                    data.inbound_on,
                ),
            )

            # 8. 발주 상태 변경
            if new_total == order_quantity:
                purchase_status = "RECEIVED"
            else:
                purchase_status = "PARTIALLY_RECEIVED"

            cursor.execute(
                """
                UPDATE purchase_orders
                SET purchase_status = %s
                WHERE purchase_order_id = %s
                """,
                (
                    purchase_status,
                    data.purchase_order_id,
                ),
            )

        conn.commit()

        return {
            "inbound_id": inbound_id,
            "inventory_id": inventory_id,
            "purchase_order_id": data.purchase_order_id,
            "inbound_seq": inbound_seq,
            "inbound_quantity": data.inbound_quantity,
            "total_received_quantity": new_total,
            "remaining_quantity": order_quantity - new_total,
            "purchase_status": purchase_status,
            "message": "입고 처리가 완료되었습니다.",
        }

    except Exception:
        conn.rollback()
        raise

    finally:
        conn.close()
