
import logging
import pymysql

from fastapi import HTTPException
from database import get_connection

logger = logging.getLogger(__name__)


# 옵션별 중복을 제거한 화장품 목록 조회
def get_distinct_cosmetics(
    page: int = 1,
    count: int = 20,
    category_id: str | None = None
):
    if page < 1 or not 1 <= count <= 100:
        raise HTTPException(
            status_code=400,
            detail="페이지는 1 이상, 조회 개수는 1~100이어야 합니다."
        )

    offset = (page - 1) * count

    try:
        conn = get_connection()

    except pymysql.MySQLError:
        logger.exception("화장품 목록 조회 중 DB 연결 실패")
        raise HTTPException(
            status_code=503,
            detail="데이터베이스 연결에 실패했습니다."
        )

    try:
        with conn.cursor() as cursor:
            sql = """
                SELECT DISTINCT
                    c.cosmetic_name,
                    cc.category_name
                FROM cosmetics AS c
                INNER JOIN categories AS cc
                    ON c.category_id = cc.category_id
            """

            params = []

            if category_id is not None:
                sql += """
                    WHERE c.category_id = %s
                """
                params.append(category_id)

            sql += """
                ORDER BY
                    c.cosmetic_name ASC,
                    cc.category_name ASC
                LIMIT %s OFFSET %s
            """

            params.extend([count, offset])

            cursor.execute(sql, params)
            return cursor.fetchall()

    except pymysql.MySQLError:
        logger.exception(
            "화장품 목록 조회 중 SQL 오류: "
            "page=%s, count=%s, category_id=%s",
            page,
            count,
            category_id
        )
        raise HTTPException(
            status_code=500,
            detail="화장품 목록 조회 중 데이터베이스 오류가 발생했습니다."
        )

    finally:
        conn.close()

# 특정 화장품 이름에 해당하는 모든 옵션별 상품 조회
def get_cosmetic_options(cosmetic_name: str):
    if not cosmetic_name or not cosmetic_name.strip():
        raise HTTPException(
            status_code=400,
            detail="화장품 이름을 입력해야 합니다."
        )

    try:
        conn = get_connection()

    except pymysql.MySQLError:
        logger.exception("화장품 옵션 조회 중 DB 연결 실패")
        raise HTTPException(
            status_code=503,
            detail="데이터베이스 연결에 실패했습니다."
        )

    try:
        with conn.cursor() as cursor:
            sql = """
                SELECT
                    c.*,

                    -- 최신 판매 가격
                    ph.sale_price,
                    ph.changed_on AS price_changed_on,

                    -- 최신 용량
                    vh.volume_text,
                    vh.changed_on AS volume_changed_on,

                    -- 최신 판매 상태
                    sh.sale_status,
                    sh.changed_on AS sale_status_changed_on,

                    -- 최신 원가
                    coh.unit_cost,
                    coh.changed_on AS cost_changed_on,

                    -- 최신 최소 재고량
                    mh.min_stock_qty,
                    mh.changed_on AS min_stock_changed_on,

                    -- 최신 목표 재고량
                    th.target_stock_qty,
                    th.changed_on AS target_stock_changed_on

                FROM cosmetics AS c

                LEFT JOIN cosmetic_price_history AS ph
                    ON ph.change_id = (
                        SELECT h.change_id
                        FROM cosmetic_price_history AS h
                        WHERE h.cosmetic_id = c.cosmetic_id
                        ORDER BY
                            h.changed_on DESC,
                            CAST(
                                SUBSTRING_INDEX(h.change_id, '_', -1)
                                AS UNSIGNED
                            ) DESC
                        LIMIT 1
                    )

                LEFT JOIN cosmetic_volume_history AS vh
                    ON vh.change_id = (
                        SELECT h.change_id
                        FROM cosmetic_volume_history AS h
                        WHERE h.cosmetic_id = c.cosmetic_id
                        ORDER BY
                            h.changed_on DESC,
                            CAST(
                                SUBSTRING_INDEX(h.change_id, '_', -1)
                                AS UNSIGNED
                            ) DESC
                        LIMIT 1
                    )

                LEFT JOIN cosmetic_sale_status_history AS sh
                    ON sh.change_id = (
                        SELECT h.change_id
                        FROM cosmetic_sale_status_history AS h
                        WHERE h.cosmetic_id = c.cosmetic_id
                        ORDER BY
                            h.changed_on DESC,
                            CAST(
                                SUBSTRING_INDEX(h.change_id, '_', -1)
                                AS UNSIGNED
                            ) DESC
                        LIMIT 1
                    )

                LEFT JOIN cosmetic_cost_history AS coh
                    ON coh.change_id = (
                        SELECT h.change_id
                        FROM cosmetic_cost_history AS h
                        WHERE h.cosmetic_id = c.cosmetic_id
                        ORDER BY
                            h.changed_on DESC,
                            CAST(
                                SUBSTRING_INDEX(h.change_id, '_', -1)
                                AS UNSIGNED
                            ) DESC
                        LIMIT 1
                    )

                LEFT JOIN cosmetic_min_stock_history AS mh
                    ON mh.change_id = (
                        SELECT h.change_id
                        FROM cosmetic_min_stock_history AS h
                        WHERE h.cosmetic_id = c.cosmetic_id
                        ORDER BY
                            h.changed_on DESC,
                            CAST(
                                SUBSTRING_INDEX(h.change_id, '_', -1)
                                AS UNSIGNED
                            ) DESC
                        LIMIT 1
                    )

                LEFT JOIN cosmetic_target_stock_history AS th
                    ON th.change_id = (
                        SELECT h.change_id
                        FROM cosmetic_target_stock_history AS h
                        WHERE h.cosmetic_id = c.cosmetic_id
                        ORDER BY
                            h.changed_on DESC,
                            CAST(
                                SUBSTRING_INDEX(h.change_id, '_', -1)
                                AS UNSIGNED
                            ) DESC
                        LIMIT 1
                    )

                WHERE c.cosmetic_name = %s

                ORDER BY
                    c.manufacturer_id ASC,
                    c.category_id ASC,
                    c.cosmetic_name_seq ASC,
                    c.cosmetic_type_seq ASC
            """

            cursor.execute(sql, (cosmetic_name,))
            rows = cursor.fetchall()

            if not rows:
                raise HTTPException(
                    status_code=404,
                    detail="해당 이름의 화장품이 존재하지 않습니다."
                )

            return rows

    except HTTPException:
        raise

    except pymysql.MySQLError:
        logger.exception(
            "화장품 옵션 및 최신 이력 조회 중 SQL 오류: "
            "cosmetic_name=%s",
            cosmetic_name
        )
        raise HTTPException(
            status_code=500,
            detail="화장품 옵션 및 이력 조회 중 데이터베이스 오류가 발생했습니다."
        )

    finally:
        conn.close()