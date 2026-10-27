from fastapi import APIRouter, Form, HTTPException, Query
import pymysql

from database import get_connection

router = APIRouter(tags=["고객 장바구니"])


# 장바구니 담기 (한 제품만 담을수 있음)
@router.post("/incart_upload", summary="장바구니 상품 담기")
def incart_upload(
    customer_id: str = Form(..., min_length=1, max_length=60,),
    cosmetic_id: str = Form(..., min_length=1, max_length=160,),
):
    conn = None
    try:
        conn = get_connection()
        conn.begin()
        with conn.cursor() as curs:
            curs.execute(
                "SELECT customer_id FROM customers WHERE customer_id = %s",
                (customer_id,),
            )
            curs.execute(
                """
                INSERT INTO cart_items (customer_id, cosmetic_id)
                VALUES (%s, %s)
                """,
                (customer_id, cosmetic_id),
            )
        conn.commit()
        return {
            "result": "OK",
            "message": "장바구니에 상품을 담았습니다.",
        }
    except Exception:
        if conn is not None:
            conn.rollback()
        raise
    finally:
        if conn is not None:
            conn.close()


# 고객별 장바구니 조회
@router.get("/incart_select", summary="고객 장바구니 조회")
def incart_select(
    customer_id: str = Query(..., min_length=1, max_length=60,),
):
    conn = get_connection()
    try:
        with conn.cursor() as curs:
            curs.execute(
                """
                SELECT ci.customer_id,
                    ci.cosmetic_id,
                    c.cosmetic_name,
                    m.manufacturer_name,
                    cat.category_name
                FROM cart_items AS ci
                JOIN cosmetics AS c ON c.cosmetic_id = ci.cosmetic_id
                JOIN manufacturers AS m ON m.manufacturer_id = c.manufacturer_id
                JOIN categories AS cat ON cat.category_id = c.category_id
                WHERE ci.customer_id = %s
                ORDER BY c.cosmetic_name, c.cosmetic_id
                """,
                (customer_id,),
            )
            rows = curs.fetchall()
        return {"result": rows,
                "message": "장바구니 조회 성공" }
    finally:
        conn.close()


# 장바구니에서 선택한 상품 삭제
@router.delete("/incart_delete", summary="장바구니 상품 삭제")
def incart_delete(
    customer_id: str = Form(..., min_length=1, max_length=60,),
    cosmetic_id: str = Form(..., min_length=1, max_length=100,),
):
    conn = None
    try:
        conn = get_connection()
        conn.begin()
        with conn.cursor() as curs:
            curs.execute(
                """
                DELETE FROM cart_items
                WHERE customer_id = %s AND cosmetic_id = %s
                """,
                (customer_id, cosmetic_id),
            )
            deleted_count = curs.rowcount
        conn.commit()
        return {"result": "OK",
                "message": deleted_count}
    except Exception:
        if conn is not None:
            conn.rollback()
        raise
    finally:
        if conn is not None:
            conn.close()
