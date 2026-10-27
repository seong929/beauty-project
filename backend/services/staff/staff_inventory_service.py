
import logging
import pymysql

from fastapi import HTTPException
from database import get_connection

logger = logging.getLogger(__name__)


def get_inventory_by_cosmetic_id(
    cosmetic_id: str,
    inventory_status: str | None = None,
    sale_option: str | None = None,
    order_by: str = "received_on",
    asc: bool = False
):
    if not cosmetic_id or not cosmetic_id.strip():
        raise HTTPException(
            status_code=400,
            detail="화장품 ID를 입력해야 합니다."
        )

    allowed_statuses = {"MAINTAIN", "HOLD", "DISCARD"}
    allowed_sale_options = {"NORMAL", "NEAR_EXPIRY"}
    allowed_order_columns = {"received_on", "expires_on"}

    if (
        inventory_status is not None
        and inventory_status not in allowed_statuses
    ):
        raise HTTPException(
            status_code=400,
            detail="올바르지 않은 재고 상태입니다."
        )

    if (
        sale_option is not None
        and sale_option not in allowed_sale_options
    ):
        raise HTTPException(
            status_code=400,
            detail="올바르지 않은 판매 옵션입니다."
        )

    if order_by not in allowed_order_columns:
        raise HTTPException(
            status_code=400,
            detail="정렬 기준은 received_on 또는 expires_on이어야 합니다."
        )

    try:
        conn = get_connection()

    except pymysql.MySQLError:
        logger.exception("재고 목록 조회 중 DB 연결 실패")
        raise HTTPException(
            status_code=503,
            detail="데이터베이스 연결에 실패했습니다."
        )

    try:
        with conn.cursor() as cursor:
            sql = """
                SELECT
                    pi.inventory_id,
                    pi.cosmetic_id,
                    pi.stock_quantity,
                    pi.received_on,
                    pi.expires_on,
                    pi.inventory_status,
                    pi.sale_option
                FROM product_inventory AS pi
                WHERE pi.cosmetic_id = %s
            """

            params = [cosmetic_id]

            if inventory_status is not None:
                sql += " AND pi.inventory_status = %s"
                params.append(inventory_status)

            if sale_option is not None:
                sql += " AND pi.sale_option = %s"
                params.append(sale_option)

            # 정렬 컬럼은 허용된 값만 사용
            direction = "ASC" if asc else "DESC"

            sql += f"""
                ORDER BY
                    pi.{order_by} {direction},
                    pi.inventory_id ASC
            """

            cursor.execute(sql, params)
            return cursor.fetchall()

    except pymysql.MySQLError:
        logger.exception(
            "재고 목록 조회 중 SQL 오류: "
            "cosmetic_id=%s, inventory_status=%s, "
            "sale_option=%s, order_by=%s, asc=%s",
            cosmetic_id,
            inventory_status,
            sale_option,
            order_by,
            asc
        )
        raise HTTPException(
            status_code=500,
            detail="재고 목록 조회 중 데이터베이스 오류가 발생했습니다."
        )

    finally:
        conn.close()
