# 발주 목록 조회, 추후 승인·반려

from database import get_connection
from fastapi import HTTPException
from schemas.admin.approval_schema import ApprovalDecisionRequest
from decimal import Decimal
from services.system.automatic_approval_service import _allocate_id

def get_approval_list():
    conn = get_connection()

    try:
        with conn.cursor() as cursor:
            sql = """
                SELECT
                    a.approval_id,
                    a.cosmetic_id,
                    c.cosmetic_name,
                    c.manufacturer_id,
                    m.manufacturer_name,
                    c.category_id,
                    c.cosmetic_name_seq,
                    (SELECT h.unit_cost FROM cosmetic_cost_history h
                     WHERE h.cosmetic_id = c.cosmetic_id
                     ORDER BY h.changed_on DESC, CAST(SUBSTRING(h.change_id, 5) AS UNSIGNED) DESC LIMIT 1) AS unit_cost,
                    (SELECT v.volume_text FROM cosmetic_volume_history v
                     WHERE v.cosmetic_id = c.cosmetic_id
                     ORDER BY v.changed_on DESC, CAST(SUBSTRING(v.change_id, 5) AS UNSIGNED) DESC LIMIT 1) AS volume_text,
                    (SELECT po.purchase_order_id FROM purchase_orders po
                     WHERE po.approval_id = a.approval_id ORDER BY po.purchase_order_seq LIMIT 1) AS purchase_order_id,
                    (SELECT po.order_quantity FROM purchase_orders po
                     WHERE po.approval_id = a.approval_id ORDER BY po.purchase_order_seq LIMIT 1) AS order_quantity,
                    a.approval_seq,
                    a.target_stock_snapshot,
                    a.current_stock_snapshot,
                    a.requested_quantity,
                    a.approval_content,
                    a.requested_on,

                    (
                        SELECT ash.approval_status
                        FROM approval_status_history AS ash
                        WHERE ash.approval_id = a.approval_id
                        ORDER BY ash.changed_at DESC,
                                 CAST(SUBSTRING(ash.status_history_id, 5) AS UNSIGNED) DESC
                        LIMIT 1
                    ) AS approval_status,

                    d.decision_id,
                    d.decision_status,
                    d.employee_id,
                    d.decided_at

                FROM approvals AS a

                JOIN cosmetics AS c
                    ON a.cosmetic_id = c.cosmetic_id
                JOIN manufacturers AS m ON m.manufacturer_id = c.manufacturer_id

                LEFT JOIN approval_decisions AS d
                    ON d.decision_id = (
                        SELECT d2.decision_id
                        FROM approval_decisions AS d2
                        WHERE d2.approval_id = a.approval_id
                        ORDER BY
                            (d2.decided_at IS NULL) ASC,
                            d2.decided_at DESC,
                            d2.decision_id DESC
                        LIMIT 1
                    )

                ORDER BY a.requested_on DESC, a.approval_id DESC
            """

            cursor.execute(sql)
            result = cursor.fetchall()

        return result

    finally:
        conn.close()


