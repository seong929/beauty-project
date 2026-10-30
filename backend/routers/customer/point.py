import pymysql
from fastapi import APIRouter, HTTPException, Query
from database import get_connection

router = APIRouter(tags=['고객 포인트'])


@router.get('/customer_points', summary='고객 포인트 잔액과 적립·사용·취소 내역')
def customer_points(customer_id: str = Query(..., min_length=1, max_length=64)):
    conn = None
    try:
        conn = get_connection()
        conn.begin()
        with conn.cursor() as cursor:
            cursor.execute('SELECT points_balance FROM customers WHERE customer_id=%s', (customer_id,))
            customer = cursor.fetchone()
            if customer is None:
                raise HTTPException(404, '존재하지 않는 고객입니다.')
            cursor.execute('''SELECT point_id, order_id, event_type, points_delta, balance_after, created_at
                FROM customer_point_history WHERE customer_id=%s ORDER BY created_at DESC, point_id DESC''', (customer_id,))
            return {'customer_id': customer_id, 'balance': customer['points_balance'], 'history': cursor.fetchall()}
    except pymysql.MySQLError:
        raise HTTPException(503, '포인트 정보를 불러올 수 없습니다. 잠시 후 다시 시도해 주세요.') from None
    finally:
        if conn is not None:
            conn.rollback()
            conn.close()
