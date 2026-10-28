
import logging

import pymysql
from fastapi import HTTPException

from database import get_connection

logger = logging.getLogger(__name__)


def _allocate_id(cursor, scope, table, column, prefix):
    """
    id_counters를 사용해 전역 순번 생성.
    기존 예시 데이터의 높은 ID와 충돌하지 않도록 보정.
    table/column/prefix는 내부 상수만 사용.
    """
    cursor.execute(
        f"""
        SELECT COALESCE(
            MAX(CAST(SUBSTRING({column}, %s) AS UNSIGNED)),
            0
        ) AS maximum
        FROM {table}
        """,
        (len(prefix) + 1,)
    )
    minimum = int(cursor.fetchone()["maximum"]) + 1

    cursor.execute(
        """
        INSERT INTO id_counters (scope_name, `last_value`)
        VALUES (%s, LAST_INSERT_ID(%s))
        ON DUPLICATE KEY UPDATE
            `last_value` = LAST_INSERT_ID(
                GREATEST(`last_value` + 1, %s)
            )
        """,
        (scope, minimum, minimum)
    )
    cursor.execute("SELECT LAST_INSERT_ID() AS seq")
    return f"{prefix}{cursor.fetchone()['seq']}"


def _process_cosmetic(cosmetic_id: str) -> dict:
    conn = get_connection()

    try:
        with conn.cursor() as cursor:
            # 1. 같은 화장품의 자동 품의 생성 직렬화
            cursor.execute(
                """
                SELECT cosmetic_id
                FROM cosmetics
                WHERE cosmetic_id = %s
                FOR UPDATE
                """,
                (cosmetic_id,)
            )

            if cursor.fetchone() is None:
                return {
                    "cosmetic_id": cosmetic_id,
                    "result": "NOT_FOUND"
                }

            # 2. 현재 판매 상태 조회
            cursor.execute(
                """
                SELECT sale_status
                FROM cosmetic_sale_status_history
                WHERE cosmetic_id = %s
                ORDER BY changed_on DESC, change_id DESC
                LIMIT 1
                """,
                (cosmetic_id,)
            )
            sale = cursor.fetchone()

            if sale is None or sale["sale_status"] != "ON_SALE":
                return {
                    "cosmetic_id": cosmetic_id,
                    "result": "NOT_ON_SALE"
                }

            # 3. 최신 최소 / 목표 재고 설정
            cursor.execute(
                """
                SELECT min_stock_qty
                FROM cosmetic_min_stock_history
                WHERE cosmetic_id = %s
                ORDER BY changed_on DESC,
                         CAST(SUBSTRING(change_id, 5)
                              AS UNSIGNED) DESC
                LIMIT 1
                """,
                (cosmetic_id,)
            )
            minimum = cursor.fetchone()

            cursor.execute(
                """
                SELECT target_stock_qty
                FROM cosmetic_target_stock_history
                WHERE cosmetic_id = %s
                ORDER BY changed_on DESC,
                         CAST(SUBSTRING(change_id, 5)
                              AS UNSIGNED) DESC
                LIMIT 1
                """,
                (cosmetic_id,)
            )
            target = cursor.fetchone()

            if minimum is None or target is None:
                return {
                    "cosmetic_id": cosmetic_id,
                    "result": "SETTING_MISSING"
                }

            minimum_qty = int(minimum["min_stock_qty"])
            target_qty = int(target["target_stock_qty"])

            if target_qty <= minimum_qty:
                return {
                    "cosmetic_id": cosmetic_id,
                    "result": "INVALID_SETTING"
                }

            # 4. 판매 가능한 재고만 합산
            cursor.execute(
                """
                SELECT COALESCE(
                    SUM(stock_quantity), 0
                ) AS current_qty
                FROM product_inventory
                WHERE cosmetic_id = %s
                  AND inventory_status = 'MAINTAIN'
                """,
                (cosmetic_id,)
            )
            current_qty = int(
                cursor.fetchone()["current_qty"]
            )

            if current_qty >= minimum_qty:
                return {
                    "cosmetic_id": cosmetic_id,
                    "result": "SUFFICIENT",
                    "current_quantity": current_qty
                }

            # 5. 기존 미완료 품의 확인
            cursor.execute(
                """
                SELECT a.approval_id
                FROM approvals a
                WHERE a.cosmetic_id = %s
                  AND (
                    SELECT h.approval_status
                    FROM approval_status_history h
                    WHERE h.approval_id = a.approval_id
                    ORDER BY h.changed_at DESC,
                        CAST(SUBSTRING(
                            h.status_history_id, 5
                        ) AS UNSIGNED) DESC
                    LIMIT 1
                  ) IN ('REQUESTED', 'APPROVED')
                  AND (
                    NOT EXISTS (
                        SELECT 1
                        FROM purchase_orders po
                        WHERE po.approval_id = a.approval_id
                    )
                    OR EXISTS (
                        SELECT 1
                        FROM purchase_orders po
                        WHERE po.approval_id = a.approval_id
                          AND po.purchase_status NOT IN (
                              'RECEIVED', 'CANCELLED'
                          )
                    )
                  )
                LIMIT 1
                """,
                (cosmetic_id,)
            )

            existing = cursor.fetchone()

            if existing is not None:
                return {
                    "cosmetic_id": cosmetic_id,
                    "result": "OPEN_APPROVAL_EXISTS",
                    "approval_id": existing["approval_id"]
                }

            # 6. 결재 담당자 선택
            # 실제 담당자 배정 정책이 없다면
            # 첫 번째 ADMIN을 임시 담당자로 선택
            cursor.execute(
                """
                SELECT employee_id
                FROM employees
                WHERE employee_role = 'ADMIN'
                ORDER BY employee_id
                LIMIT 1
                """
            )
            admin = cursor.fetchone()

            if admin is None:
                return {
                    "cosmetic_id": cosmetic_id,
                    "result": "ADMIN_MISSING"
                }

            # 7. 화장품별 품의 순번 생성
            cursor.execute(
                """
                SELECT COALESCE(MAX(approval_seq), 0) AS seq
                FROM approvals
                WHERE cosmetic_id = %s
                """,
                (cosmetic_id,)
            )

            seq = int(cursor.fetchone()["seq"]) + 1
            approval_id = f"pa_{cosmetic_id}_{seq}"
            requested_qty = target_qty - current_qty

            # 8. 품의 등록
            cursor.execute(
                """
                INSERT INTO approvals (
                    approval_id,
                    cosmetic_id,
                    approval_seq,
                    target_stock_snapshot,
                    current_stock_snapshot,
                    requested_quantity,
                    approval_content,
                    requested_on
                )
                VALUES (
                    %s, %s, %s, %s, %s, %s,
                    %s, CURDATE()
                )
                """,
                (
                    approval_id,
                    cosmetic_id,
                    seq,
                    target_qty,
                    current_qty,
                    requested_qty,
                    "자동 재고 보충 품의"
                )
            )

            # 9. 품의 상태 이력
            history_id = _allocate_id(
                cursor,
                "history:approval_status_history",
                "approval_status_history",
                "status_history_id",
                "ash_"
            )

            cursor.execute(
                """
                INSERT INTO approval_status_history (
                    status_history_id,
                    approval_id,
                    approval_status,
                    changed_at
                )
                VALUES (%s, %s, 'REQUESTED', NOW())
                """,
                (history_id, approval_id)
            )

            # 10. 기존 결재 API와 호환되는 대기 건 생성
            decision_id = _allocate_id(
                cursor,
                "history:approval_decisions",
                "approval_decisions",
                "decision_id",
                "dec_"
            )

            cursor.execute(
                """
                INSERT INTO approval_decisions (
                    decision_id,
                    employee_id,
                    approval_id,
                    decision_status,
                    decided_at
                )
                VALUES (%s, %s, %s, 'PENDING', NULL)
                """,
                (
                    decision_id,
                    admin["employee_id"],
                    approval_id
                )
            )

        conn.commit()

        return {
            "cosmetic_id": cosmetic_id,
            "result": "CREATED",
            "approval_id": approval_id,
            "minimum_quantity": minimum_qty,
            "target_quantity": target_qty,
            "current_quantity": current_qty,
            "requested_quantity": requested_qty,
            "approver_employee_id": admin["employee_id"]
        }

    except Exception:
        conn.rollback()
        raise

    finally:
        conn.close()


