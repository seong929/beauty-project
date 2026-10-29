
import logging
from datetime import datetime, timezone, timedelta

import pymysql
from fastapi import HTTPException

from database import get_connection

logger = logging.getLogger(__name__)
KST = timezone(timedelta(hours=9), name="KST")


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


def _find_pipeline_blocker(cursor, cosmetic_id: str,
                           current_qty: int, target_qty: int) -> dict | None:
    """진행 중인 발주와 아직 발주되지 않은 품의를 독립적으로 확인한다.

    자동 품의는 기존 approvals.requested_quantity CHECK 제약을 유지한다.
    따라서 미입고 예정량을 요청량에서 빼서 새 품의를 만들지 않고,
    진행 중인 공급 절차가 있다면 신규 자동 품의를 보류한다.
    """
    # (A) 활성 발주는 품의가 APPROVED인지와 무관하게 확인해야 한다.
    # 각 발주별 입고 누적량을 조회하여 PARTIALLY_RECEIVED도 다룬다.
    cursor.execute(
        """
        SELECT po.purchase_order_id, po.approval_id,
               po.purchase_status, po.order_quantity,
               COALESCE((
                   SELECT SUM(ih.inbound_quantity)
                   FROM inbound_history AS ih
                   WHERE ih.purchase_order_id = po.purchase_order_id
               ), 0) AS received_quantity
        FROM purchase_orders AS po
        JOIN approvals AS a ON a.approval_id = po.approval_id
        WHERE a.cosmetic_id = %s
          AND po.purchase_status IN (
              'REQUESTED', 'ORDERED', 'PARTIALLY_RECEIVED'
          )
        ORDER BY po.ordered_on DESC, po.purchase_order_id DESC
        """,
        (cosmetic_id,),
    )
    active_orders = cursor.fetchall()
    if active_orders:
        order_details = []
        pending_quantity = 0
        inconsistent = False
        for order in active_orders:
            ordered = int(order["order_quantity"])
            received = int(order["received_quantity"])
            remaining = ordered - received
            # 입고량이 발주량 이상인데 상태가 진행 중이면 정합성 이상:
            # 조용히 다음 품의를 만들지 않고 관리자가 검수하도록 보류한다.
            if remaining <= 0:
                inconsistent = True
            pending_quantity += max(0, remaining)
            order_details.append({
                "purchase_order_id": order["purchase_order_id"],
                "approval_id": order["approval_id"],
                "purchase_status": order["purchase_status"],
                "ordered_quantity": ordered,
                "received_quantity": received,
                "remaining_quantity": max(0, remaining),
            })
        return {
            "cosmetic_id": cosmetic_id,
            "result": ("INCONSISTENT_PURCHASE_ORDER" if inconsistent
                       else "OPEN_PURCHASE_ORDER_EXISTS"),
            "current_quantity": current_qty,
            "target_quantity": target_qty,
            "incoming_quantity": pending_quantity,
            "projected_quantity": current_qty + pending_quantity,
            "projected_shortfall": max(0, target_qty - current_qty - pending_quantity),
            "purchase_orders": order_details,
        }

    # (B) 발주가 아직 등록되지 않은 결재 대기/승인 품의.
    # 취소/완료된 발주가 연결된 승인 품의는 재신청 방해 요인이 아니다.
    # 신규 발주는 현재 1품의 1발주이며, 취소 발주에 재발주는 불가하므로
    # 재고가 부족하면 별도의 신규 품의를 허용한다.
    cursor.execute(
        """
        SELECT pending.approval_id, pending.requested_quantity,
               pending.approval_status
        FROM (
            SELECT a.approval_id, a.requested_quantity, a.requested_on,
                   (
                       SELECT h.approval_status
                       FROM approval_status_history AS h
                       WHERE h.approval_id = a.approval_id
                       ORDER BY h.changed_at DESC,
                                CAST(SUBSTRING(h.status_history_id, 5)
                                     AS UNSIGNED) DESC
                       LIMIT 1
                   ) AS approval_status
            FROM approvals AS a
            WHERE a.cosmetic_id = %s
              AND NOT EXISTS (
                  SELECT 1 FROM purchase_orders AS po
                  WHERE po.approval_id = a.approval_id
              )
        ) AS pending
        WHERE pending.approval_status IN ('REQUESTED', 'APPROVED')
        ORDER BY pending.requested_on DESC, pending.approval_id DESC
        """,
        (cosmetic_id,),
    )
    pending_approvals = cursor.fetchall()
    if pending_approvals:
        return {
            "cosmetic_id": cosmetic_id,
            "result": "OPEN_APPROVAL_EXISTS",
            "current_quantity": current_qty,
            "target_quantity": target_qty,
            "approval_id": pending_approvals[0]["approval_id"],
            "pending_approvals": [
                {
                    "approval_id": a["approval_id"],
                    "approval_status": a["approval_status"],
                    "requested_quantity": int(a["requested_quantity"]),
                }
                for a in pending_approvals
            ],
        }
    return None


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

            # 5. 발주와 품의를 분리해서 검토한다.
            # 승인 상태 이력이 변경되더라도 실제 발주가 남아 있으면
            # 신규 품의가 중복 생성되지 않아야 한다.
            pipeline_blocker = _find_pipeline_blocker(
                cursor, cosmetic_id, current_qty, target_qty
            )
            if pipeline_blocker is not None:
                return pipeline_blocker

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
                    %s, %s
                )
                """,
                (
                    approval_id,
                    cosmetic_id,
                    seq,
                    target_qty,
                    current_qty,
                    requested_qty,
                    "자동 재고 보충 품의",
                    datetime.now(KST).date()
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
