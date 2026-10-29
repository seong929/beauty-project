
import logging
import pymysql

from fastapi import HTTPException
from database import get_connection

logger = logging.getLogger(__name__)
# UI 검색용 가상 상태. DB inventory_status ENUM에는 추가하지 않습니다.
INVENTORY_FILTER_STATUSES = {"MAINTAIN", "HOLD", "DISCARD", "DISCARD_COMPLETED"}


def _status_filter_clause(alias: str, inventory_status: str | None) -> tuple[str, list]:
    if inventory_status is None:
        return "", []
    if inventory_status not in INVENTORY_FILTER_STATUSES:
        raise HTTPException(status_code=400, detail="유효하지 않은 재고 상태입니다.")
    if inventory_status == "DISCARD":
        return f"{alias}.inventory_status = %s AND {alias}.stock_quantity > 0", ["DISCARD"]
    if inventory_status == "DISCARD_COMPLETED":
        return f"{alias}.inventory_status = %s AND {alias}.stock_quantity = 0", ["DISCARD"]
    return f"{alias}.inventory_status = %s", [inventory_status]



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

    allowed_statuses = INVENTORY_FILTER_STATUSES
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

            status_sql, status_params = _status_filter_clause("pi", inventory_status)
            if status_sql:
                sql += " AND " + status_sql
                params.extend(status_params)

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

    
def get_inventory_grouped_by_status(
    inventory_status: str | None = None,
    cosmetic_id: str | None = None,
    sale_option: str | None = None,
    page: int = 1,
    count: int = 20,
    descending: bool = True,
) -> dict:
    """상태별 전체 집계와 한 페이지의 재고만 반환한다.

    전체 재고를 Python 메모리로 가져오지 않고 MySQL LIMIT/OFFSET으로 제한한다.
    기본 DESC 우선순위: DISCARD -> HOLD -> MAINTAIN.
    """
    if inventory_status is not None and inventory_status not in INVENTORY_FILTER_STATUSES:
        raise HTTPException(status_code=400, detail="유효하지 않은 재고 상태입니다.")
    if sale_option not in (None, "NORMAL", "NEAR_EXPIRY"):
        raise HTTPException(status_code=400, detail="유효하지 않은 판매 옵션입니다.")
    if cosmetic_id is not None and not cosmetic_id.strip():
        raise HTTPException(status_code=400, detail="화장품 ID를 입력해야 합니다.")
    if type(page) is not int or page < 1 or type(count) is not int or not 1 <= count <= 100:
        raise HTTPException(status_code=400, detail="page는 1 이상, count는 1~100이어야 합니다.")

    conditions = []
    params = []
    if cosmetic_id is not None:
        conditions.append("pi.cosmetic_id = %s")
        params.append(cosmetic_id)
    if sale_option is not None:
        conditions.append("pi.sale_option = %s")
        params.append(sale_option)
    where = " WHERE " + " AND ".join(conditions) if conditions else ""
    list_conditions = conditions.copy()
    list_params = params.copy()
    status_sql, status_params = _status_filter_clause("pi", inventory_status)
    if status_sql:
        list_conditions.append(status_sql)
        list_params.extend(status_params)
    list_where = " WHERE " + " AND ".join(list_conditions) if list_conditions else ""
    # 전체 집계는 상태 필터와 무관하게 출력해 그룹별 총량을 보여준다.
    # 같은 base filter는 유지한다.
    order_case = ("CASE "
                  "WHEN pi.inventory_status='DISCARD' AND pi.stock_quantity > 0 THEN 0 "
                  "WHEN pi.inventory_status='HOLD' THEN 1 "
                  "WHEN pi.inventory_status='MAINTAIN' THEN 2 "
                  "WHEN pi.inventory_status='DISCARD' AND pi.stock_quantity = 0 THEN 3 "
                  "ELSE 4 END")
    order_direction = "ASC" if descending else "DESC"
    offset = (page - 1) * count

    try:
        conn = get_connection()
    except pymysql.MySQLError:
        logger.exception("상태별 재고 조회 DB 연결 실패")
        raise HTTPException(status_code=503, detail="데이터베이스 연결에 실패했습니다.")

    try:
        with conn.cursor() as cursor:
            cursor.execute(
                "SELECT CASE WHEN pi.inventory_status='DISCARD' "
                "AND pi.stock_quantity=0 THEN 'DISCARD_COMPLETED' "
                "ELSE pi.inventory_status END AS filter_status, "
                "COUNT(*) AS inventory_count, "
                "COALESCE(SUM(pi.stock_quantity), 0) AS total_quantity "
                "FROM product_inventory pi" + where +
                " GROUP BY filter_status", params,
            )
            summary_rows = cursor.fetchall()
            cursor.execute(
                "SELECT COUNT(*) AS total FROM product_inventory pi" + list_where,
                list_params,
            )
            total = int(cursor.fetchone()["total"])
            cursor.execute(
                "SELECT pi.inventory_id, pi.cosmetic_id, c.cosmetic_name, "
                "pi.stock_quantity, pi.received_on, pi.expires_on, "
                "pi.inventory_status, pi.sale_option "
                "FROM product_inventory pi "
                "LEFT JOIN cosmetics c ON c.cosmetic_id = pi.cosmetic_id "
                + list_where + " ORDER BY " + order_case + " " + order_direction
                + ", pi.received_on DESC, pi.inventory_id ASC "
                "LIMIT %s OFFSET %s",
                [*list_params, count, offset],
            )
            inventories = cursor.fetchall()

        summary = {
            state: {"inventory_count": 0, "total_quantity": 0}
            for state in ("MAINTAIN", "HOLD", "DISCARD", "DISCARD_COMPLETED")
        }
        for row in summary_rows:
            summary[row["filter_status"]] = {
                "inventory_count": int(row["inventory_count"]),
                "total_quantity": int(row["total_quantity"]),
            }
        total_pages = max(1, (total + count - 1) // count)
        return {
            "summary": summary,
            "filters": {
                "inventory_status": inventory_status,
                "cosmetic_id": cosmetic_id,
                "sale_option": sale_option,
            },
            "pagination": {
                "page": page,
                "count": count,
                "total": total,
                "total_pages": total_pages,
                "has_next": page < total_pages,
                "has_previous": page > 1,
            },
            "inventories": inventories,
        }
    except pymysql.MySQLError:
        logger.exception("상태별 재고 조회 SQL 오류")
        raise HTTPException(status_code=500, detail="재고 조회 중 DB 오류가 발생했습니다.")
    finally:
        conn.close()


def discard_inventory_stock(
    inventory_id: str,
    quantity: int
) -> dict:
    """DISCARD 상태의 재고 수량을 차감한다."""

    if not inventory_id or not inventory_id.strip():
        raise HTTPException(
            status_code=400,
            detail="재고 ID를 입력해야 합니다."
        )

    if type(quantity) is not int or quantity <= 0:
        raise HTTPException(
            status_code=400,
            detail="폐기 수량은 1 이상의 정수여야 합니다."
        )

    try:
        conn = get_connection()
    except pymysql.MySQLError:
        logger.exception("재고 폐기 DB 연결 실패")
        raise HTTPException(
            status_code=503,
            detail="데이터베이스 연결에 실패했습니다."
        )

    try:
        with conn.cursor() as cursor:
            # 동시 폐기 요청 방지
            cursor.execute(
                """
                SELECT
                    inventory_status,
                    stock_quantity
                FROM product_inventory
                WHERE inventory_id = %s
                FOR UPDATE
                """,
                (inventory_id,)
            )

            row = cursor.fetchone()

            if row is None:
                raise HTTPException(
                    status_code=404,
                    detail="존재하지 않는 재고입니다."
                )

            if row["inventory_status"] != "DISCARD":
                raise HTTPException(
                    status_code=409,
                    detail="DISCARD 상태의 재고만 폐기할 수 있습니다."
                )

            before = int(row["stock_quantity"])

            if before < quantity:
                raise HTTPException(
                    status_code=409,
                    detail="폐기 수량이 현재 재고량보다 많습니다."
                )

            cursor.execute(
                """
                UPDATE product_inventory
                SET stock_quantity = stock_quantity - %s
                WHERE inventory_id = %s
                  AND inventory_status = 'DISCARD'
                  AND stock_quantity >= %s
                """,
                (quantity, inventory_id, quantity)
            )

            if cursor.rowcount != 1:
                raise HTTPException(
                    status_code=409,
                    detail="재고 차감에 실패했습니다."
                )

        conn.commit()

        return {
            "inventory_id": inventory_id,
            "inventory_status": "DISCARD",
            "discarded_quantity": quantity,
            "previous_quantity": before,
            "stock_quantity": before - quantity
        }

    except HTTPException:
        conn.rollback()
        raise

    except pymysql.MySQLError:
        conn.rollback()
        logger.exception(
            "재고 폐기 SQL 오류: %s",
            inventory_id
        )
        raise HTTPException(
            status_code=500,
            detail="재고 폐기 중 DB 오류가 발생했습니다."
        )

    except Exception:
        conn.rollback()
        logger.exception(
            "재고 폐기 서버 오류: %s",
            inventory_id
        )
        raise HTTPException(
            status_code=500,
            detail="재고 폐기 중 서버 오류가 발생했습니다."
        )

    finally:
        conn.close()

"""Inventory history read-only services. Append to services/staff/staff_inventory_service.py."""


def get_inventory_detail(inventory_id: str) -> dict:
    """상품 재고 배치 1건과 표시용 화장품 이름을 조회한다."""
    if not inventory_id or not inventory_id.strip():
        raise HTTPException(status_code=400, detail="재고 ID를 입력해야 합니다.")
    try:
        conn = get_connection()
    except pymysql.MySQLError:
        logger.exception("재고 상세 DB 연결 실패")
        raise HTTPException(status_code=503, detail="데이터베이스 연결에 실패했습니다.")
    try:
        with conn.cursor() as cursor:
            cursor.execute(
                """SELECT pi.inventory_id, pi.cosmetic_id, c.cosmetic_name,
                          pi.stock_quantity, pi.received_on, pi.expires_on,
                          pi.inventory_status, pi.sale_option
                   FROM product_inventory AS pi
                   INNER JOIN cosmetics AS c ON c.cosmetic_id = pi.cosmetic_id
                   WHERE pi.inventory_id = %s""",
                (inventory_id,),
            )
            detail = cursor.fetchone()
            if detail is None:
                raise HTTPException(status_code=404, detail="존재하지 않는 재고입니다.")
            return detail
    except pymysql.MySQLError:
        logger.exception("재고 상세 SQL 조회 오류: inventory_id=%s", inventory_id)
        raise HTTPException(status_code=500, detail="재고 상세 조회 중 DB 오류가 발생했습니다.")
    finally:
        conn.close()


def get_inventory_inbound_history(inventory_id: str) -> dict:
    """재고 배치의 입고 이력. 현행 스키마는 inventory_id당 0~1건."""
    if not inventory_id or not inventory_id.strip():
        raise HTTPException(status_code=400, detail="재고 ID를 입력해야 합니다.")
    try:
        conn = get_connection()
    except pymysql.MySQLError:
        logger.exception("입고 이력 DB 연결 실패")
        raise HTTPException(status_code=503, detail="데이터베이스 연결에 실패했습니다.")
    try:
        with conn.cursor() as cursor:
            cursor.execute(
                "SELECT 1 FROM product_inventory WHERE inventory_id = %s", (inventory_id,)
            )
            if cursor.fetchone() is None:
                raise HTTPException(status_code=404, detail="존재하지 않는 재고입니다.")
            cursor.execute(
                """SELECT ih.inbound_id, ih.inventory_id, ih.purchase_order_id,
                          ih.inbound_seq, ih.inbound_quantity, ih.inbound_on
                   FROM inbound_history AS ih
                   WHERE ih.inventory_id = %s
                   ORDER BY ih.inbound_on DESC, ih.inbound_id DESC""",
                (inventory_id,),
            )
            rows = cursor.fetchall()
            return {"inventory_id": inventory_id, "inbounds": rows}
    except pymysql.MySQLError:
        logger.exception("입고 이력 SQL 조회 오류: inventory_id=%s", inventory_id)
        raise HTTPException(status_code=500, detail="입고 이력 조회 중 DB 오류가 발생했습니다.")
    finally:
        conn.close()


def get_inventory_outbound_history(inventory_id: str, page: int = 1, count: int = 20) -> dict:
    """출고 예약 및 확정 건을 N:1 inventory 기준으로 페이지 조회한다."""
    if not inventory_id or not inventory_id.strip():
        raise HTTPException(status_code=400, detail="재고 ID를 입력해야 합니다.")
    if type(page) is not int or page < 1 or type(count) is not int or not 1 <= count <= 100:
        raise HTTPException(status_code=400, detail="page는 1 이상, count는 1~100이어야 합니다.")
    try:
        conn = get_connection()
    except pymysql.MySQLError:
        logger.exception("출고 이력 DB 연결 실패")
        raise HTTPException(status_code=503, detail="데이터베이스 연결에 실패했습니다.")
    try:
        with conn.cursor() as cursor:
            cursor.execute(
                "SELECT 1 FROM product_inventory WHERE inventory_id = %s", (inventory_id,)
            )
            if cursor.fetchone() is None:
                raise HTTPException(status_code=404, detail="존재하지 않는 재고입니다.")
            cursor.execute(
                """SELECT COUNT(*) AS total,
                          COALESCE(SUM(CASE WHEN so.outbound_on IS NULL
                                        THEN so.outbound_quantity ELSE 0 END), 0) AS reserved_quantity,
                          COALESCE(SUM(CASE WHEN so.outbound_on IS NOT NULL
                                        THEN so.outbound_quantity ELSE 0 END), 0) AS confirmed_quantity
                   FROM stock_outbounds AS so
                   WHERE so.inventory_id = %s""",
                (inventory_id,),
            )
            totals = cursor.fetchone()
            total = int(totals["total"])
            cursor.execute(
                """SELECT so.order_item_id, so.inventory_id,
                          oi.order_id, o.order_status,
                          so.delivery_id, so.outbound_quantity, so.outbound_on,
                          CASE WHEN so.outbound_on IS NULL THEN 'RESERVED'
                               ELSE 'CONFIRMED' END AS outbound_status
                   FROM stock_outbounds AS so
                   INNER JOIN order_items AS oi
                     ON oi.order_item_id = so.order_item_id
                    AND oi.inventory_id = so.inventory_id
                   INNER JOIN orders AS o ON o.order_id = oi.order_id
                   WHERE so.inventory_id = %s
                   ORDER BY CASE WHEN so.outbound_on IS NULL THEN 0 ELSE 1 END ASC,
                            so.outbound_on DESC, so.order_item_id DESC
                   LIMIT %s OFFSET %s""",
                (inventory_id, count, (page - 1) * count),
            )
            rows = cursor.fetchall()
            total_pages = max(1, (total + count - 1) // count)
            return {
                "inventory_id": inventory_id,
                "outbounds": rows,
                "summary": {
                    "reserved_quantity": int(totals["reserved_quantity"]),
                    "confirmed_quantity": int(totals["confirmed_quantity"]),
                },
                "pagination": {
                    "page": page, "count": count, "total": total,
                    "total_pages": total_pages,
                    "has_previous": page > 1, "has_next": page < total_pages,
                },
            }
    except pymysql.MySQLError:
        logger.exception("출고 이력 SQL 조회 오류: inventory_id=%s", inventory_id)
        raise HTTPException(status_code=500, detail="출고 이력 조회 중 DB 오류가 발생했습니다.")
    finally:
        conn.close()
