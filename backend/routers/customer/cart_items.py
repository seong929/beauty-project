"""장바구니: 구매 수량·판매 옵션은 결제 화면에서 선택한다."""
from fastapi import APIRouter, Form, HTTPException, Query
import pymysql
from database import get_connection

router = APIRouter(tags=["고객 장바구니"])


@router.post("/incart_upload", summary="장바구니 상품 담기")
def incart_upload(
    customer_id: str = Form(..., min_length=1, max_length=64),
    cosmetic_id: str = Form(..., min_length=1, max_length=160),
):
    conn = get_connection()
    try:
        conn.begin()
        with conn.cursor() as cur:
            # 결제와 장바구니 수정이 서로 겹치지 않도록 동일 고객 행 잠금.
            cur.execute(
                "SELECT customer_id FROM customers WHERE customer_id=%s FOR UPDATE",
                (customer_id,),
            )
            if cur.fetchone() is None:
                raise HTTPException(404, "존재하지 않는 고객입니다.")
            cur.execute(
                "SELECT cosmetic_id FROM cosmetics WHERE cosmetic_id=%s",
                (cosmetic_id,),
            )
            if cur.fetchone() is None:
                raise HTTPException(404, "존재하지 않는 화장품입니다.")
            cur.execute(
                "INSERT INTO cart_items (customer_id, cosmetic_id) VALUES (%s, %s)",
                (customer_id, cosmetic_id),
            )
        conn.commit()
        return {"result": "OK", "message": "장바구니에 상품을 담았습니다."}
    except pymysql.err.IntegrityError:
        conn.rollback()
        raise HTTPException(409, "장바구니에 이미 등록된 상품이거나 참조 정보가 올바르지 않습니다.")
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


@router.get("/incart_select", summary="고객 장바구니 조회")
def incart_select(customer_id: str = Query(..., min_length=1, max_length=64)):
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute(
                """SELECT ci.customer_id, ci.cosmetic_id, c.cosmetic_name,
                          m.manufacturer_name, cat.category_name,
                          COALESCE((SELECT SUM(pi.stock_quantity)
                            FROM product_inventory AS pi
                           WHERE pi.cosmetic_id = ci.cosmetic_id
                             AND pi.inventory_status = 'MAINTAIN'
                             AND pi.sale_option = 'NORMAL'
                             AND (pi.expires_on IS NULL OR pi.expires_on >= CURRENT_DATE())), 0)
                            AS normal_quantity,
                          COALESCE((SELECT SUM(pi.stock_quantity)
                            FROM product_inventory AS pi
                           WHERE pi.cosmetic_id = ci.cosmetic_id
                             AND pi.inventory_status = 'MAINTAIN'
                             AND pi.sale_option = 'NEAR_EXPIRY'
                             AND (pi.expires_on IS NULL OR pi.expires_on >= CURRENT_DATE())), 0)
                            AS near_expiry_quantity
                     FROM cart_items AS ci
                     JOIN cosmetics AS c ON c.cosmetic_id = ci.cosmetic_id
                     JOIN manufacturers AS m ON m.manufacturer_id = c.manufacturer_id
                     JOIN categories AS cat ON cat.category_id = c.category_id
                    WHERE ci.customer_id = %s
                    ORDER BY c.cosmetic_name, ci.cosmetic_id""",
                (customer_id,),
            )
            return {"result": cur.fetchall(), "message": "장바구니 조회 성공"}
    finally:
        conn.close()


@router.delete("/incart_delete", summary="장바구니 상품 삭제")
def incart_delete(
    customer_id: str = Form(..., min_length=1, max_length=64),
    cosmetic_id: str = Form(..., min_length=1, max_length=160),
):
    conn = get_connection()
    try:
        conn.begin()
        with conn.cursor() as cur:
            cur.execute(
                "SELECT customer_id FROM customers WHERE customer_id=%s FOR UPDATE",
                (customer_id,),
            )
            if cur.fetchone() is None:
                raise HTTPException(404, "존재하지 않는 고객입니다.")
            cur.execute(
                "DELETE FROM cart_items WHERE customer_id=%s AND cosmetic_id=%s",
                (customer_id, cosmetic_id),
            )
            deleted = cur.rowcount
        conn.commit()
        return {"result": "OK", "deleted_count": deleted}
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()
