
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
            carrier = cursor.fetchone()

            if carrier is None:
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
            existing_delivery = cursor.fetchone()

            if existing_delivery is not None:
                raise HTTPException(
                    status_code=409,
                    detail="이미 배송 정보가 등록된 주문입니다.",
                )
            # 출고 기록 확인
            cursor.execute(
                """
                SELECT
                    oi.order_item_id,
                    oi.purchase_quantity,
                    so.outbound_quantity,
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

            for row in outbound_rows:
                if row["outbound_quantity"] is None:
                    raise HTTPException(
                        status_code=409,
                        detail="출고 예약 기록이 없는 상품이 있습니다.",
                    )

                if row["outbound_quantity"] != row["purchase_quantity"]:
                    raise HTTPException(
                        status_code=409,
                        detail="주문 수량과 출고 예약 수량이 일치하지 않습니다.",
                    )

                if (
                    row["delivery_id"] is not None
                    or row["outbound_on"] is not None
                ):
                    raise HTTPException(
                        status_code=409,
                        detail="이미 출고 처리된 상품이 있습니다.",
                    )

            # 4. 배송 번호 생성
            delivery_seq = 1
            delivery_id = f"dlv_{data.order_id}_{delivery_seq}"

            # 5. 배송 정보 생성
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

            # 출고 예약 기록에 배송 번호와 출고일 연결
            cursor.execute(
                """
                UPDATE stock_outbounds AS so
                INNER JOIN order_items AS oi
                    ON so.order_item_id = oi.order_item_id
                SET
                    so.delivery_id = %s,
                    so.outbound_on = CURDATE()
                WHERE oi.order_id = %s
                AND so.delivery_id IS NULL
                AND so.outbound_on IS NULL
                """,
                (delivery_id, data.order_id),
            )

            if cursor.rowcount != len(outbound_rows):
                raise HTTPException(
                    status_code=409,
                    detail="출고 예약 기록 연결에 실패했습니다.",
                )

            # 6. 주문 상태 변경
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

        # 7. 배송 정보 생성과 주문 상태 변경을 함께 저장
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
