from fastapi import APIRouter, Form, HTTPException, Query
import pymysql
from pwdlib import PasswordHash
from database import get_connection
from services.customer.customer_service import (
    append_account_status,
    get_account_status,
    next_sequence,
)



router = APIRouter(tags=["고객 상품 조회"])
password_hasher = PasswordHash.recommended()


# 고객 상품 조회
@router.get("/customers_categories_search", tags=["고객 상품 조회"], summary="고객 상품 조회")
def customers_categories():
    conn = get_connection()
    try:
        with conn.cursor() as curs:
            curs.execute(
                """
                    SELECT
                    c.cosmetic_id,
                    c.cosmetic_name,
                    m.manufacturer_name,
                    cat.category_name,

                    -- 최신 용량
                    (
                        SELECT vh.volume_text
                        FROM cosmetic_volume_history AS vh
                        WHERE vh.cosmetic_id = c.cosmetic_id
                        ORDER BY
                            vh.changed_on DESC,
                            CAST(
                                SUBSTRING_INDEX(vh.change_id, '_', -1)
                                AS UNSIGNED
                            ) DESC
                        LIMIT 1
                    ) AS volume_text,

                    -- 최신 판매 가격
                    (
                        SELECT ph.sale_price
                        FROM cosmetic_price_history AS ph
                        WHERE ph.cosmetic_id = c.cosmetic_id
                        ORDER BY
                            ph.changed_on DESC,
                            CAST(
                                SUBSTRING_INDEX(ph.change_id, '_', -1)
                                AS UNSIGNED
                            ) DESC
                        LIMIT 1
                    ) AS sale_price,

                    COALESCE(i.available_quantity, 0)
                        AS available_quantity,

                    CASE
                        WHEN COALESCE(i.available_quantity, 0) > 0
                            THEN '구매 가능'
                        ELSE '품절'
                    END AS availability

                FROM cosmetics AS c

                JOIN manufacturers AS m
                    ON m.manufacturer_id = c.manufacturer_id

                JOIN categories AS cat
                    ON cat.category_id = c.category_id

                -- 판매 가능한 입고별 재고 합산
                LEFT JOIN (
                    SELECT
                        cosmetic_id,
                        SUM(stock_quantity) AS available_quantity
                    FROM product_inventory
                    WHERE inventory_status = 'MAINTAIN'
                    AND stock_quantity > 0
                    AND (
                        expires_on IS NULL
                        OR expires_on >= CURDATE()
                      )
                    GROUP BY cosmetic_id
                ) AS i
                    ON i.cosmetic_id = c.cosmetic_id

                -- 최신 판매 상태가 판매 중인 상품만 조회
                WHERE (
                    SELECT sh.sale_status
                    FROM cosmetic_sale_status_history AS sh
                    WHERE sh.cosmetic_id = c.cosmetic_id
                    ORDER BY
                        sh.changed_on DESC,
                        CAST(
                            SUBSTRING_INDEX(sh.change_id, '_', -1)
                            AS UNSIGNED
                        ) DESC
                    LIMIT 1
                ) = 'ON_SALE'

                ORDER BY c.cosmetic_name, c.cosmetic_id
                """
            )
            rows = curs.fetchall()
        return {"result": rows}
    finally:
        conn.close()
