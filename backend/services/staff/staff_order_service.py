
import logging
import pymysql

from fastapi import HTTPException
from database import get_connection

logger = logging.getLogger(__name__)


# 현재 진행 중인 선택된 상태의 주문 내역을 페이지 단위로 가져오는 함수
def get_available_order_list_from_page(
    page: int,
    count: int,
    asc: bool,
    statuses: list[str] | None = None,
    customer_id: str | None = None
):
    if page < 1:
        raise HTTPException(
            status_code=400,
            detail="페이지 번호는 1 이상이어야 합니다."
        )

    if count < 1 or count > 100:
        raise HTTPException(
            status_code=400,
            detail="페이지당 조회 개수는 1~100개여야 합니다."
        )

    if customer_id is not None:
        customer_id = customer_id.strip()
        if not customer_id:
            raise HTTPException(
                status_code=400,
                detail="고객 ID는 빈 문자열일 수 없습니다."
            )

    try:
        conn = get_connection()

    except pymysql.MySQLError:
        logger.exception("주문 목록 조회: DB 연결 실패")
        raise HTTPException(
            status_code=503,
            detail="데이터베이스 연결에 실패했습니다."
        )

    try:
        with conn.cursor() as cursor:
            orderby = "ASC" if asc else "DESC"
            offset = (page - 1) * count

            conditions = []
            params = []

            # 주문 상태 필터
            if statuses:
                statuses = list(dict.fromkeys(statuses))
                placeholders = ", ".join(["%s"] * len(statuses))

                conditions.append(
                    f"order_status IN ({placeholders})"
                )
                params.extend(statuses)

            else:
                # 기본적으로 진행 중인 주문만 조회
                conditions.append("""
                    order_status NOT IN (
                        'DELIVERED',
                        'CANCELLED',
                        'RETURNED'
                    )
                """)

            # 고객 ID 필터
            if customer_id is not None:
                conditions.append("customer_id = %s")
                params.append(customer_id)

            where_clause = " AND ".join(conditions)

            sql = f"""
                SELECT *
                FROM orders
                WHERE {where_clause}
                ORDER BY order_seq {orderby}
                LIMIT %s OFFSET %s
            """

            params.extend([count, offset])

            cursor.execute(sql, tuple(params))
            return cursor.fetchall()

    except pymysql.MySQLError:
        logger.exception("주문 목록 조회: SQL 실행 실패")
        raise HTTPException(
            status_code=500,
            detail="주문 목록을 조회하는 중 오류가 발생했습니다."
        )

    finally:
        conn.close()


# 특정 주문 내역에 포함된 구매 상품들의 정보를 가져오는 함수
def get_items_from_order(order_id: str):
    if not order_id or not order_id.strip():
        raise HTTPException(
            status_code=400,
            detail="주문 번호를 입력해야 합니다."
        )

    try:
        conn = get_connection()
    except pymysql.MySQLError:
        logger.exception("주문 상품 조회: DB 연결 실패")
        raise HTTPException(
            status_code=503,
            detail="데이터베이스 연결에 실패했습니다."
        )

    try:
        with conn.cursor() as cursor:
            sql = """
                SELECT
                    oi.order_item_id,
                    oi.purchase_quantity,
                    oi.purchase_unit_price,
                    pi.inventory_id,
                    pi.expires_on,
                    c.cosmetic_id,
                    c.cosmetic_name
                FROM order_items AS oi
                INNER JOIN product_inventory AS pi
                    ON oi.inventory_id = pi.inventory_id
                INNER JOIN cosmetics AS c
                    ON pi.cosmetic_id = c.cosmetic_id
                WHERE oi.order_id = %s
            """

            cursor.execute(sql, (order_id,))
            return cursor.fetchall()

    except pymysql.MySQLError:
        logger.exception(
            "주문 상품 조회 실패: order_id=%s", order_id
        )
        raise HTTPException(
            status_code=500,
            detail="주문 상품 정보를 조회하는 중 오류가 발생했습니다."
        )

    finally:
        conn.close()
