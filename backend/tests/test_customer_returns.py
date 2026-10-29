import datetime
import unittest
from unittest.mock import MagicMock, patch

import pymysql
from fastapi import FastAPI
from fastapi.testclient import TestClient

from routers.customer import return_api


class CustomerReturnTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        app = FastAPI()
        app.include_router(return_api.router)
        cls.client = TestClient(app)

    def setUp(self):
        self.conn = MagicMock()
        self.cursor = self.conn.cursor.return_value.__enter__.return_value
        self.cursor.fetchone.side_effect = [
            {"order_item_id": "ord_1_1", "purchase_quantity": 3, "order_status": "DELIVERED"},
            {"last_seq": 0, "requested_qty": 0},
            {"requested_on": datetime.date(2026, 10, 29)},
        ]
        self.connection_patch = patch.object(return_api, "get_connection", return_value=self.conn)
        self.connection_patch.start()
        self.addCleanup(self.connection_patch.stop)

    def submit(self, **overrides):
        return self.client.post("/return_requests", json={
            "customer_id": "cus_1", "order_item_id": "ord_1_1",
            "return_reason": " 파손\n용기가 깨졌습니다. ", "return_quantity": 1, **overrides,
        })

    def test_success_locks_owned_item_and_commits_only_a_requested_return(self):
        response = self.submit()
        self.assertEqual(response.status_code, 201)
        self.assertEqual(response.json(), {
            "customer_id": "cus_1", "return_id": "ret_ord_1_1_1", "order_item_id": "ord_1_1",
            "return_seq": 1, "return_reason": "파손\n용기가 깨졌습니다.", "return_quantity": 1,
            "requested_on": "2026-10-29", "return_status": "REQUESTED",
            "refund_status": "PENDING", "pickup_status": "WAITING",
        })
        sql, params = self.cursor.execute.call_args_list[0].args
        self.assertIn("o.customer_id = %s", sql)
        self.assertIn("FOR UPDATE", sql)
        self.assertEqual(params, ("ord_1_1", "cus_1"))
        self.conn.commit.assert_called_once()
        self.conn.close.assert_called_once()

    def test_missing_or_other_customers_item_is_not_written(self):
        self.cursor.fetchone.side_effect = [None]
        self.assertEqual(self.submit(customer_id="cus_other").status_code, 404)
        self.assertEqual(self.cursor.execute.call_count, 1)
        self.conn.commit.assert_not_called()
        self.conn.rollback.assert_called_once()

    def test_unshipped_item_is_rejected(self):
        self.cursor.fetchone.side_effect = [{"purchase_quantity": 3, "order_status": "PAID"}]
        self.assertEqual(self.submit().status_code, 409)
        self.conn.commit.assert_not_called()

    def test_already_requested_quantity_is_subtracted(self):
        self.cursor.fetchone.side_effect = [
            {"purchase_quantity": 3, "order_status": "DELIVERED"},
            {"last_seq": 1, "requested_qty": 2},
        ]
        response = self.submit(return_quantity=2)
        self.assertEqual(response.status_code, 409)
        self.assertIn("남은 수량: 1", response.json()["detail"])
        self.conn.commit.assert_not_called()

    def test_partial_return_gets_the_next_sequence(self):
        self.cursor.fetchone.side_effect = [
            {"purchase_quantity": 3, "order_status": "SHIPPED"},
            {"last_seq": 2, "requested_qty": 2},
            {"requested_on": datetime.date(2026, 10, 29)},
        ]
        response = self.submit()
        self.assertEqual(response.status_code, 201)
        self.assertEqual(response.json()["return_id"], "ret_ord_1_1_3")

    def test_input_validation_happens_before_database_access(self):
        for override in ({"customer_id": " "}, {"return_reason": " "},
                         {"return_reason": "가" * 501}, {"return_quantity": 0}, {"extra": "x"}):
            with self.subTest(override=override):
                self.assertEqual(self.submit(**override).status_code, 422)
        return_api.get_connection.assert_not_called()

    def test_write_failure_rolls_back_and_never_reports_success(self):
        self.cursor.execute.side_effect = pymysql.OperationalError(2006, "private database detail")
        with self.assertLogs(return_api.logger, level="ERROR"):
            response = self.submit()
        self.assertEqual(response.status_code, 500)
        self.assertNotIn("private database detail", response.text)
        self.conn.rollback.assert_called_once()
        self.conn.commit.assert_not_called()
        self.conn.close.assert_called_once()

    def test_customer_list_is_parameterized_and_never_queries_admins_list(self):
        row = {"return_id": "ret_ord_1_1_1", "customer_id": "cus_1"}
        self.cursor.fetchall.return_value = [row]
        response = self.client.get("/return_requests", params={"customer_id": "cus_1", "order_item_id": "ord_1_1"})
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json(), {"result": [row]})
        sql, params = self.cursor.execute.call_args.args
        self.assertIn("WHERE o.customer_id = %s", sql)
        self.assertIn("AND rr.order_item_id = %s", sql)
        self.assertEqual(params, ("cus_1", "ord_1_1"))
        self.conn.commit.assert_not_called()
        self.conn.close.assert_called_once()

    def test_empty_list_and_list_database_error(self):
        self.cursor.fetchall.return_value = []
        self.assertEqual(self.client.get("/return_requests?customer_id=cus_1").json(), {"result": []})
        self.cursor.execute.side_effect = pymysql.OperationalError(2006, "private")
        response = self.client.get("/return_requests?customer_id=cus_1")
        self.assertEqual(response.status_code, 503)
        self.assertNotIn("private", response.text)

    def test_main_registers_both_customer_return_methods(self):
        from main import app
        paths = app.openapi()["paths"]
        self.assertIn("get", paths["/return_requests"])
        self.assertIn("post", paths["/return_requests"])


if __name__ == "__main__":
    unittest.main()
