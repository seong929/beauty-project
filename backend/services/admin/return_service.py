from fastapi import HTTPException
from database import get_connection
from schemas.admin.return_schema import (ReturnDecisionRequest, ReturnPickupStatusRequest, ReturnInspectionRequest)


# 반품 승인 및 반려
def decide_return(
    return_id: str,
    data: ReturnDecisionRequest,
):
    conn = get_connection()

    try:
        with conn.cursor() as cursor:
            # 1. 본사 직원 및 관리자 권한 확인
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
            if employee["employee_role"] not in ("ADMIN", "STAFF"):
                raise HTTPException(
                    status_code=403,
                    detail="본사 직원 또는 관리자만 반품을 처리할 수 있습니다.",
                )
            
            # 2. 반품 요청 조회 및 잠금
            cursor.execute(
                """
                SELECT return_status
                FROM return_requests
                WHERE return_id = %s
                FOR UPDATE
                """,
                (return_id,),
            )
            return_request = cursor.fetchone()
            if return_request is None:
                raise HTTPException(
                    status_code=404,
                    detail="존재하지 않는 반품 요청입니다.",
                )

            # 3. 처리 가능한 상태 확인
            if return_request["return_status"] != "REQUESTED":
                raise HTTPException(
                    status_code=409,
                    detail="이미 처리되었거나 승인·반려할 수 없는 반품입니다.",
                )

            # 4. 반품 승인 또는 반려
            cursor.execute(
                """
                UPDATE return_requests
                SET return_status = %s
                WHERE return_id = %s
                  AND return_status = 'REQUESTED'
                """,
                (
                    data.return_status,
                    return_id,
                ),
            )
            if cursor.rowcount != 1:
                raise HTTPException(
                    status_code=409,
                    detail="반품 상태 변경에 실패했습니다.",
                )
        conn.commit()
        return {
            "return_id": return_id,
            "previous_status": "REQUESTED",
            "return_status": data.return_status,
            "message": "반품 승인·반려 처리가 완료되었습니다.",
        }

    except Exception:
        conn.rollback()
        raise

    finally:
        conn.close()


# 반품 요청 목록 조회
def get_return_list():
    conn = get_connection()

    try:
        with conn.cursor() as cursor:
            cursor.execute(
                """
                SELECT
                    rr.return_id,
                    rr.order_item_id,
                    o.order_id,
                    o.customer_id,
                    rr.return_seq,
                    rr.requested_on,
                    rr.return_reason,
                    rr.return_quantity,
                    rr.return_status,
                    rr.refund_status,
                    rr.pickup_status,
                    rr.pickup_requested_on,
                    rr.pickup_completed_on,
                    rr.headquarters_received_on,
                    rr.inspection_result
                FROM return_requests AS rr
                JOIN order_items AS oi
                    ON rr.order_item_id = oi.order_item_id
                JOIN orders AS o
                    ON oi.order_id = o.order_id
                ORDER BY rr.requested_on DESC,
                    rr.return_id DESC
                """
            )
            return cursor.fetchall()
    finally:
        conn.close()


