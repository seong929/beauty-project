"""실제 DB의 배송 정보 저장을 확인하고 생성한 주문·포인트·재고 변경은 모두 롤백한다."""
import os
import unittest
from unittest.mock import patch

from fastapi import HTTPException
from database import get_connection
from routers.customer import delivery, order


@unittest.skipUnless(os.getenv('RUN_CUSTOMER_SHIPPING_MYSQL') == '1', 'explicit MySQL verification only')
class CustomerShippingMySQLTests(unittest.TestCase):
    def test_checkout_and_pre_dispatch_edit_keep_customer_profile_unchanged(self):
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
                cursor.execute('SELECT customer_id FROM customers ORDER BY customer_id')
                buyer = next((row for row in cursor.fetchall() if order.get_account_status(cursor, row['customer_id']) == 'ACTIVE'), None)
                cursor.execute("SELECT cosmetic_id FROM cosmetics WHERE manufacturer_id='mfr_sodam_demo' ORDER BY cosmetic_id LIMIT 1")
                product = cursor.fetchone()
                if buyer is None or product is None:
                    self.skipTest('active customer and seed product required')
                cursor.execute('SELECT customer_name,phone,address FROM customers WHERE customer_id=%s', (buyer['customer_id'],))
                original_profile = cursor.fetchone()
            transaction = Transaction()
            with patch.object(order, 'get_connection', return_value=transaction), patch.object(delivery, 'get_connection', return_value=transaction):
                receipt = order.checkout_cart(order.CheckoutRequest(
                    customer_id=buyer['customer_id'], shipping_address='서울시 검증 주소 101호',
                    shipping_recipient='결제 수령인', shipping_phone='01077778888', delivery_request='문 앞에 놓아주세요.',
                    items=[order.CheckoutItem(cosmetic_id=product['cosmetic_id'], quantity=1, sale_option=order.SaleOption.NORMAL)],
                ))
                self.assertEqual(receipt['shipping_recipient'], '결제 수령인')
                changed = delivery.customer_delivery_update(delivery.ShippingAddressUpdate(
                    customer_id=buyer['customer_id'], order_id=receipt['order_id'], shipping_address='부산시 새 주소 202호',
                    shipping_recipient='변경 수령인', shipping_phone='01099998888', delivery_request='배송 전에 연락해 주세요.',
                ))
                self.assertEqual(changed['shipping_recipient'], '변경 수령인')
                with conn.cursor() as cursor:
                    cursor.execute('SELECT shipping_address,shipping_recipient,shipping_phone,delivery_request FROM orders WHERE order_id=%s', (receipt['order_id'],))
                    stored = cursor.fetchone()
                    self.assertEqual(stored, {'shipping_address': '부산시 새 주소 202호', 'shipping_recipient': '변경 수령인', 'shipping_phone': '01099998888', 'delivery_request': '배송 전에 연락해 주세요.'})
                    cursor.execute('SELECT customer_name,phone,address FROM customers WHERE customer_id=%s', (buyer['customer_id'],))
                    self.assertEqual(cursor.fetchone(), original_profile)
                    cursor.execute("UPDATE orders SET order_status='SHIPPED' WHERE order_id=%s", (receipt['order_id'],))
                with self.assertRaises(HTTPException) as error:
                    delivery.customer_delivery_update(delivery.ShippingAddressUpdate(
                        customer_id=buyer['customer_id'], order_id=receipt['order_id'], shipping_address='변경되면 안 되는 주소',
                    ))
                self.assertEqual(error.exception.status_code, 409)
                with conn.cursor() as cursor:
                    cursor.execute('SELECT shipping_address FROM orders WHERE order_id=%s', (receipt['order_id'],))
                    self.assertEqual(cursor.fetchone()['shipping_address'], stored['shipping_address'])
        finally:
            conn.rollback()
            conn.close()


if __name__ == '__main__':
    unittest.main()
