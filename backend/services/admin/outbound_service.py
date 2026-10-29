
from fastapi import HTTPException

from database import get_connection
from schemas.admin.outbound_schema import OutboundCreateRequest


def create_outbound(data: OutboundCreateRequest):
    conn = get_connection()

    try:
        conn.begin()

        with conn.cursor() as cursor:
            # 1. 주문 조회 및 잠금
            cursor.execute(
                """
                SELECT order_id, order_status
                FROM orders
                WHERE order_id = %s
                FOR UPDATE
                """,
                (data.order_id,),
            )
            order = cursor.fetchone()

            if order is None:
                raise HTTPException(
                    status_code=404,
                    detail="존재하지 않는 주문입니다.",
                )

            if order["order_status"] != "PREPARING":
                raise HTTPException(
                    status_code=409,
                    detail="상품 준비 중인 주문만 출고할 수 있습니다.",
                )

            # 2. 배송업체 존재 여부 확인
            cursor.execute(
                """
                SELECT carrier_id
                FROM carriers
                WHERE carrier_id = %s
                """,
                (data.carrier_id,),
            )

            if cursor.fetchone() is None:
                raise HTTPException(
                    status_code=404,
                    detail="존재하지 않는 배송업체입니다.",
                )

            # 3. 기존 배송 정보 확인
            cursor.execute(
                """
                SELECT delivery_id
                FROM delivery_information
                WHERE order_id = %s
                LIMIT 1
                """,
                (data.order_id,),
            )

            if cursor.fetchone() is not None:
                raise HTTPException(
                    status_code=409,
                    detail="이미 배송 정보가 등록된 주문입니다.",
                )

            # 4. 주문 상품과 기존 출고 기록 조회
            cursor.execute(
                """
                SELECT
                    oi.order_item_id,
                    oi.inventory_id,
                    oi.purchase_quantity,
                    so.outbound_quantity,
                    so.inventory_id AS outbound_inventory_id,
                    so.delivery_id,
                    so.outbound_on
                FROM order_items AS oi
                LEFT JOIN stock_outbounds AS so
                    ON oi.order_item_id = so.order_item_id
                WHERE oi.order_id = %s
                FOR UPDATE
                """,
                (data.order_id,),
            )

            outbound_rows = cursor.fetchall()

            if not outbound_rows:
                raise HTTPException(
                    status_code=409,
                    detail="출고할 주문 상품이 없습니다.",
                )

            # 5. 기존 출고 기록 검증
            for row in outbound_rows:
                if row["outbound_quantity"] is not None:
                    if (
                        row["outbound_quantity"]
                        != row["purchase_quantity"]
                    ):
                        raise HTTPException(
                            status_code=409,
                            detail="주문 수량과 출고 수량이 일치하지 않습니다.",
                        )

                    if (
                        row["outbound_inventory_id"]
                        != row["inventory_id"]
                    ):
                        raise HTTPException(
                            status_code=409,
                            detail="주문 상품과 출고 재고가 일치하지 않습니다.",
                        )

                    if (
                        row["delivery_id"] is not None
                        or row["outbound_on"] is not None
                    ):
                        raise HTTPException(
                            status_code=409,
                            detail="이미 출고 처리된 상품이 있습니다.",
                        )

            # 6. 배송 번호 생성
            delivery_seq = 1
            delivery_id = f"dlv_{data.order_id}_{delivery_seq}"

            # 7. 배송 정보 생성
            cursor.execute(
                """
                INSERT INTO delivery_information (
                    delivery_id,
                    order_id,
                    delivery_seq,
                    carrier_id,
                    delivery_status
                )
                VALUES (%s, %s, %s, %s, 'READY')
                """,
                (
                    delivery_id,
                    data.order_id,
                    delivery_seq,
                    data.carrier_id,
                ),
            )

            # 8. 출고 기록 생성 또는 갱신
            for row in outbound_rows:
                if row["outbound_quantity"] is None:
                    # 예약 기록이 없는 주문 상품
                    cursor.execute(
                        """
                        INSERT INTO stock_outbounds (
                            order_item_id,
                            inventory_id,
                            delivery_id,
                            outbound_quantity,
                            outbound_on
                        )
                        VALUES (%s, %s, %s, %s, CURDATE())
                        """,
                        (
                            row["order_item_id"],
                            row["inventory_id"],
                            delivery_id,
                            row["purchase_quantity"],
                        ),
                    )
                else:
                    # 기존 예약 기록을 출고 완료 기록으로 변경
                    cursor.execute(
                        """
                        UPDATE stock_outbounds
                        SET
                            delivery_id = %s,
                            outbound_on = CURDATE()
                        WHERE order_item_id = %s
                          AND delivery_id IS NULL
                          AND outbound_on IS NULL
                        """,
                        (
                            delivery_id,
                            row["order_item_id"],
                        ),
                    )

                if cursor.rowcount != 1:
                    raise HTTPException(
                        status_code=409,
                        detail="출고 기록 저장에 실패했습니다.",
                    )

            # 9. 주문 상태 변경
            cursor.execute(
                """
                UPDATE orders
                SET order_status = 'SHIPPED'
                WHERE order_id = %s
                  AND order_status = 'PREPARING'
                """,
                (data.order_id,),
            )

            if cursor.rowcount != 1:
                raise HTTPException(
                    status_code=409,
                    detail="주문 상태가 변경되어 출고할 수 없습니다.",
                )

        # 10. 모든 작업이 성공한 경우에만 저장
        conn.commit()

        return {
            "delivery_id": delivery_id,
            "order_id": data.order_id,
            "delivery_seq": delivery_seq,
            "carrier_id": data.carrier_id,
            "order_status": "SHIPPED",
            "delivery_status": "READY",
            "message": "출고 처리가 완료되었습니다.",
        }

    except Exception:
        conn.rollback()
        raise

    finally:
        conn.close()
