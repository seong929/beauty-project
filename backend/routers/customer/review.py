from contextlib import contextmanager

import pymysql
from fastapi import APIRouter, Form, HTTPException, Query

from database import get_connection

router = APIRouter(tags=["리뷰"])


@contextmanager
def review_cursor(*, write=False):
    conn = None
    try:
        conn = get_connection()
        if write:
            conn.begin()
        with conn.cursor() as cursor:
            yield cursor
        if write:
            conn.commit()
    except HTTPException:
        if conn is not None and write:
            conn.rollback()
        raise
    except pymysql.MySQLError as error:
        if conn is not None and write:
            conn.rollback()
        if isinstance(error, pymysql.IntegrityError) and error.args and error.args[0] == 1062:
            raise HTTPException(409, "이미 등록한 리뷰가 있습니다. 기존 리뷰를 수정해 주세요.") from None
        raise HTTPException(503, "리뷰 요청을 처리하지 못했습니다. 다시 조회해 주세요.") from None
    finally:
        if conn is not None:
            conn.close()


def clean(value, label):
    value = value.strip()
    if not value:
        raise HTTPException(422, f"{label}을(를) 입력해 주세요.")
    return value


def next_sequence(cursor, scope_name):
    cursor.execute(
        """INSERT INTO id_counters (scope_name, `last_value`)
           VALUES (%s, LAST_INSERT_ID(1))
           ON DUPLICATE KEY UPDATE
               `last_value` = LAST_INSERT_ID(`last_value` + 1)""",
        (scope_name,),
    )
    cursor.execute("SELECT LAST_INSERT_ID() AS seq")
    return cursor.fetchone()["seq"]


def delivered_products_sql(customer_id, cosmetic_id=None):
    # 주문 전체가 배송 완료되었거나, 해당 구매항목에 연결된 분할 배송이 완료된 상품만 선택한다.
    sql = """SELECT DISTINCT pi.cosmetic_id
             FROM orders AS o
             JOIN order_items AS oi ON oi.order_id = o.order_id
             JOIN product_inventory AS pi ON pi.inventory_id = oi.inventory_id
             LEFT JOIN stock_outbounds AS so ON so.order_item_id = oi.order_item_id
             LEFT JOIN delivery_information AS d
                    ON d.delivery_id = so.delivery_id AND d.order_id = o.order_id
             WHERE o.customer_id = %s AND o.order_status <> 'CANCELLED'
               AND (o.order_status = 'DELIVERED' OR d.delivery_status = 'DELIVERED')"""
    params = [customer_id]
    if cosmetic_id is not None:
        sql += " AND pi.cosmetic_id = %s"
        params.append(cosmetic_id)
    return sql, tuple(params)


@router.get("/reviews_eligibility", summary="배송 완료된 리뷰 작성 가능 상품 조회")
def reviews_eligibility(
    customer_id: str = Query(..., min_length=1, max_length=64, pattern=r"\S"),
    cosmetic_id: str | None = Query(None, min_length=1, max_length=160, pattern=r"\S"),
):
    with review_cursor() as cursor:
        sql, params = delivered_products_sql(customer_id.strip(), cosmetic_id.strip() if cosmetic_id else None)
        cursor.execute(sql, params)
        return {"result": cursor.fetchall()}


@router.post("/reviews_upload", summary="배송 완료 구매 상품 리뷰 등록")
def reviews_upload(
    customer_id: str = Form(..., min_length=1, max_length=64),
    cosmetic_id: str = Form(..., min_length=1, max_length=160),
    review_content: str = Form(..., min_length=1, max_length=2000),
    rating: int = Form(..., ge=1, le=5),
):
    customer_id = clean(customer_id, "고객번호")
    cosmetic_id = clean(cosmetic_id, "상품번호")
    content = clean(review_content, "리뷰 내용")
    with review_cursor(write=True) as cursor:
        # 같은 고객의 동시 리뷰 등록을 직렬화한다. 고객·상품 중복은 기존 DB 고유키로도 막는다.
        cursor.execute("SELECT customer_id FROM customers WHERE customer_id = %s FOR UPDATE", (customer_id,))
        if cursor.fetchone() is None:
            raise HTTPException(404, "존재하지 않는 고객입니다.")
        sql, params = delivered_products_sql(customer_id, cosmetic_id)
        cursor.execute(sql + " LIMIT 1", params)
        if cursor.fetchone() is None:
            raise HTTPException(403, "배송 완료된 구매 상품만 리뷰를 작성할 수 있습니다.")
        review_id = f"rev_{next_sequence(cursor, 'review')}"
        # 별점과 본문을 함께 저장한다. 임의의 집계 값은 저장하지 않는다.
        cursor.execute(
            """INSERT INTO reviews (review_id, customer_id, cosmetic_id, review_content, rating)
               VALUES (%s, %s, %s, %s, %s)""",
            (review_id, customer_id, cosmetic_id, content, rating),
        )
    return {"result": "OK", "review_id": review_id, "customer_id": customer_id, "cosmetic_id": cosmetic_id}


