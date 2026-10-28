from fastapi import APIRouter, Form, HTTPException, Query
from database import get_connection
from services.customer.customer_service import next_sequence

router = APIRouter(tags=["리뷰"])
def next_sequence(cursor, scope_name):
    """호출자의 DB 트랜잭션 안에서 순번을 할당합니다."""
    cursor.execute(
        """INSERT INTO id_counters (scope_name, `last_value`)
           VALUES (%s, LAST_INSERT_ID(1))
           ON DUPLICATE KEY UPDATE
               `last_value` = LAST_INSERT_ID(`last_value` + 1)""",
        (scope_name,),
    )
    cursor.execute("SELECT LAST_INSERT_ID() AS seq")
    return cursor.fetchone()["seq"]




# 리뷰 등록
@router.post("/reviews_upload")
def reviews_upload(
    customer_id: str = Form(...,),
    cosmetic_id: str = Form(...,),
    review_content: str = Form(...,),
    rating: int = Form(..., ge=1, le=5),
):
    conn = None
    try:
        conn = get_connection()
        with conn.cursor() as curs:
            review_id = f"rev_{next_sequence(curs, 'review')}"
            sql = """
                INSERT INTO reviews (
                review_id,
                customer_id,
                cosmetic_id,
                review_content,
                rating
                )
                VALUES (%s, %s, %s, %s, %s)
            """

            curs.execute(sql, (
                review_id,
                customer_id,
                cosmetic_id,
                review_content,
                rating
            ))
        conn.commit()
        return {
            "result": "OK",
            "customer_id": customer_id,
        }
    except Exception:
        if conn is not None:
            conn.rollback()
        raise

    finally:
        if conn is not None:
            conn.close()


# 리뷰 조회
@router.get("/reviews_select")
def reviews_select(
    review_id: str | None = Query(None),
    customer_id: str | None = Query(None),
    cosmetic_id: str | None = Query(None),
):
    conn = get_connection()

    try:
        with conn.cursor() as curs:
            sql = """
                SELECT
                    r.review_id,
                    r.customer_id,
                    c.customer_name,
                    r.cosmetic_id,
                    p.cosmetic_name,
                    r.review_content,
                    r.rating,
                    r.reviewed_at
                FROM reviews AS r
                JOIN customers AS c
                    ON c.customer_id = r.customer_id
                JOIN cosmetics AS p
                    ON p.cosmetic_id = r.cosmetic_id
                WHERE 1 = 1
            """

            params = []

            # 입력 조건
            if review_id:
                sql += " AND r.review_id = %s"
                params.append(review_id)

            if customer_id:
                sql += " AND r.customer_id = %s"
                params.append(customer_id)

            if cosmetic_id:
                sql += " AND r.cosmetic_id = %s"
                params.append(cosmetic_id)

            sql += """
                ORDER BY
                    r.reviewed_at DESC,
                    CAST(
                        SUBSTRING_INDEX(r.review_id, '_', -1)
                        AS UNSIGNED
                    ) DESC
            """

            curs.execute(sql, tuple(params))
            rows = curs.fetchall()
        return {"result": rows}
    except Exception:
        if conn is not None:
            conn.rollback()
        raise

    finally:
        if conn is not None:
            conn.close()

# 리뷰 수정
@router.put("/reviews_update")
def reviews_update(
    review_id: str = Form(...,),
    customer_id: str = Form(...,),
    review_content: str = Form(...,),
    rating: int = Form(..., ge=1, le=5),
):
    conn = None
    try:
        conn = get_connection()
        conn.begin()
        with conn.cursor() as curs:
            curs.execute(
                "SELECT review_id, customer_id FROM reviews WHERE review_id = %s FOR UPDATE",
                (review_id,),
            )
            review = curs.fetchone()
            if review is None:
                raise HTTPException(404, "존재하지 않는 리뷰입니다.")

            if review["customer_id"] != customer_id:
                raise HTTPException(403, "작성자만 수정할 수 있습니다.")
                
            curs.execute(
                """
                UPDATE reviews
                SET review_content = %s,
                    rating = %s
                WHERE review_id = %s AND
                    customer_id = %s
                """,
                (review_content, rating, review_id, customer_id),
            )
        conn.commit()
        
        return {"result": "OK", "review_id": review_id,
                "message": "리뷰가 수정되었습니다."}
        
    except Exception:
        if conn is not None:
            conn.rollback()
        raise

    finally:
        if conn is not None:
            conn.close()


# 리뷰 삭제
@router.delete("/reviews_delete")
def reviews_delete(
    review_id: str = Form(...),
    customer_id:str = Form(...)):
    conn = None
    try:
        conn = get_connection()
        curs = conn.cursor()
        curs.execute(
            """
                DELETE FROM reviews
                WHERE review_id = %s
                AND customer_id = %s
                """,
            (review_id,customer_id),
        )

        deleted_count = curs.rowcount
        conn.commit()
        return {"result": "OK",
                "deleted_count": deleted_count}

    except Exception:
        if conn is not None:
            conn.rollback()
        raise

    finally:
        if conn is not None:
            conn.close()