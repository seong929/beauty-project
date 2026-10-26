# 발주 목록 조회, 추후 승인·반려

from database import get_connection

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
