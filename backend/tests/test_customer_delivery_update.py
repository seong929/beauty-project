import unittest
from unittest.mock import MagicMock, patch

import pymysql
from fastapi import FastAPI
from fastapi.testclient import TestClient

from routers.customer import delivery


class DeliveryAddressTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        app = FastAPI()
        app.include_router(delivery.router)
        cls.client = TestClient(app)

    def setUp(self):
        self.conn = MagicMock()
        self.cursor = self.conn.cursor.return_value.__enter__.return_value
        self.cursor.fetchone.side_effect = [{"order_id": "ord_1", "order_status": "PAID"}, None]
        self.connection_patch = patch.object(delivery, "get_connection", return_value=self.conn)
        self.connection_patch.start()
        self.addCleanup(self.connection_patch.stop)

    def update(self, **overrides):
        return self.client.put("/customer_delivery_update", json={
            "customer_id": "cus_1", "order_id": "ord_1",
            "shipping_address": " (04524) 서울 중구 세종대로 110 101호 ", **overrides,
        })

    def test_paid_order_address_is_committed_without_changing_customer(self):
        response = self.update()
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["shipping_address"], "(04524) 서울 중구 세종대로 110 101호")
        queries = self.cursor.execute.call_args_list
        self.assertIn("FOR UPDATE", queries[0].args[0])
        self.assertEqual(queries[0].args[1], ("ord_1", "cus_1"))
        self.assertIn("UPDATE orders SET shipping_address", queries[-1].args[0])
        self.assertNotIn("UPDATE customers", " ".join(call.args[0] for call in queries))
        self.conn.commit.assert_called_once()
        self.conn.rollback.assert_not_called()
        self.conn.close.assert_called_once()

    def test_pending_and_preparing_orders_are_editable(self):
        for status in ("PENDING", "PREPARING"):
            with self.subTest(status=status):
                self.cursor.fetchone.side_effect = [{"order_status": status}, None]
                self.assertEqual(self.update().status_code, 200)

    def test_order_contact_and_request_are_saved_without_updating_customer_profile(self):
        response = self.update(shipping_recipient=' 새 수령인 ', shipping_phone='010-9876-5432', delivery_request='문 앞에 놓아주세요.')
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()['shipping_recipient'], '새 수령인')
        self.assertEqual(response.json()['shipping_phone'], '010-9876-5432')
        self.assertEqual(response.json()['delivery_request'], '문 앞에 놓아주세요.')
        self.assertEqual(self.cursor.execute.call_args.args[1][1:4], ('새 수령인', '010-9876-5432', '문 앞에 놓아주세요.'))
        self.assertFalse(any('UPDATE customers' in c.args[0] for c in self.cursor.execute.call_args_list))

    def test_another_customer_or_missing_order_is_not_updated(self):
        self.cursor.fetchone.side_effect = [None]
        self.assertEqual(self.update(customer_id="cus_other").status_code, 404)
        self.assertEqual(self.cursor.execute.call_count, 1)
        self.conn.commit.assert_not_called()
        self.conn.rollback.assert_called_once()

    def test_shipped_delivered_cancelled_returned_and_unknown_status_are_rejected(self):
        for status in ("SHIPPED", "DELIVERED", "CANCELLED", "RETURNED", "UNKNOWN"):
            with self.subTest(status=status):
                self.cursor.fetchone.side_effect = [{"order_status": status}]
                self.assertEqual(self.update().status_code, 409)
        self.conn.commit.assert_not_called()

    def test_registered_delivery_blocks_edit_even_when_order_status_is_stale(self):
        self.cursor.fetchone.side_effect = [{"order_status": "PAID"}, {"delivery_id": "dlv_ord_1_1"}]
        self.assertEqual(self.update().status_code, 409)
        self.assertEqual(self.cursor.execute.call_count, 2)
        self.conn.commit.assert_not_called()
        self.conn.rollback.assert_called_once()

    def test_same_address_is_success_even_if_mysql_reports_no_changed_rows(self):
        self.cursor.rowcount = 0
        self.assertEqual(self.update().status_code, 200)
        self.conn.commit.assert_called_once()

    def test_invalid_input_never_reaches_database(self):
        for change in ({"shipping_address": "   "}, {"shipping_address": "가" * 501},
                       {"customer_id": " "}, {"order_id": " "}, {"unexpected": True},
                       {'shipping_recipient': ' '}, {'shipping_phone': 'phone'},
                       {'shipping_phone': '0101'}, {'delivery_request': '가' * 201}):
            with self.subTest(change=change):
                self.assertEqual(self.update(**change).status_code, 422)
        delivery.get_connection.assert_not_called()

    def test_database_write_failure_rolls_back_and_hides_details(self):
        self.cursor.execute.side_effect = [None, None, pymysql.OperationalError(2006, "private")]
        response = self.update()
        self.assertEqual(response.status_code, 503)
        self.assertNotIn("private", response.text)
        self.conn.commit.assert_not_called()
        self.conn.rollback.assert_called_once()
        self.conn.close.assert_called_once()

    def test_connection_failure_is_a_service_error(self):
        with patch.object(delivery, "get_connection", side_effect=pymysql.OperationalError(2003, "private")):
            self.assertEqual(self.update().status_code, 503)


if __name__ == "__main__":
    unittest.main()