# 기존 배송업체를 반품 회수업체로 자동 지정
def assign_return_pickup(return_id: str, employee_id: str):
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
                (employee_id,),
            )
            employee = cursor.fetchone()
            if employee is None:
                raise HTTPException(
                    status_code=404,
                    detail="존재하지 않는 직원입니다.",
                )
            if employee["employee_role"] not in ("ADMIN", "STAFF"):
                raise HTTPException(
                    status_code=403,
                    detail="본사 직원 또는 관리자만 반품 회수를 요청할 수 있습니다.",
                )

            # 2. 반품 요청 조회 및 잠금
            cursor.execute(
                """
                SELECT
                    rr.return_status,
                    rr.pickup_status,
                    oi.order_id
                FROM return_requests AS rr
                JOIN order_items AS oi
                    ON rr.order_item_id = oi.order_item_id
                WHERE rr.return_id = %s
                FOR UPDATE
                """,
                (return_id,),
            )
            return_request = cursor.fetchone()
            if return_request is None:
                raise HTTPException(
                    status_code=404,
                    detail="존재하지 않는 반품 요청입니다.",
                )
            if (
                return_request["return_status"] != "APPROVED"
                or return_request["pickup_status"] != "WAITING"
            ):
                raise HTTPException(
                    status_code=409,
                    detail="승인된 회수 대기 반품만 처리할 수 있습니다.",
                )

            # 3. 해당 주문의 배송 완료 기록 조회
            cursor.execute(
                """
                SELECT DISTINCT carrier_id
                FROM delivery_information
                WHERE order_id = %s
                AND delivery_status = 'DELIVERED'
                """,
                (return_request["order_id"],),
            )
            carriers = cursor.fetchall()
            if not carriers:
                raise HTTPException(
                    status_code=409,
                    detail="배송 완료 기록이 없어 회수업체를 확인할 수 없습니다.",
                )
            if len(carriers) != 1:
                raise HTTPException(
                    status_code=409,
                    detail="배송업체가 여러 곳이므로 자동 지정할 수 없습니다.",
                )
            carrier_id = carriers[0]["carrier_id"]

            # 4. 회수업체 중복 지정 확인
            cursor.execute(
                """
                SELECT carrier_id
                FROM return_pickups
                WHERE return_id = %s
                """,
                (return_id,),
            )
            if cursor.fetchone() is not None:
                raise HTTPException(
                    status_code=409,
                    detail="이미 회수업체가 지정된 반품입니다.",
                )

            # 5. 기존 배송업체를 회수업체로 등록
            cursor.execute(
                """
                INSERT INTO return_pickups (
                    return_id,
                    carrier_id
                )
                VALUES (%s, %s)
                """,
                (return_id, carrier_id),
            )

            # 6. 반품 및 회수 상태 변경
            cursor.execute(
                """
                UPDATE return_requests
                SET return_status = 'COLLECTING',
                    pickup_status = 'SCHEDULED',
                    pickup_requested_on = CURDATE()
                WHERE return_id = %s
                """,
                (return_id,),
            )

        conn.commit()

        return {
            "return_id": return_id,
            "carrier_id": carrier_id,
            "return_status": "COLLECTING",
            "pickup_status": "SCHEDULED",
            "message": "기존 배송업체에 반품 회수를 요청했습니다.",
        }

    except Exception:
        conn.rollback()
        raise

    finally:
        conn.close()


# 반품 회수 상태 변경
def update_return_pickup_status(
    return_id: str,
    data: ReturnPickupStatusRequest,
):
    conn = get_connection()

    try:
        with conn.cursor() as cursor:
            # 1. 직원 권한 확인
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

            if employee["employee_role"] not in ("ADMIN", "STAFF"):
                raise HTTPException(
                    status_code=403,
                    detail="본사 직원과 관리자만 회수 상태를 변경할 수 있습니다.",
                )

            # 2. 반품 요청 조회 및 잠금
            cursor.execute(
                """
                SELECT return_status, pickup_status
                FROM return_requests
                WHERE return_id = %s
                FOR UPDATE
                """,
                (return_id,),
            )

            return_request = cursor.fetchone()

            if return_request is None:
                raise HTTPException(
                    status_code=404,
                    detail="존재하지 않는 반품 요청입니다.",
                )

            # 3. 상태 변경 조건 확인
            if return_request["return_status"] != "COLLECTING":
                raise HTTPException(
                    status_code=409,
                    detail="회수 진행 중인 반품만 상태를 변경할 수 있습니다.",
                )

            if return_request["pickup_status"] != "SCHEDULED":
                raise HTTPException(
                    status_code=409,
                    detail="회수 예정 상태에서만 변경할 수 있습니다.",
                )

            if data.pickup_status not in ("COLLECTED", "FAILED"):
                raise HTTPException(
                    status_code=422,
                    detail="회수 완료 또는 실패 상태만 지정할 수 있습니다.",
                )

            # 4. 회수 상태 변경
            if data.pickup_status == "COLLECTED":
                cursor.execute(
                    """
                    UPDATE return_requests
                    SET pickup_status = 'COLLECTED',
                        pickup_completed_on = CURDATE()
                    WHERE return_id = %s
                    """,
                    (return_id,),
                )
            else:
                cursor.execute(
                    """
                    UPDATE return_requests
                    SET pickup_status = 'FAILED'
                    WHERE return_id = %s
                    """,
                    (return_id,),
                )

            if cursor.rowcount != 1:
                raise HTTPException(
                    status_code=409,
                    detail="회수 상태 변경에 실패했습니다.",
                )

        conn.commit()

        return {
            "return_id": return_id,
            "return_status": "COLLECTING",
            "pickup_status": data.pickup_status,
            "message": "반품 회수 상태가 변경되었습니다.",
        }

    except Exception:
        conn.rollback()
        raise

    finally:
        conn.close()


