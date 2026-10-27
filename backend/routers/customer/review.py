from typing import Annotated
from fastapi import APIRouter, Form, HTTPException, Query
from pydantic import StringConstraints
import pymysql

from database import get_connection
from services.customer.customer_service import next_sequence

router = APIRouter(tags=["리뷰"])


# 리뷰 등록
@router.post("/reviews_upload", tags=["리뷰 등록"], summary="리뷰 등록")
def reviews_upload(
    customer_id: Annotated[
        str,
        StringConstraints(strip_whitespace=True, min_length=1),
        Form(),
    ],
    cosmetic_id: Annotated[
        str,
        StringConstraints(strip_whitespace=True, min_length=1),
        Form(),
    ],
    review_content: Annotated[
        str,
        StringConstraints(
            strip_whitespace=True,
            min_length=1,
            max_length=21845,
        ),
        Form(),
    ],
    rating: int = Form(..., ge=1, le=5),
):
    conn = None

    try:
        conn = get_connection()
        conn.begin()

        with conn.cursor() as curs:
            # 1. 고객 존재 여부 확인
            curs.execute(
                """
                SELECT customer_id
                FROM customers
                WHERE customer_id = %s
                """,
                (customer_id,),
            )

            customer = curs.fetchone()

            if customer is None:
                raise HTTPException(
                    status_code=404,
                    detail="존재하지 않는 고객입니다.",
                )

            # 2. 화장품 존재 여부 확인
            curs.execute(
                """
                SELECT cosmetic_id
                FROM cosmetics
                WHERE cosmetic_id = %s
                """,
                (cosmetic_id,),
            )

            cosmetic = curs.fetchone()

            if cosmetic is None:
                raise HTTPException(
                    status_code=404,
                    detail="존재하지 않는 화장품입니다.",
                )

            # 3. 리뷰 ID 생성
            review_id = f"rev_{next_sequence(curs, 'review')}"

            # 4. 리뷰 등록
            curs.execute(
                """
                INSERT INTO reviews (
                    review_id,
                    customer_id,
                    cosmetic_id,
                    review_content,
                    rating
                )
                VALUES (%s, %s, %s, %s, %s)
                """,
                (
                    review_id,
                    customer_id,
                    cosmetic_id,
                    review_content,
                    rating,
                ),
            )

        conn.commit()

        return {
            "result": "OK",
            "review_id": review_id,
            "customer_id": customer_id,
            "message": "리뷰가 등록되었습니다.",
        }

    except HTTPException:
        if conn:
            conn.rollback()
        raise

    except pymysql.IntegrityError as e:
        if conn:
            conn.rollback()

        if e.args and e.args[0] == 1062:
            raise HTTPException(
                status_code=409,
                detail="이미 등록된 리뷰입니다.",
            )

        if e.args and e.args[0] == 1452:
            raise HTTPException(
                status_code=404,
                detail="고객 또는 화장품 정보가 존재하지 않습니다.",
            )

        raise HTTPException(
            status_code=400,
            detail="리뷰 등록 조건을 충족하지 않습니다.",
        )

    except Exception:
        if conn:
            conn.rollback()

        raise HTTPException(
            status_code=500,
            detail="리뷰 등록 중 오류가 발생했습니다.",
        )

    finally:
        if conn:
            conn.close()




# 리뷰 조회
@router.get("/reviews_select", tags=["리뷰 조회"], summary="리뷰 조회")
def reviews_select(
    review_id: str | None = Query(None),
    customer_id: str | None = Query(None),
    cosmetic_id: str | None = Query(None),
):
    conn = None

    try:
        conn = get_connection()

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
    except pymysql.MySQLError:
        raise HTTPException(
            status_code=500,
            detail="리뷰 조회 중 데이터베이스 오류가 발생했습니다.",
        )

    except Exception:
        raise HTTPException(
            status_code=500,
            detail="리뷰 조회 중 오류가 발생했습니다.",
        )

    finally:
        if conn:
            conn.close()


# 리뷰 수정
@router.put("/reviews_update", tags=["리뷰 수정"], summary="리뷰 수정")
def reviews_update(
    review_content: Annotated[
        str,
        StringConstraints(
            strip_whitespace=True,
            min_length=1,
            max_length=21845,
        ),
        Form(),
    ],
    review_id: str = Query(...,),
    customer_id: str = Query(...,),
    rating: int = Form(..., ge=1, le=5),
):
    conn = None
    try:
        conn = get_connection()
        conn.begin()
        with conn.cursor() as curs:
            curs.execute(
                "SELECT customer_id FROM reviews WHERE review_id = %s FOR UPDATE",
                (review_id,),
            )
            review = curs.fetchone()
            if review is None:
                raise HTTPException(
                    status_code=404,
                    detail="존재하지 않는 리뷰입니다.",
                )

            # DictCursor / 일반 Cursor 모두 대응
            writer_id = (
                review["customer_id"]
                if isinstance(review, dict)
                else review[0]
            )

            if writer_id != customer_id:
                raise HTTPException(
                    status_code=403,
                    detail="본인이 작성한 리뷰만 수정할 수 있습니다.",
                )

            # 리뷰 수정
            curs.execute(
                """
                UPDATE reviews
                SET review_content = %s,
                    rating = %s
                WHERE review_id = %s
                  AND customer_id = %s
                """,
                (
                    review_content,
                    rating,
                    review_id,
                    customer_id,
                ),
            )

        conn.commit()

        return {
            "result": "OK",
            "review_id": review_id,
            "message": "리뷰가 수정되었습니다.",
        }

    except HTTPException:
        if conn:
            conn.rollback()
        raise

    except Exception:
        if conn:
            conn.rollback()
        raise HTTPException(
            status_code=500,
            detail="리뷰 수정 중 오류가 발생했습니다.",
        )

    finally:
        if conn:
            conn.close()
            



# 리뷰 삭제
@router.delete("/reviews_delete", tags=["리뷰 삭제"], summary="리뷰 삭제")
def reviews_delete(
    review_id: Annotated[
        str,
        StringConstraints(
            strip_whitespace=True,
            pattern=r"^rev_[1-9][0-9]*$",
        ),
        Form(),
    ],
    customer_id: Annotated[
        str,
        StringConstraints(
            strip_whitespace=True,
            min_length=1,
        ),
        Form(),
    ],
):
    conn = None

    try:
        conn = get_connection()
        conn.begin()

        with conn.cursor() as curs:
            curs.execute(
                """
                SELECT customer_id
                FROM reviews
                WHERE review_id = %s
                FOR UPDATE
                """,
                (review_id,),
            )

            review = curs.fetchone()

            if review is None:
                raise HTTPException(
                    status_code=404,
                    detail="존재하지 않는 리뷰입니다.",
                )

            writer_id = (
                review["customer_id"]
                if isinstance(review, dict)
                else review[0]
            )

            if writer_id != customer_id:
                raise HTTPException(
                    status_code=403,
                    detail="본인이 작성한 리뷰만 삭제할 수 있습니다.",
                )

            curs.execute(
                """
                DELETE FROM reviews
                WHERE review_id = %s
                  AND customer_id = %s
                """,
                (review_id, customer_id),
            )

            deleted_count = curs.rowcount

        conn.commit()

        return {
            "result": "OK",
            "deleted_count": deleted_count,
            "message": "리뷰가 삭제되었습니다.",
        }

    except HTTPException:
        if conn:
            conn.rollback()
        raise

    except Exception:
        if conn:
            conn.rollback()
        raise HTTPException(
            status_code=500,
            detail="리뷰 삭제 중 오류가 발생했습니다.",
        )

    finally:
        if conn:
            conn.close()