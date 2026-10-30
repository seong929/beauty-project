from fastapi import HTTPException
from database import get_connection


def get_return_pickups(carrier_id: str):
    conn = get_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                SELECT rr.return_id, oi.order_id, rr.order_item_id,
                       o.shipping_address, rr.return_reason, rr.return_quantity,
                       rr.return_status, rr.pickup_status, rr.requested_on,
                       rr.pickup_requested_on, rr.pickup_completed_on
                FROM return_pickups rp
                JOIN return_requests rr ON rr.return_id = rp.return_id
                JOIN order_items oi ON oi.order_item_id = rr.order_item_id
                JOIN orders o ON o.order_id = oi.order_id
                WHERE rp.carrier_id = %s
                  AND rr.return_status IN ('COLLECTING', 'INSPECTING', 'COMPLETED')
                ORDER BY rr.pickup_requested_on DESC, rr.return_id DESC
            """, (carrier_id,))
            return cursor.fetchall()
    finally:
        conn.close()


def complete_return_pickup(return_id: str, carrier_id: str):
    conn = get_connection()
    try:
        conn.begin()
        with conn.cursor() as cursor:
            cursor.execute("""
                SELECT rr.return_status, rr.pickup_status
                FROM return_requests rr
                JOIN return_pickups rp ON rp.return_id = rr.return_id
                WHERE rr.return_id = %s AND rp.carrier_id = %s
                FOR UPDATE
            """, (return_id, carrier_id))
            row = cursor.fetchone()
            if row is None:
                raise HTTPException(404, '배정된 반품 수거 정보를 찾을 수 없습니다.')
            if row['return_status'] != 'COLLECTING' or row['pickup_status'] != 'SCHEDULED':
                raise HTTPException(409, '회수 요청 상태인 반품만 수거 완료할 수 있습니다.')
            cursor.execute("""
                UPDATE return_requests
                SET pickup_status = 'COLLECTED', pickup_completed_on = CURDATE()
                WHERE return_id = %s
                  AND return_status = 'COLLECTING' AND pickup_status = 'SCHEDULED'
            """, (return_id,))
            if cursor.rowcount != 1:
                raise HTTPException(409, '수거 상태가 변경되었습니다. 새로고침해 주세요.')
        conn.commit()
        return {'return_id': return_id, 'pickup_status': 'COLLECTED',
                'message': '수거 완료 처리되었습니다.'}
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()
