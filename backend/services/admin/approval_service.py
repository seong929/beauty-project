# 발주 목록 조회, 추후 승인·반려

from database import get_connection
from fastapi import HTTPException
from schemas.admin.approval_schema import ApprovalDecisionRequest

def get_approval_list():
    conn = get_connection()

    try:
        with conn.cursor() as cursor:
            sql = """
                SELECT
                    a.approval_id,
                    a.cosmetic_id,
                    c.cosmetic_name,
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
                                 ash.status_history_id DESC
                        LIMIT 1
                    ) AS approval_status,

                    d.decision_id,
                    d.decision_status,
                    d.employee_id,
                    d.decided_at

                FROM approvals AS a

                JOIN cosmetics AS c
                    ON a.cosmetic_id = c.cosmetic_id

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
                SELECT approval_id
                FROM approvals
                WHERE approval_id = %s
                FOR UPDATE
                """,
                (approval_id,),
            )

            if cursor.fetchone() is None:
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

            if decision["employee_id"] != data.employee_id:
                raise HTTPException(
                    status_code=403,
                    detail="지정된 결재 담당자가 아닙니다.",
                )

            # 5. 결재 상태 변경
            cursor.execute(
                """
                UPDATE approval_decisions
                SET decision_status = %s,
                    decided_at = NOW()
                WHERE decision_id = %s
                  AND decision_status = 'PENDING'
                """,
                (data.decision_status, decision["decision_id"]),
            )

            if cursor.rowcount != 1:
                raise HTTPException(
                    status_code=409,
                    detail="결재 상태 변경에 실패했습니다.",
                )

            # 6. 상태 이력 ID 생성
            cursor.execute(
                """
                INSERT INTO id_counters (
                    scope_name,
                    `last_value`
                )
                VALUES (
                    'history:approval_status_history',
                    LAST_INSERT_ID(1)
                )
                ON DUPLICATE KEY UPDATE
                    `last_value` =
                        LAST_INSERT_ID(`last_value` + 1)
                """
            )

            cursor.execute(
                "SELECT LAST_INSERT_ID() AS seq"
            )
            seq = cursor.fetchone()["seq"]
            status_history_id = f"ash_{seq}"

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

        conn.commit()

        return {
            "approval_id": approval_id,
            "decision_id": decision["decision_id"],
            "decision_status": data.decision_status,
            "status_history_id": status_history_id,
            "message": "결재 처리가 완료되었습니다.",
        }

    except Exception:
        conn.rollback()
        raise

    finally:
        conn.close()
