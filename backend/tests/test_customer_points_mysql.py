"""실제 스키마에서 결제·회수를 검증하되 모든 변경을 마지막에 롤백한다."""
import os
import unittest
from unittest.mock import patch

from database import get_connection
from routers.customer import order, order_item


@unittest.skipUnless(os.getenv('RUN_CUSTOMER_POINTS_MYSQL') == '1', 'explicit MySQL verification only')
class CustomerPointsMySQLTests(unittest.TestCase):
    def test_used_points_are_restored_once_and_full_point_payment_earns_zero(self):
        conn = get_connection()
        class Transaction:
            def begin(self): pass
            def commit(self): pass
            def rollback(self): pass
            def close(self): pass
            def __getattr__(self, name): return getattr(conn, name)
        try:
            conn.begin()
            with conn.cursor() as cursor:
                cursor.execute('SELECT customer_id, points_balance FROM customers ORDER BY customer_id')
                buyer = next((row for row in cursor.fetchall() if order.get_account_status(cursor, row['customer_id']) == 'ACTIVE'), None)
                cursor.execute("SELECT cosmetic_id FROM cosmetics WHERE manufacturer_id='mfr_sodam_demo' ORDER BY cosmetic_id LIMIT 1")
                product = cursor.fetchone()
                if buyer is None or product is None:
                    self.skipTest('customer and Firebase seed product required')
                # Test-only balance change remains inside the final rollback.
                cursor.execute('UPDATE customers SET points_balance=1000000 WHERE customer_id=%s', (buyer['customer_id'],))
                cursor.execute('SELECT inventory_id, stock_quantity FROM product_inventory WHERE cosmetic_id=%s ORDER BY inventory_id', (product['cosmetic_id'],))
                original_stock = cursor.fetchall()
            transaction = Transaction()
            with patch.object(order, 'get_connection', return_value=transaction), patch.object(order_item, 'get_connection', return_value=transaction):
                for used in (100, None):
                    request = order.CheckoutRequest(customer_id=buyer['customer_id'], shipping_address='검증용 임시 주소',
                        points_to_use=used or 0,
                        items=[order.CheckoutItem(cosmetic_id=product['cosmetic_id'], quantity=1, sale_option=order.SaleOption.NORMAL)])
                    if used is None:
                        with conn.cursor() as cursor:
                            cursor.execute('SELECT sale_price FROM cosmetic_price_history WHERE cosmetic_id=%s ORDER BY changed_on DESC, CAST(SUBSTRING_INDEX(change_id, \'_\', -1) AS UNSIGNED) DESC LIMIT 1', (product['cosmetic_id'],))
                            request.points_to_use = int(cursor.fetchone()['sale_price'])
                    paid = order.checkout_cart(request)
                    self.assertEqual(paid['payment_amount'], paid['total_amount'] - request.points_to_use)
                    self.assertEqual(paid['earned_points'], int(paid['payment_amount'] // 10))
                    self.assertEqual(paid['points_balance'], 1000000 - request.points_to_use + paid['earned_points'])
                    with conn.cursor() as cursor:
                        cursor.execute('SELECT used_points FROM orders WHERE order_id=%s', (paid['order_id'],))
                        self.assertEqual(cursor.fetchone()['used_points'], request.points_to_use)
                    cancelled = order_item.cancel_paid_order(buyer['customer_id'], paid['order_id'])
                    self.assertEqual(cancelled['restored_points'], request.points_to_use)
                    from fastapi import HTTPException
                    with self.assertRaises(HTTPException) as error:
                        order_item.cancel_paid_order(buyer['customer_id'], paid['order_id'])
                    self.assertEqual(error.exception.status_code, 409)
                    with conn.cursor() as cursor:
                        cursor.execute('SELECT points_balance FROM customers WHERE customer_id=%s', (buyer['customer_id'],))
                        self.assertEqual(cursor.fetchone()['points_balance'], 1000000)
                        cursor.execute('SELECT event_type, points_delta FROM customer_point_history WHERE order_id=%s', (paid['order_id'],))
                        entries = cursor.fetchall()
                        self.assertEqual(sum(row['points_delta'] for row in entries), 0)
                        self.assertEqual(len([row for row in entries if row['event_type'] == 'RESTORE']), 1)
                        cursor.execute('SELECT inventory_id, stock_quantity FROM product_inventory WHERE cosmetic_id=%s ORDER BY inventory_id', (product['cosmetic_id'],))
                        self.assertEqual(cursor.fetchall(), original_stock)
        finally:
            conn.rollback()
            conn.close()

    def test_payment_awards_ten_percent_and_cancel_recovers_it_without_leaving_test_data(self):
        conn = get_connection()
        class Transaction:
            def begin(self): pass
            def commit(self): pass
            def close(self): pass
            def __getattr__(self, name): return getattr(conn, name)
        try:
            conn.begin()
            with conn.cursor() as cursor:
                cursor.execute('SELECT customer_id, points_balance FROM customers ORDER BY customer_id')
                buyer = next((row for row in cursor.fetchall() if order.get_account_status(cursor, row['customer_id']) == 'ACTIVE'), None)
                cursor.execute("SELECT cosmetic_id FROM cosmetics WHERE manufacturer_id='mfr_sodam_demo' ORDER BY cosmetic_id LIMIT 1")
                product = cursor.fetchone()
                if buyer is None or product is None:
                    self.skipTest('customer and Firebase seed product required')
            transaction = Transaction()
            request = order.CheckoutRequest(customer_id=buyer['customer_id'], shipping_address='포인트 검증용 임시 주소',
                items=[order.CheckoutItem(cosmetic_id=product['cosmetic_id'], quantity=1, sale_option=order.SaleOption.NORMAL)])
            with patch.object(order, 'get_connection', return_value=transaction), patch.object(order_item, 'get_connection', return_value=transaction):
                paid = order.checkout_cart(request)
                self.assertEqual(paid['earned_points'], int(paid['total_amount'] // 10))
                self.assertEqual(paid['points_balance'], buyer['points_balance'] + paid['earned_points'])
                cancelled = order_item.cancel_paid_order(buyer['customer_id'], paid['order_id'])
                self.assertEqual(cancelled['recovered_points'], paid['earned_points'])
            with conn.cursor() as cursor:
                cursor.execute('SELECT points_balance FROM customers WHERE customer_id=%s', (buyer['customer_id'],))
                self.assertEqual(cursor.fetchone()['points_balance'], buyer['points_balance'])
                cursor.execute('SELECT points_delta FROM customer_point_history WHERE order_id=%s', (paid['order_id'],))
                entries = cursor.fetchall()
                self.assertEqual(len(entries), 2)
                self.assertEqual(sum(row['points_delta'] for row in entries), 0)
            # No artificial purchase, credit, cancellation or inventory change is committed.
        finally:
            conn.rollback()
            conn.close()


if __name__ == '__main__':
    unittest.main()