@router.get("/reviews_select", summary="상품별·고객별 리뷰 조회")
def reviews_select(
    review_id: str | None = Query(None, min_length=1, max_length=64, pattern=r"\S"),
    customer_id: str | None = Query(None, min_length=1, max_length=64, pattern=r"\S"),
    cosmetic_id: str | None = Query(None, min_length=1, max_length=160, pattern=r"\S"),
):
    with review_cursor() as cursor:
        sql = """SELECT r.review_id, r.customer_id, c.customer_name,
                        r.cosmetic_id, p.cosmetic_name, r.review_content, r.rating, r.reviewed_at
                 FROM reviews AS r
                 JOIN customers AS c ON c.customer_id = r.customer_id
                 JOIN cosmetics AS p ON p.cosmetic_id = r.cosmetic_id
                 WHERE 1 = 1"""
        params = []
        for field, value in (("review_id", review_id), ("customer_id", customer_id), ("cosmetic_id", cosmetic_id)):
            if value is not None:
                sql += f" AND r.{field} = %s"
                params.append(value.strip())
        sql += " ORDER BY r.reviewed_at DESC, CAST(SUBSTRING_INDEX(r.review_id, '_', -1) AS UNSIGNED) DESC"
        cursor.execute(sql, tuple(params))
        return {"result": cursor.fetchall()}


def owned_review(cursor, review_id, customer_id):
    # 변경할 리뷰를 잠근 뒤 작성자만 수정·삭제할 수 있는지 확인한다.
    cursor.execute("SELECT review_id, customer_id, cosmetic_id FROM reviews WHERE review_id = %s FOR UPDATE", (review_id,))
    review = cursor.fetchone()
    if review is None:
        raise HTTPException(404, "존재하지 않는 리뷰입니다.")
    if review["customer_id"] != customer_id:
        raise HTTPException(403, "작성자만 리뷰를 수정·삭제할 수 있습니다.")
    return review


@router.put("/reviews_update", summary="내 리뷰·별점 수정")
def reviews_update(
    review_id: str = Form(..., min_length=1, max_length=64),
    customer_id: str = Form(..., min_length=1, max_length=64),
    review_content: str = Form(..., min_length=1, max_length=2000),
    rating: int = Form(..., ge=1, le=5),
):
    review_id = clean(review_id, "리뷰번호")
    customer_id = clean(customer_id, "고객번호")
    content = clean(review_content, "리뷰 내용")
    with review_cursor(write=True) as cursor:
        review = owned_review(cursor, review_id, customer_id)
        cursor.execute(
            "UPDATE reviews SET review_content = %s, rating = %s WHERE review_id = %s AND customer_id = %s",
            (content, rating, review_id, customer_id),
        )
    return {"result": "OK", "review_id": review_id, "customer_id": customer_id,
            "cosmetic_id": review["cosmetic_id"], "message": "리뷰를 수정했습니다."}


@router.delete("/reviews_delete", summary="내 리뷰 삭제")
def reviews_delete(
    review_id: str = Form(..., min_length=1, max_length=64),
    customer_id: str = Form(..., min_length=1, max_length=64),
):
    review_id = clean(review_id, "리뷰번호")
    customer_id = clean(customer_id, "고객번호")
    with review_cursor(write=True) as cursor:
        review = owned_review(cursor, review_id, customer_id)
        cursor.execute("DELETE FROM reviews WHERE review_id = %s AND customer_id = %s", (review_id, customer_id))
        if cursor.rowcount != 1:
            raise HTTPException(409, "리뷰가 변경되었습니다. 다시 조회해 주세요.")
    return {"result": "OK", "review_id": review_id, "customer_id": customer_id,
            "cosmetic_id": review["cosmetic_id"], "deleted_count": 1}