def create_automatic_approvals() -> dict:
    """
    기존 품의에 등장한 화장품만 대상으로
    재고 부족 여부를 확인하고 새 품의를 생성한다.

    내부 자동화 프로그램은 이 함수를 직접 호출할 수 있다.
    """
    try:
        conn = get_connection()
        try:
            with conn.cursor() as cursor:
                cursor.execute(
                    """
                    SELECT DISTINCT cosmetic_id
                    FROM approvals
                    ORDER BY cosmetic_id
                    """
                )
                cosmetic_ids = [
                    row["cosmetic_id"]
                    for row in cursor.fetchall()
                ]
        finally:
            conn.close()
    except pymysql.MySQLError:
        logger.exception("자동 품의 대상 조회 실패")
        raise HTTPException(
            status_code=503,
            detail="자동 품의 대상을 조회할 수 없습니다."
        )

    results = []

    for cosmetic_id in cosmetic_ids:
        try:
            results.append(
                _process_cosmetic(cosmetic_id)
            )
        except pymysql.MySQLError:
            logger.exception(
                "자동 품의 생성 실패: %s",
                cosmetic_id
            )
            results.append({
                "cosmetic_id": cosmetic_id,
                "result": "ERROR",
                "detail": "DB 처리 실패"
            })
        except Exception:
            logger.exception(
                "자동 품의 처리 오류: %s",
                cosmetic_id
            )
            results.append({
                "cosmetic_id": cosmetic_id,
                "result": "ERROR",
                "detail": "서버 처리 실패"
            })

    created = [
        item for item in results
        if item["result"] == "CREATED"
    ]

    return {
        "checked_count": len(cosmetic_ids),
        "created_count": len(created),
        "error_count": sum(
            item["result"] == "ERROR"
            for item in results
        ),
        "results": results
    }
