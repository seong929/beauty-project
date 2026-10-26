def next_sequence(cursor, scope_name):
    """호출자가 시작한 트랜잭션 안에서 순번을 발급한다."""
    cursor.execute(
        """
        INSERT INTO id_counters (scope_name, `last_value`)
        VALUES (%s, LAST_INSERT_ID(1))
        ON DUPLICATE KEY UPDATE
            `last_value` = LAST_INSERT_ID(`last_value` + 1)
        """,
        (scope_name,),
    )
    cursor.execute("SELECT LAST_INSERT_ID() AS seq")
    return cursor.fetchone()["seq"]


def get_account_status(cursor, customer_id):
    cursor.execute(
        """
        SELECT account_status
        FROM customer_account_status_history
        WHERE customer_id = %s
        ORDER BY changed_on DESC,
                 CAST(SUBSTRING(status_history_id, 5) AS UNSIGNED) DESC
        LIMIT 1
        """,
        (customer_id,),
    )
    row = cursor.fetchone()
    # 상태 이력이 없는 기존 고객은 활성 회원으로 취급한다.
    return row["account_status"] if row else "ACTIVE"


def append_account_status(cursor, customer_id, account_status):
    seq = next_sequence(cursor, "history:customer_account_status_history")
    cursor.execute(
        """
        INSERT INTO customer_account_status_history (
            status_history_id, customer_id, changed_on, account_status
        )
        VALUES (%s, %s, CURRENT_DATE(), %s)
        """,
        (f"csh_{seq}", customer_id, account_status),
    )
