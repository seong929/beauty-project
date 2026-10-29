from database import get_connection
from fastapi import HTTPException
from schemas.delivery.delivery_schema import DeliveryStatusUpdateRequest


# 배송 목록 조회
def get_delivery_list(carrier_id: str):
    conn = get_connection()

    try:
        with conn.cursor() as cursor:
            sql = """
                SELECT
                    d.delivery_id,
                    d.order_id,
                    d.delivery_seq,
                    c.carrier_name,
                    o.shipping_address,
                    o.ordered_at,
                    d.delivery_status,
                    d.shipped_at,
                    d.arrived_at
                FROM delivery_information AS d

                JOIN carriers AS c
                    ON d.carrier_id = c.carrier_id

                JOIN orders AS o
                    ON d.order_id = o.order_id

                WHERE d.carrier_id = %s

                ORDER BY
                    o.ordered_at DESC,
                    d.delivery_seq DESC
            """

            cursor.execute(sql, (carrier_id,))
            result = cursor.fetchall()

        return result

    finally:
        conn.close()

# 본사 관리자 전체 배송 목록 조회
def get_admin_delivery_list():
    conn = get_connection()

    try:
        with conn.cursor() as cursor:
            sql = """
                SELECT
                    d.delivery_id,
                    d.order_id,
                    d.delivery_seq,
                    c.carrier_name,
                    o.shipping_address,
                    o.ordered_at,
                    d.delivery_status,
                    d.shipped_at,
                    d.arrived_at
                FROM delivery_information AS d

                JOIN carriers AS c
                    ON d.carrier_id = c.carrier_id

                JOIN orders AS o
                    ON d.order_id = o.order_id

                ORDER BY
                    o.ordered_at DESC,
                    d.delivery_seq DESC
            """

            cursor.execute(sql)
            result = cursor.fetchall()

        return result

    finally:
        conn.close()

# 배송 상태 변경
def update_delivery_status(
    delivery_id: str,
    data: DeliveryStatusUpdateRequest,
    carrier_id: str
):
    conn = get_connection()

    try:
        conn.begin()

        with conn.cursor() as cursor:
            # 1. 배송 정보 조회 및 잠금
            cursor.execute(
                """
                SELECT order_id, delivery_status
                FROM delivery_information
                WHERE delivery_id = %s
                AND carrier_id = %s
                FOR UPDATE
                """,
                (delivery_id, carrier_id),
            )

            delivery = cursor.fetchone()

            if delivery is None:
                raise HTTPException(
                    status_code=404,
                    detail="존재하지 않는 배송 정보입니다.",
                )

            current_status = delivery["delivery_status"]
            new_status = data.delivery_status
            order_id = delivery["order_id"]

            # 2. 허용되는 배송 상태 변경 규칙
            allowed_transitions = {
                "READY": {"IN_TRANSIT"},
                "IN_TRANSIT": {
                    "DELIVERED",
                    "FAILED",
                    "RETURNING",
                },
                "FAILED": {"RETURNING"},
                "DELIVERED": set(),
                "RETURNING": set(),
            }

            if new_status not in allowed_transitions.get(
                current_status, set()
            ):
                raise HTTPException(
                    status_code=409,
                    detail=(
                        f"배송 상태를 {current_status}에서 "
                        f"{new_status}(으)로 변경할 수 없습니다."
                    ),
                )

            # 3. 배송 상태 및 일시 변경
            if new_status == "IN_TRANSIT":
                cursor.execute(
                    """
                    UPDATE delivery_information
                    SET delivery_status = %s,
                        shipped_at = NOW()
                    WHERE delivery_id = %s
                    AND carrier_id = %s
                    """,
                    (new_status, delivery_id, carrier_id),
                )

            elif new_status == "DELIVERED":
                cursor.execute(
                    """
                    UPDATE delivery_information
                    SET delivery_status = %s,
                        arrived_at = NOW()
                    WHERE delivery_id = %s
                    AND carrier_id = %s
                    """,
                    (new_status, delivery_id, carrier_id),
                )

            else:
                cursor.execute(
                    """
                    UPDATE delivery_information
                    SET delivery_status = %s
                    WHERE delivery_id = %s
                    AND carrier_id = %s
                    """,
                    (new_status, delivery_id, carrier_id),
                )

            if cursor.rowcount != 1:
                raise HTTPException(
                    status_code=409,
                    detail="배송 상태 변경에 실패했습니다.",
                )

            # 4. 배송 완료 시 주문 상태도 변경
            if new_status == "DELIVERED":
                cursor.execute(
                    """
                    SELECT COUNT(*) AS remaining_count
                    FROM delivery_information
                    WHERE order_id = %s
                    AND delivery_status <> 'DELIVERED'
                    """,
                    (order_id,),
                )
                remaining_count = cursor.fetchone()["remaining_count"]

                if remaining_count == 0:
                    cursor.execute(
                        """
                        UPDATE orders
                        SET order_status = 'DELIVERED'
                        WHERE order_id = %s
                            AND order_status = 'SHIPPED'
                        """,
                    (order_id,),
                    )

                    if cursor.rowcount != 1:
                        raise HTTPException(
                            status_code=409,
                            detail="주문 상태를 배송 완료로 변경할 수 없습니다.",
                        )

        # 5. 배송 상태와 주문 상태를 함께 저장
        conn.commit()

        return {
            "delivery_id": delivery_id,
            "previous_status": current_status,
            "delivery_status": new_status,
            "message": "배송 상태가 변경되었습니다.",
        }

    except Exception:
        conn.rollback()
        raise

    finally:
        conn.close()