# 본사 반품 상품 수령 처리
def receive_return(return_id: str, employee_id: str):
    conn = get_connection()
    cursor = conn.cursor()

    try:
        # 1. 본사 관리자 권한 확인
        cursor.execute(
            """
            SELECT employee_role
            FROM employees
            WHERE employee_id = %s
            """,
            (employee_id,),
        )
        employee = cursor.fetchone()

        if employee is None:
            raise HTTPException(
                status_code=404,
                detail="직원 정보를 찾을 수 없습니다.",
            )

        if employee["employee_role"] not in ("ADMIN", "STAFF"):
            raise HTTPException(
                status_code=403,
                detail="본사 직원과 본사 관리자만 반품 상품을 수령 처리할 수 있습니다.",
            )

        # 2. 반품 요청 조회 및 잠금
        cursor.execute(
            """
            SELECT return_status, pickup_status
            FROM return_requests
            WHERE return_id = %s
            FOR UPDATE
            """,
            (return_id,),
        )
        return_request = cursor.fetchone()

        if return_request is None:
            raise HTTPException(
                status_code=404,
                detail="반품 요청을 찾을 수 없습니다.",
            )

        # 3. 회수 완료 여부 확인
        if (
            return_request["return_status"] != "COLLECTING"
            or return_request["pickup_status"] != "COLLECTED"
        ):
            raise HTTPException(
                status_code=400,
                detail="회수가 완료된 반품만 본사 수령 처리할 수 있습니다.",
            )

        # 4. 본사 수령일 및 상태 변경
        cursor.execute(
            """
            UPDATE return_requests
            SET return_status = 'INSPECTING',
                headquarters_received_on = CURDATE()
            WHERE return_id = %s
            """,
            (return_id,),
        )

        conn.commit()

        return {
            "message": "반품 상품 본사 수령 처리가 완료되었습니다.",
            "return_id": return_id,
            "return_status": "INSPECTING",
        }

    except Exception:
        conn.rollback()
        raise

    finally:
        cursor.close()
        conn.close()


# 반품 상품 검수 완료 처리
def complete_return_inspection(
    return_id: str,
    data: ReturnInspectionRequest,
):
    conn = get_connection()
    cursor = conn.cursor()

    try:
        # 1. 본사 관리자 권한 확인
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
                detail="직원 정보를 찾을 수 없습니다.",
            )

        if employee["employee_role"] not in ("ADMIN", "STAFF"):
            raise HTTPException(
                status_code=403,
                detail="본사 직원과 본사 관리자만 반품 검수를 완료할 수 있습니다.",
            )

        # 2. 반품 요청 조회 및 잠금
        cursor.execute(
            """
            SELECT
                return_status,
                pickup_status,
                headquarters_received_on
            FROM return_requests
            WHERE return_id = %s
            FOR UPDATE
            """,
            (return_id,),
        )
        return_request = cursor.fetchone()

        if return_request is None:
            raise HTTPException(
                status_code=404,
                detail="반품 요청을 찾을 수 없습니다.",
            )

        # 3. 본사 수령 및 검수 가능 상태 확인
        if (
            return_request["return_status"] != "INSPECTING"
            or return_request["pickup_status"] != "COLLECTED"
            or return_request["headquarters_received_on"] is None
        ):
            raise HTTPException(
                status_code=400,
                detail="본사 수령 처리가 완료된 반품만 검수 완료할 수 있습니다.",
            )

        # 4. 검수 결과 저장 및 반품 완료 처리
        cursor.execute(
            """
            UPDATE return_requests
            SET inspection_result = %s,
                return_status = 'COMPLETED'
            WHERE return_id = %s
            """,
            (
                data.inspection_result,
                return_id,
            ),
        )

        conn.commit()

        return {
            "message": "반품 검수 및 반품 완료 처리가 완료되었습니다.",
            "return_id": return_id,
            "return_status": "COMPLETED",
            "inspection_result": data.inspection_result,
        }

    except Exception:
        conn.rollback()
        raise

    finally:
        cursor.close()
        conn.close()
