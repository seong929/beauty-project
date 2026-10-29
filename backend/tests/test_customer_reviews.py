import unittest
from unittest.mock import MagicMock, patch

import pymysql
from fastapi import FastAPI
from fastapi.testclient import TestClient

from routers.customer import review


class CustomerReviewTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        app = FastAPI()
        app.include_router(review.router)
        cls.client = TestClient(app)

    def setUp(self):
        self.conn = MagicMock()
        self.cursor = self.conn.cursor.return_value.__enter__.return_value
        self.cursor.rowcount = 1
        self.cursor.fetchone.side_effect = [
            {"customer_id": "cus_1"}, {"cosmetic_id": "sku_1"}, {"seq": 7},
        ]
        patcher = patch.object(review, "get_connection", return_value=self.conn)
        patcher.start()
        self.addCleanup(patcher.stop)
        self.owner = {"review_id": "rev_7", "customer_id": "cus_1", "cosmetic_id": "sku_1"}

    def create(self, **overrides):
        return self.client.post("/reviews_upload", data={"customer_id": "cus_1", "cosmetic_id": "sku_1",
            "review_content": " 사용감이 좋습니다. ", "rating": "5", **overrides})

    def update(self, **overrides):
        return self.client.put("/reviews_update", data={"review_id": "rev_7", "customer_id": "cus_1",
            "review_content": "수정한 내용", "rating": "3", **overrides})

    def delete(self, **overrides):
        return self.client.request("DELETE", "/reviews_delete", data={"review_id": "rev_7", "customer_id": "cus_1", **overrides})

    def test_delivered_purchase_saves_content_and_rating_together(self):
        response = self.create()
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json(), {"result": "OK", "review_id": "rev_7", "customer_id": "cus_1", "cosmetic_id": "sku_1"})
        sql, params = self.cursor.execute.call_args_list[1].args
        self.assertEqual(params, ("cus_1", "sku_1"))
        self.assertIn("o.order_status = 'DELIVERED'", sql)
        self.assertIn("d.delivery_status = 'DELIVERED'", sql)
        self.assertEqual(self.cursor.execute.call_args.args[1], ("rev_7", "cus_1", "sku_1", "사용감이 좋습니다.", 5))
        self.conn.commit.assert_called_once()
        self.conn.rollback.assert_not_called()
        self.conn.close.assert_called_once()

    def test_no_delivered_purchase_is_rejected_before_writing(self):
        self.cursor.fetchone.side_effect = [{"customer_id": "cus_1"}, None]
        self.assertEqual(self.create().status_code, 403)
        self.assertEqual(self.cursor.execute.call_count, 2)
        self.conn.commit.assert_not_called()
        self.conn.rollback.assert_called_once()

    def test_unknown_customer_cannot_create_review(self):
        self.cursor.fetchone.side_effect = [None]
        self.assertEqual(self.create().status_code, 404)
        self.conn.commit.assert_not_called()

    def test_split_delivery_check_is_joined_to_the_exact_purchased_item(self):
        self.cursor.fetchall.return_value = [{"cosmetic_id": "sku_1"}]
        response = self.client.get("/reviews_eligibility?customer_id=cus_1")
        self.assertEqual(response.json(), {"result": [{"cosmetic_id": "sku_1"}]})
        sql, params = self.cursor.execute.call_args.args
        normalized = " ".join(sql.split())
        self.assertIn("so.order_item_id = oi.order_item_id", normalized)
        self.assertIn("d.delivery_id = so.delivery_id AND d.order_id = o.order_id", normalized)
        self.assertIn("o.customer_id = %s", normalized)
        self.assertIn("o.order_status <> 'CANCELLED'", normalized)
        self.assertEqual(params, ("cus_1",))
        self.conn.commit.assert_not_called()

    def test_product_specific_eligibility_uses_parameters(self):
        self.cursor.fetchall.return_value = []
        response = self.client.get("/reviews_eligibility", params={"customer_id": "cus_1", "cosmetic_id": "bad' OR '1'='1"})
        self.assertEqual(response.status_code, 200)
        sql, params = self.cursor.execute.call_args.args
        self.assertNotIn("bad'", sql)
        self.assertEqual(params, ("cus_1", "bad' OR '1'='1"))

    def test_duplicate_customer_product_review_is_a_conflict(self):
        def execute(sql, params=()):
            if "INSERT INTO reviews" in sql:
                raise pymysql.IntegrityError(1062, "private duplicate detail")
        self.cursor.execute.side_effect = execute
        response = self.create()
        self.assertEqual(response.status_code, 409)
        self.assertNotIn("private", response.text)
        self.conn.rollback.assert_called_once()
        self.conn.commit.assert_not_called()

    def test_blank_long_content_and_invalid_ratings_do_not_reach_database(self):
        for overrides in ({"review_content": " "}, {"review_content": "가" * 2001},
                          {"customer_id": " "}, {"cosmetic_id": " "}, {"rating": 0}, {"rating": 6}, {"rating": "3.5"}):
            with self.subTest(overrides=overrides):
                self.assertEqual(self.create(**overrides).status_code, 422)
        review.get_connection.assert_not_called()

    def test_owner_can_edit_content_and_rating(self):
        self.cursor.fetchone.side_effect = [self.owner]
        response = self.update()
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["cosmetic_id"], "sku_1")
        self.assertEqual(self.cursor.execute.call_args.args[1], ("수정한 내용", 3, "rev_7", "cus_1"))
        self.conn.commit.assert_called_once()

    def test_unchanged_review_is_still_a_success(self):
        self.cursor.fetchone.side_effect = [self.owner]
        self.cursor.rowcount = 0
        self.assertEqual(self.update().status_code, 200)
        self.conn.commit.assert_called_once()

    def test_someone_else_cannot_update_or_delete(self):
        for action in (self.update, self.delete):
            with self.subTest(action=action.__name__):
                self.cursor.fetchone.side_effect = [{**self.owner, "customer_id": "other"}]
                self.assertEqual(action().status_code, 403)
        self.conn.commit.assert_not_called()

    def test_owner_delete_reports_a_single_deleted_review(self):
        self.cursor.fetchone.side_effect = [self.owner]
        response = self.delete()
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["deleted_count"], 1)
        self.assertEqual(self.cursor.execute.call_args.args[1], ("rev_7", "cus_1"))
        self.conn.commit.assert_called_once()

    def test_missing_review_and_unexpected_delete_count_are_not_success(self):
        self.cursor.fetchone.side_effect = [None]
        self.assertEqual(self.delete().status_code, 404)
        self.cursor.fetchone.side_effect = [self.owner]
        self.cursor.rowcount = 0
        self.assertEqual(self.delete().status_code, 409)
        self.conn.commit.assert_not_called()

    def test_list_filters_are_parameterized(self):
        self.cursor.fetchall.return_value = []
        response = self.client.get("/reviews_select?customer_id=cus_1&cosmetic_id=sku_1")
        self.assertEqual(response.json(), {"result": []})
        self.assertEqual(self.cursor.execute.call_args.args[1], ("cus_1", "sku_1"))
        self.conn.commit.assert_not_called()

    def test_database_errors_roll_back_without_exposing_details(self):
        self.cursor.execute.side_effect = pymysql.OperationalError(2006, "private connection detail")
        response = self.create()
        self.assertEqual(response.status_code, 503)
        self.assertNotIn("private", response.text)
        self.conn.rollback.assert_called_once()
        self.conn.close.assert_called_once()


if __name__ == "__main__":
    unittest.main()
