import unittest
from decimal import Decimal
from unittest.mock import MagicMock, patch

import pymysql
from fastapi import FastAPI
from fastapi.testclient import TestClient
from routers.customer import order, point
from services.customer.point_service import purchase_points


class CustomerPointTests(unittest.TestCase):
    def setUp(self):
        app = FastAPI()
        app.include_router(order.router)
        app.include_router(point.router)
        self.client = TestClient(app)
        self.conn = MagicMock()
        self.cursor = self.conn.cursor.return_value.__enter__.return_value
        self.cursor.rowcount = 1
        self.patch = patch.object(order, 'get_connection', return_value=self.conn)
        self.patch.start()
        self.addCleanup(self.patch.stop)

    def prepare_payment(self, balance=100):
        self.cursor.fetchone.side_effect = [
            {'customer_id': 'c1', 'points_balance': balance}, {'account_status': 'ACTIVE'},
            {'cosmetic_name': '로션', 'sale_status': 'ON_SALE', 'sale_price': Decimal('99.99')}, {'seq': 42},
        ]
        self.cursor.fetchall.side_effect = [[], [
            {'inventory_id': 'inv1', 'stock_quantity': 1},
            {'inventory_id': 'inv2', 'stock_quantity': 1},
        ]]

    def pay(self, **shipping):
        return self.client.post('/orders_pay', json={'customer_id': 'c1', 'shipping_address': '서울시',
            'items': [{'cosmetic_id': 'sku1', 'quantity': 2, 'sale_option': 'NORMAL'}], **shipping})

    def test_checkout_stores_selected_shipping_contact_and_request_on_the_order(self):
        self.prepare_payment()
        response = self.pay(shipping_recipient='받는 사람', shipping_phone='01088887777', delivery_request='문 앞에 놓아주세요.')
        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertEqual(body['shipping_recipient'], '받는 사람')
        self.assertEqual(body['shipping_phone'], '01088887777')
        inserts = [c for c in self.cursor.execute.call_args_list if 'INSERT INTO orders' in c.args[0]]
        self.assertEqual(inserts[0].args[1][-4:-1], ('받는 사람', '01088887777', '문 앞에 놓아주세요.'))

    def test_decimal_points_round_down_and_batch_allocation_keeps_order_total(self):
        self.assertEqual(purchase_points(Decimal('23900')), 2390)
        self.assertEqual(purchase_points(Decimal('99.99')), 9)
        self.prepare_payment()
        response = self.pay()
        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertEqual(body['earned_points'], 19)
        self.assertEqual(body['points_balance'], 119)
        self.assertEqual([i['earned_points'] for i in body['items']], [9, 10])
        self.assertEqual(sum(i['quantity'] for i in body['items']), 2)
        ledger = [c for c in self.cursor.execute.call_args_list if 'INSERT INTO customer_point_history' in c.args[0]]
        self.assertEqual(len(ledger), 1)
        self.assertEqual(ledger[0].args[1], ('pt_ord_42_earn', 'ord_42', 'EARN', 19, 'c1'))
        self.conn.commit.assert_called_once()

    def test_ledger_failure_rolls_back_balance_stock_and_order_together(self):
        self.prepare_payment()
        def execute(sql, params=None):
            if 'INSERT INTO customer_point_history' in sql:
                raise pymysql.OperationalError(2013, 'private details')
        self.cursor.execute.side_effect = execute
        response = self.pay()
        self.assertEqual(response.status_code, 500)
        self.conn.rollback.assert_called_once()
        self.conn.commit.assert_not_called()
        self.assertNotIn('private details', response.text)

    def test_points_discount_net_payment_and_net_earning_are_saved_together(self):
        self.prepare_payment()
        response = self.pay(points_to_use=80)
        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertEqual(Decimal(str(body['payment_amount'])), Decimal('119.98'))
        self.assertEqual(body['used_points'], 80)
        self.assertEqual(body['earned_points'], 11)
        self.assertEqual(body['points_balance'], 31)
        self.assertEqual(sum(i['earned_points'] for i in body['items']), 11)
        ledger = [c.args[1] for c in self.cursor.execute.call_args_list if 'INSERT INTO customer_point_history' in c.args[0]]
        self.assertEqual([entry[2:4] for entry in ledger], [('USE', -80), ('EARN', 11)])
        self.conn.commit.assert_called_once()

    def test_insufficient_balance_rejects_without_consuming_future_earnings(self):
        self.prepare_payment()
        response = self.pay(points_to_use=101)
        self.assertEqual(response.status_code, 409)
        self.conn.rollback.assert_called_once()
        self.conn.commit.assert_not_called()
        self.assertFalse(any('INSERT INTO orders' in c.args[0] for c in self.cursor.execute.call_args_list))

    def test_points_cannot_exceed_server_product_total(self):
        self.prepare_payment(balance=1000)
        self.assertEqual(self.pay(points_to_use=200).status_code, 409)
        self.conn.commit.assert_not_called()

    def test_points_require_a_nonnegative_integer(self):
        for value in (-1, 1.5, True, '10', 4294967296):
            with self.subTest(value=value):
                self.assertEqual(self.pay(points_to_use=value).status_code, 422)

    def test_use_history_failure_also_rolls_back_stock_and_order(self):
        self.prepare_payment()
        def execute(sql, params=None):
            if 'INSERT INTO customer_point_history' in sql and params[2] == 'USE':
                raise pymysql.OperationalError(2013, 'private details')
        self.cursor.execute.side_effect = execute
        self.assertEqual(self.pay(points_to_use=80).status_code, 500)
        self.conn.rollback.assert_called_once()
        self.conn.commit.assert_not_called()

    def test_point_history_is_scoped_to_requested_customer(self):
        self.cursor.fetchone.side_effect = [{'points_balance': 119}]
        self.cursor.fetchall.side_effect = [[{'point_id': 'pt_ord_42_earn', 'order_id': 'ord_42',
            'event_type': 'EARN', 'points_delta': 19, 'balance_after': 119, 'created_at': '2026-10-30 12:00:00'}]]
        with patch.object(point, 'get_connection', return_value=self.conn):
            response = self.client.get('/customer_points', params={'customer_id': 'c1'})
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()['balance'], 119)
        self.assertTrue(all(c.args[1] == ('c1',) for c in self.cursor.execute.call_args_list))
        self.conn.commit.assert_not_called()


if __name__ == '__main__':
    unittest.main()
