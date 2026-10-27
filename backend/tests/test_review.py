import unittest
from unittest.mock import MagicMock, patch

import pymysql
from fastapi.testclient import TestClient

from main import app
from routers.customer import review


class ReviewApiTests(unittest.TestCase):
    def setUp(self):
        self.client = TestClient(app)
        self.conn = MagicMock()
        self.cursor = self.conn.cursor.return_value.__enter__.return_value
        patcher = patch.object(review, "get_connection", return_value=self.conn)
        self.connection_mock = patcher.start()
        self.addCleanup(patcher.stop)
        self.form = {
            "customer_id": "cus_1", "cosmetic_id": "mfr_demo_cat_skin_1_1",
            "review_content": "사용감이 좋습니다.", "rating": 5,
        }
        self.owner = {"review_id": "rev_7", "customer_id": "cus_1"}
        self.update_url = "/reviews_update?review_id=rev_7&customer_id=cus_1"
        self.delete_form = {"review_id": "rev_7", "customer_id": "cus_1"}

    def assert_rolled_back(self):
        self.conn.commit.assert_not_called()
        self.conn.rollback.assert_called_once()
        self.conn.close.assert_called_once()

    def test_review_routes_do_not_duplicate_customer_routes(self):
        paths = self.client.get("/openapi.json").json()["paths"]
        for path, method in (("/reviews_upload", "post"), ("/reviews_select", "get"),
                             ("/reviews_update", "put"), ("/reviews_delete", "delete")):
            self.assertIn(method, paths[path])
        for path in ("/customers_upload", "/customers_select", "/customers_update", "/customers_delect"):
            self.assertIn(path, paths)
            self.assertNotIn(path, {r.path for r in review.router.routes})

    def test_registration_generates_id_and_commits_review(self):
        self.cursor.fetchone.side_effect = [{"customer_id": "cus_1"},
                                           {"cosmetic_id": self.form["cosmetic_id"]}, {"seq": 7}]
        response = self.client.post("/reviews_upload", data=self.form)
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["review_id"], "rev_7")
        params = self.cursor.execute.call_args.args[1]
        self.assertEqual(params, ("rev_7", "cus_1", self.form["cosmetic_id"], self.form["review_content"], 5))
        self.conn.commit.assert_called_once()
        self.conn.rollback.assert_not_called()
        self.conn.close.assert_called_once()

    def test_registration_rejects_missing_customer_or_product(self):
        for rows in ([None], [{"customer_id": "cus_1"}, None]):
            with self.subTest(rows=rows):
                self.conn.reset_mock()
                self.cursor.fetchone.side_effect = rows
                response = self.client.post("/reviews_upload", data=self.form)
                self.assertEqual(response.status_code, 404)
                self.assert_rolled_back()

    def test_duplicate_review_returns_conflict(self):
        self.cursor.fetchone.side_effect = [{"customer_id": "cus_1"},
                                           {"cosmetic_id": self.form["cosmetic_id"]}, {"seq": 8}]

        def execute(sql, params=None):
            if "INSERT INTO reviews" in sql:
                raise pymysql.IntegrityError(1062, "Duplicate review")
        self.cursor.execute.side_effect = execute
        self.assertEqual(self.client.post("/reviews_upload", data=self.form).status_code, 409)
        self.assert_rolled_back()

    def test_registration_handles_customer_deleted_during_request(self):
        self.cursor.fetchone.side_effect = [{"customer_id": "cus_1"},
                                           {"cosmetic_id": self.form["cosmetic_id"]}, {"seq": 8}]

        def execute(sql, params=None):
            if "INSERT INTO reviews" in sql:
                raise pymysql.IntegrityError(1452, "Foreign key failure")
        self.cursor.execute.side_effect = execute
        self.assertEqual(self.client.post("/reviews_upload", data=self.form).status_code, 404)
        self.assert_rolled_back()

    def test_invalid_registration_is_rejected_before_database_access(self):
        for change in ({"rating": 0}, {"rating": 6}, {"review_content": "  "},
                       {"customer_id": "  "}, {"review_content": "가" * 21846}):
            with self.subTest(field=next(iter(change))):
                response = self.client.post("/reviews_upload", data=dict(self.form, **change))
                self.assertEqual(response.status_code, 422)
        self.connection_mock.assert_not_called()

    def test_review_list_binds_filters_and_returns_rows(self):
        rows = [dict(self.owner, review_content=self.form["review_content"], rating=5)]
        self.cursor.fetchall.return_value = rows
        cosmetic_id = "product' OR 1=1 --"
        response = self.client.get("/reviews_select", params={
            "review_id": "rev_7", "customer_id": "cus_1", "cosmetic_id": cosmetic_id,
        })
        self.assertEqual(response.json(), {"result": rows})
        sql, params = self.cursor.execute.call_args.args
        self.assertNotIn(cosmetic_id, sql)
        self.assertEqual(params, ("rev_7", "cus_1", cosmetic_id))
        self.conn.close.assert_called_once()

    def test_empty_review_list_returns_empty_array(self):
        self.cursor.fetchall.return_value = []
        self.assertEqual(self.client.get("/reviews_select").json(), {"result": []})
        self.conn.close.assert_called_once()

    def test_list_failure_closes_connection(self):
        self.cursor.execute.side_effect = pymysql.OperationalError(2013, "Lost connection")
        with TestClient(app, raise_server_exceptions=False) as client:
            self.assertEqual(client.get("/reviews_select").status_code, 500)
        self.conn.close.assert_called_once()

    def test_update_changes_only_content_and_rating(self):
        self.cursor.fetchone.return_value = self.owner
        response = self.client.put(self.update_url, data={"review_content": "수정한 리뷰", "rating": 4})
        self.assertEqual(response.status_code, 200)
        sql, params = self.cursor.execute.call_args.args
        self.assertIn("UPDATE reviews", sql)
        self.assertEqual(params, ("수정한 리뷰", 4, "rev_7", "cus_1"))
        self.conn.commit.assert_called_once()
        self.conn.close.assert_called_once()

    def test_unchanged_review_update_is_successful(self):
        self.cursor.fetchone.return_value = self.owner
        self.cursor.rowcount = 0
        self.assertEqual(self.client.put(self.update_url, data=self.form).status_code, 200)
        self.conn.commit.assert_called_once()

    def test_update_rejects_missing_review_or_different_author(self):
        for row, status in ((None, 404), ({"customer_id": "cus_2"}, 403)):
            with self.subTest(status=status):
                self.conn.reset_mock()
                self.cursor.fetchone.return_value = row
                self.assertEqual(self.client.put(self.update_url, data=self.form).status_code, status)
                self.assert_rolled_back()

    def test_invalid_update_does_not_access_database(self):
        for change in ({"rating": 6}, {"review_content": "  "}, {"review_content": "가" * 21846}):
            with self.subTest(field=next(iter(change))):
                response = self.client.put(self.update_url, data=dict(self.form, **change))
                self.assertEqual(response.status_code, 422)
        self.connection_mock.assert_not_called()

    def test_delete_removes_selected_review(self):
        cursor = self.cursor

        # 리뷰 작성자 조회 결과
        cursor.fetchone.side_effect = None
        cursor.fetchone.return_value = {
            "customer_id": "cus_1"
        }

        # 삭제된 행 수
        cursor.rowcount = 1

        response = self.client.request(
            "DELETE",
            "/reviews_delete",
            data=self.delete_form,
        )

        self.assertEqual(response.status_code, 200)

        self.assertEqual(
            response.json(),
            {
                "result": "OK",
                "deleted_count": 1,
                "message": "리뷰가 삭제되었습니다.",
            },
        )

        self.assertEqual(cursor.execute.call_count, 2)

        self.conn.commit.assert_called_once()
        self.conn.rollback.assert_not_called()
        self.conn.close.assert_called_once()

    def test_delete_missing_review_returns_zero_deleted_count(self):
        self.cursor.fetchone.return_value = None
        response = self.client.request(
            "DELETE",
            "/reviews_delete",
            data={
                "review_id": "rev_999",
                "customer_id": "cus_1",
            },
        )
        self.assertEqual(response.status_code, 404)
        self.assertEqual(response.json(),
            {
                "detail": "존재하지 않는 리뷰입니다.",
            },
        )
        self.conn.commit.assert_not_called()
        self.conn.rollback.assert_called_once()
        self.conn.close.assert_called_once()

    def test_delete_failure_returns_error_and_rolls_back(self):
        self.cursor.execute.side_effect = pymysql.OperationalError(2013, "Lost connection")
        response = self.client.request(
            "DELETE",
            "/reviews_delete",
            data=self.delete_form,
        )
        self.assertEqual(response.status_code, 500)
        self.assertEqual(
            response.json(),
            {
                "detail": "리뷰 삭제 중 오류가 발생했습니다.",
            },
        )
        self.assert_rolled_back()

    def test_delete_connection_failure_does_not_close_missing_connection(self):
        self.connection_mock.side_effect = pymysql.OperationalError(2003, "Cannot connect")
        response = self.client.request(
            "DELETE",
            "/reviews_delete",
            data=self.delete_form,
        )
        self.assertEqual(response.status_code, 500)
        self.assertEqual(
            response.json(),
            {
                "detail": "리뷰 삭제 중 오류가 발생했습니다.",
            },
        )
        self.conn.commit.assert_not_called()
        self.conn.rollback.assert_not_called()
        self.conn.close.assert_not_called()

    def test_delete_rejects_blank_review_id(self):
        response = self.client.request(
            "DELETE",
            "/reviews_delete",
            data={
                "review_id": "  ",
                "customer_id": "cus_1",
            },
        )
        self.assertEqual(response.status_code, 422)
        self.connection_mock.assert_not_called()

    def test_delete_rejects_nonnumeric_or_nonpositive_review_id(self):
        for review_id in ("abc", "0", "-1", "rev_0"):
            with self.subTest(review_id=review_id):
                response = self.client.request(
                    "DELETE",
                    "/reviews_delete",
                    data={
                        "review_id": review_id,
                        "customer_id": "cus_1",
                    },
                )
                self.assertEqual(response.status_code, 422)
        self.connection_mock.assert_not_called()

    def test_writing_failure_rolls_back_and_closes_connection(self):
        for operation in ("create", "update"):
            with self.subTest(operation=operation):
                self.conn.reset_mock()
                self.cursor.fetchone.side_effect = (
                    [{"customer_id": "cus_1"}, {"cosmetic_id": self.form["cosmetic_id"]}, {"seq": 9}]
                    if operation == "create" else [self.owner]
                )

                def execute(sql, params=None):
                    if any(part in sql for part in ("INSERT INTO reviews", "UPDATE reviews", "DELETE FROM reviews")):
                        raise pymysql.OperationalError(2013, "Lost connection")
                self.cursor.execute.side_effect = execute
                with TestClient(app, raise_server_exceptions=False) as client:
                    if operation == "create":
                        response = client.post("/reviews_upload", data=self.form)
                    elif operation == "update":
                        response = client.put(self.update_url, data=self.form)
                self.assertEqual(response.status_code, 500)
                self.assert_rolled_back()


if __name__ == "__main__":
    unittest.main()
