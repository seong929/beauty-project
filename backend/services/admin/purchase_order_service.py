
from decimal import Decimal
from fastapi import HTTPException
from database import get_connection
from schemas.admin.purchase_order_schema import PurchaseOrderCreateRequest


def create_purchase_order(data: PurchaseOrderCreateRequest):
    conn = get_connection()

    try:
        with conn.cursor() as cursor:
            # 1. 품의 및 화장품 정보 조회
            cursor.execute(
                """
                SELECT
                    a.approval_id,
                    a.requested_quantity,
                    c.manufacturer_id
                FROM approvals AS a
                JOIN cosmetics AS c
                    ON a.cosmetic_id = c.cosmetic_id
                WHERE a.approval_id = %s
                FOR UPDATE
                """,
                (data.approval_id,),
            )

            approval = cursor.fetchone()

            if approval is None:
                raise HTTPException(
                    status_code=404,
                    detail="존재하지 않는 품의입니다.",
                )

            # 2. 최신 품의 상태 확인
            cursor.execute(
                """
                SELECT approval_status
                FROM approval_status_history
                WHERE approval_id = %s
                ORDER BY changed_at DESC,
                         CAST(
                             SUBSTRING(status_history_id, 5)
                             AS UNSIGNED
                         ) DESC
                LIMIT 1
                """,
                (data.approval_id,),
            )

            status_row = cursor.fetchone()

            if (
                status_row is None
                or status_row["approval_status"] != "APPROVED"
            ):
                raise HTTPException(
                    status_code=409,
                    detail="승인된 품의만 발주할 수 있습니다.",
                )

            # 3. 제조사 검증
            if approval["manufacturer_id"] != data.manufacturer_id:
                raise HTTPException(
                    status_code=400,
                    detail="해당 화장품의 제조사가 아닙니다.",
                )

            # 4. 동일 품의 중복 발주 확인
            cursor.execute(
                """
                SELECT purchase_order_id
                FROM purchase_orders
                WHERE approval_id = %s
                LIMIT 1
                """,
                (data.approval_id,),
            )

            existing_order = cursor.fetchone()

            if existing_order is not None:
                raise HTTPException(
                    status_code=409,
                    detail="이미 발주가 등록된 품의입니다.",
                )

            # 5. 발주번호 생성
            # 품의 1건당 발주 1건이므로 순번은 1로 고정
            purchase_order_seq = 1

            purchase_order_id = (
                f"{data.approval_id}_{purchase_order_seq}"
            )

            # 6. 발주 수량 및 금액 계산
            order_quantity = approval["requested_quantity"]

            unit_supply_price = data.unit_supply_price.quantize(
                Decimal("0.01")
            )

            order_total_amount = (
                Decimal(order_quantity) * unit_supply_price
            )


            # 7. 실제 발주 데이터 저장
            cursor.execute(
                """
                INSERT INTO purchase_orders (
                    purchase_order_id,
                    approval_id,
                    purchase_order_seq,
                    manufacturer_id,
                    ordered_on,
                    order_quantity,
                    purchase_status,
                    unit_supply_price,
                    order_total_amount
                )
                VALUES (
                    %s, %s, %s, %s, CURDATE(),
                    %s, 'ORDERED', %s, %s
                )
                """,
                (
                    purchase_order_id,
                    data.approval_id,
                    purchase_order_seq,
                    data.manufacturer_id,
                    order_quantity,
                    unit_supply_price,
                    order_total_amount,
                ),
            )


        conn.commit()

        return {
            "purchase_order_id": purchase_order_id,
            "approval_id": data.approval_id,
            "purchase_order_seq": purchase_order_seq,
            "manufacturer_id": data.manufacturer_id,
            "order_quantity": order_quantity,
            "unit_supply_price": unit_supply_price,
            "order_total_amount": order_total_amount,
            "purchase_status": "ORDERED",
            "message": "발주 등록이 완료되었습니다.",
        }

    except Exception:
        conn.rollback()
        raise

    finally:
        conn.close()


def get_purchase_order_list():
    conn = get_connection()

    try:
        with conn.cursor() as cursor:
            cursor.execute(
                """
                SELECT
                    po.purchase_order_id,
                    po.approval_id,
                    po.purchase_order_seq,
                    po.manufacturer_id,
                    m.manufacturer_name,
                    a.cosmetic_id,
                    c.cosmetic_name,
                    po.ordered_on,
                    po.order_quantity,
                    po.purchase_status,
                    po.unit_supply_price,
                    po.order_total_amount
                FROM purchase_orders AS po
                JOIN approvals AS a
                    ON po.approval_id = a.approval_id
                JOIN cosmetics AS c
                    ON a.cosmetic_id = c.cosmetic_id
                JOIN manufacturers AS m
                    ON po.manufacturer_id = m.manufacturer_id
                ORDER BY po.ordered_on DESC,
                         po.purchase_order_id DESC
                """
            )

            return cursor.fetchall()

    finally:
        conn.close()