def decide_approval(
    approval_id: str,
    data: ApprovalDecisionRequest,
):
    conn = get_connection()

    try:
        with conn.cursor() as cursor:
            # 1. 관리자 권한 확인
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

            if employee["employee_role"] != "ADMIN":
                raise HTTPException(
                    status_code=403,
                    detail="관리자만 결재할 수 있습니다.",
                )

            # 2. 품의 존재 여부 확인 및 잠금
            cursor.execute(
                """
                SELECT a.approval_id, c.manufacturer_id
                FROM approvals a
                JOIN cosmetics c ON c.cosmetic_id = a.cosmetic_id
                WHERE a.approval_id = %s
                FOR UPDATE
                """,
                (approval_id,),
            )

            approval = cursor.fetchone()
            if approval is None:
                raise HTTPException(
                    status_code=404,
                    detail="존재하지 않는 품의입니다.",
                )

            # 3. 최신 품의 상태 확인
            cursor.execute(
                """
                SELECT approval_status
                FROM approval_status_history
                WHERE approval_id = %s
                ORDER BY changed_at DESC,
                         CAST(SUBSTRING(status_history_id, 5)
                              AS UNSIGNED) DESC
                LIMIT 1
                """,
                (approval_id,),
            )

            status_row = cursor.fetchone()

            if (
                status_row is None
                or status_row["approval_status"] != "REQUESTED"
            ):
                raise HTTPException(
                    status_code=409,
                    detail="이미 처리되었거나 결재할 수 없는 품의입니다.",
                )

            # 4. 대기 중인 결재 정보 확인
            cursor.execute(
                """
                SELECT decision_id, employee_id
                FROM approval_decisions
                WHERE approval_id = %s
                  AND decision_status = 'PENDING'
                FOR UPDATE
                """,
                (approval_id,),
            )

            pending_rows = cursor.fetchall()

            if len(pending_rows) != 1:
                raise HTTPException(
                    status_code=409,
                    detail="결재 대기 정보가 정확히 1건이어야 합니다.",
                )

            decision = pending_rows[0]

            if data.decision_status == "APPROVED":
                if data.manufacturer_id != approval["manufacturer_id"]:
                    raise HTTPException(status_code=400, detail="해당 상품에 등록된 제조사만 발주처로 선택할 수 있습니다.")
                cursor.execute("SELECT purchase_order_id FROM purchase_orders WHERE approval_id = %s LIMIT 1", (approval_id,))
                if cursor.fetchone() is not None:
                    raise HTTPException(status_code=409, detail="이미 발주가 등록된 품의입니다.")
                total = Decimal(data.order_quantity) * data.unit_supply_price
                if total > Decimal("999999999999.99"):
                    raise HTTPException(status_code=422, detail="총 발주 금액이 허용 범위를 초과합니다.")

            # 5. 결재 상태 변경
            cursor.execute(
                """
                UPDATE approval_decisions
                SET decision_status = %s,
                    employee_id = %s,
                    decided_at = NOW()
                WHERE decision_id = %s
                  AND decision_status = 'PENDING'
                """,
                (data.decision_status, data.employee_id, decision["decision_id"]),
            )

            if cursor.rowcount != 1:
                raise HTTPException(
                    status_code=409,
                    detail="결재 상태 변경에 실패했습니다.",
                )

            # 6. 상태 이력 ID 생성
            status_history_id = _allocate_id(cursor, "history:approval_status_history", "approval_status_history", "status_history_id", "ash_")

            # 7. 품의 상태 변경 이력 추가
            cursor.execute(
                """
                INSERT INTO approval_status_history (
                    status_history_id,
                    approval_id,
                    approval_status,
                    changed_at
                )
                VALUES (%s, %s, %s, NOW())
                """,
                (
                    status_history_id,
                    approval_id,
                    data.decision_status,
                ),
            )

            purchase_order_id = None
            if data.decision_status == "APPROVED":
                purchase_order_id = f"{approval_id}_1"
                cursor.execute(
                    """INSERT INTO purchase_orders
                       (purchase_order_id, approval_id, purchase_order_seq, manufacturer_id,
                        ordered_on, order_quantity, purchase_status, unit_supply_price, order_total_amount)
                       VALUES (%s, %s, 1, %s, CURDATE(), %s, 'ORDERED', %s, %s)""",
                    (purchase_order_id, approval_id, data.manufacturer_id,
                     data.order_quantity, data.unit_supply_price, total),
                )

        conn.commit()

        return {
            "approval_id": approval_id,
            "decision_id": decision["decision_id"],
            "decision_status": data.decision_status,
            "status_history_id": status_history_id,
            "purchase_order_id": purchase_order_id,
            "message": "결재 처리가 완료되었습니다.",
        }

    except Exception:
        conn.rollback()
        raise

    finally:
        conn.close()
