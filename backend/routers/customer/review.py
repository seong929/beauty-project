from fastapi import APIRouter, Form, HTTPException, Query
import pymysql

from database import get_connection
from services.customer.customer_service import next_sequence

router = APIRouter(tags=["리뷰"])


# 리뷰 등록
@router.post("/reviews_upload", tags=["리뷰 등록"], summary="리뷰 등록")
def reviews_upload(
    customer_id: str = Form(...,),
    cosmetic_id: str = Form(...,),
    review_content: str = Form(...,),
    rating: int = Form(..., ge=1, le=5),
):
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
        conn.close()

        return {
            "result": "OK",
            "customer_id": customer_id,
        }

    except Exception as e:
        return {'result' : 'Error'}



# 리뷰 조회
@router.get("/reviews_select", tags=["리뷰 조회"], summary="리뷰 조회")
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
    finally:
        conn.close()


# 리뷰 수정
@router.put("/reviews_update", tags=["리뷰 수정"], summary="리뷰 수정")
def reviews_update(
    review_id: str = Query(...,),
    customer_id: str = Query(...,),
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
            curs.execute(
                """
                UPDATE reviews
                SET review_content = %s, rating = %s
                WHERE review_id = %s AND customer_id = %s
                """,
                (review_content, rating, review_id, customer_id),
            )
        conn.commit()
        
        return {"result": "OK", "review_id": review_id,
                "message": "리뷰가 수정되었습니다."}
        
    except Exception as e:
        return{'result' : 'Error'}
    finally:
            conn.close()
            



# 리뷰 삭제
@router.delete("/reviews_delete", tags=["리뷰 삭제"],summary="리뷰 삭제")
async def reviews_delete(review_id: int = Form(...)):
    conn = None
    try:
        conn = get_connection()
        curs = conn.cursor()
        curs.execute(
            "DELETE FROM reviews WHERE review_id = %s",
            (review_id,),
        )

        deleted_count = curs.rowcount
        conn.commit()
        conn.close()
        return {"result": "OK", "deleted_count": deleted_count}

    except Exception as e:
        return {"result": "리뷰가 삭제 되었습니다."}


            
