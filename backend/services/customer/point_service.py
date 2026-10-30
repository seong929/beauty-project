from decimal import Decimal, ROUND_FLOOR

from fastapi import HTTPException

MAX_POINTS = 4294967295


def purchase_points(amount):
    return int((Decimal(str(amount)) * Decimal('0.10')).to_integral_value(rounding=ROUND_FLOOR))


def change_points(cursor, customer_id, order_id, delta, event=None):
    """호출자의 결제/취소 트랜잭션 안에서 잔액과 중복 불가능한 내역을 함께 기록한다."""
    if delta == 0:
        return
    event = event or ('EARN' if delta > 0 else 'CANCEL')
    if event not in ('EARN', 'CANCEL', 'USE', 'RESTORE') or (
        (delta > 0) != (event in ('EARN', 'RESTORE'))
    ):
        raise ValueError('포인트 처리 유형과 금액이 일치하지 않습니다.')
    if delta > 0:
        cursor.execute('UPDATE customers SET points_balance=points_balance+%s WHERE customer_id=%s AND points_balance<=%s',
                       (delta, customer_id, MAX_POINTS - delta))
    else:
        cursor.execute('UPDATE customers SET points_balance=points_balance-%s WHERE customer_id=%s AND points_balance>=%s',
                       (-delta, customer_id, -delta))
    if cursor.rowcount != 1:
        raise HTTPException(409, '포인트 잔액을 확인할 수 없어 주문 처리를 완료하지 못했습니다.')
    cursor.execute('''INSERT INTO customer_point_history
        (point_id, customer_id, order_id, event_type, points_delta, balance_after)
        SELECT %s, customer_id, %s, %s, %s, points_balance FROM customers WHERE customer_id=%s''',
        (f'pt_{order_id}_{event.lower()}', order_id, event, delta, customer_id))


# Function: 사용·적립·취소 복원은 호출자의 주문 트랜잭션에 포함한다. 적립은 포인트 차감 후 결제 금액의 10%이다.
