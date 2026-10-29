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

        # 리뷰 API가 정상 등록되어 있는지 확인
        review_routes = (
            ("/reviews_upload", "post"),
            ("/reviews_select", "get"),
            ("/reviews_update", "put"),
            ("/reviews_delete", "delete"),
            ("/reviews_eligibility", "get"),
        )

        for path, method in review_routes:
            with self.subTest(path=path, method=method):
                self.assertIn(path, paths)
                self.assertIn(method, paths[path])

        # 고객 API 경로 확인
        customer_routes = (
            "/customer_upload",
            "/customer_select",
            "/customer_update",
            "/customer_delect",
        )

        registered_review_paths = {
            route.path for route in review.router.routes
        }

        for path in customer_routes:
            with self.subTest(customer_path=path):
                # 전체 FastAPI 앱에는 고객 API가 등록되어 있어야 함
                self.assertIn(path, paths)

                # 리뷰 라우터에는 고객 API가 중복 등록되면 안 됨
                self.assertNotIn(path, registered_review_paths)

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
        cases = [
            ([None], 404, "존재하지 않는 고객입니다."),
            (
                [{"customer_id": "cus_1"}, None],
                403,
                "배송 완료된 구매 상품만 리뷰를 작성할 수 있습니다.",
            ),
        ]

        for rows, expected_status, expected_detail in cases:
            with self.subTest(expected_status=expected_status):
                self.conn.reset_mock()
                self.cursor.reset_mock()

                self.cursor.fetchone.side_effect = rows

                response = self.client.post(
                    "/reviews_upload",
                    data=self.form,
                )

                self.assertEqual(
                    response.status_code,
                    expected_status,
                )

                self.assertEqual(
                    response.json(),
                    {"detail": expected_detail},
                )

                self.conn.begin.assert_called_once()
                self.conn.rollback.assert_called_once()
                self.conn.commit.assert_not_called()
                self.conn.close.assert_called_once()

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
        self.cursor.fetchone.side_effect = [
            {"customer_id": "cus_1"},
            {"cosmetic_id": self.form["cosmetic_id"]},
            {"seq": 8},
        ]

        def execute(sql, params=None):
            if "INSERT INTO reviews" in sql:
                raise pymysql.IntegrityError(
                    1452,
                    "Foreign key failure",
                )

        self.cursor.execute.side_effect = execute

        response = self.client.post(
            "/reviews_upload",
            data=self.form,
        )

        self.assertEqual(response.status_code, 503)

        self.assertEqual(
            response.json(),
            {
                "detail": "리뷰 요청을 처리하지 못했습니다. 다시 조회해 주세요.",
            },
        )

        # 외래 키 오류 발생 시 트랜잭션 롤백
        self.conn.begin.assert_called_once()
        self.conn.rollback.assert_called_once()
        self.conn.commit.assert_not_called()
        self.conn.close.assert_called_once()

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
        self.cursor.execute.side_effect = pymysql.OperationalError(
            2013,
            "Lost connection",
        )

        response = self.client.get("/reviews_select")

        self.assertEqual(response.status_code, 503)

        self.assertEqual(
            response.json(),
            {
                "detail": "리뷰 요청을 처리하지 못했습니다. 다시 조회해 주세요.",
            },
        )

        # 조회 요청이므로 트랜잭션을 시작하지 않음
        self.conn.begin.assert_not_called()

        # 조회 실패 시 commit과 rollback은 실행되지 않음
        self.conn.commit.assert_not_called()
        self.conn.rollback.assert_not_called()

        # 오류가 발생해도 DB 연결은 종료
        self.conn.close.assert_called_once()

    def test_update_changes_only_content_and_rating(self):
        self.cursor.fetchone.return_value = {
            "review_id": "rev_7",
            "customer_id": "cus_1",
            "cosmetic_id": self.form["cosmetic_id"],
        }

        response = self.client.put(
            "/reviews_update",
            data={
                "review_id": "rev_7",
                "customer_id": "cus_1",
                "review_content": "수정한 리뷰",
                "rating": 4,
            },
        )

        self.assertEqual(response.status_code, 200)

        self.assertEqual(
            response.json(),
            {
                "result": "OK",
                "review_id": "rev_7",
                "customer_id": "cus_1",
                "cosmetic_id": self.form["cosmetic_id"],
                "message": "리뷰를 수정했습니다.",
            },
        )

        # 마지막 SQL이 UPDATE인지 확인
        sql, params = self.cursor.execute.call_args.args

        self.assertIn("UPDATE reviews", sql)

        # 리뷰 내용과 평점만 수정하고, 작성자 조건도 유지
        self.assertEqual(
            params,
            ("수정한 리뷰", 4, "rev_7", "cus_1"),
        )

        # 소유자 조회 + 리뷰 수정
        self.assertEqual(self.cursor.execute.call_count, 2)

        self.conn.begin.assert_called_once()
        self.conn.commit.assert_called_once()
        self.conn.rollback.assert_not_called()
        self.conn.close.assert_called_once()

    def test_unchanged_review_update_is_successful(self):
        self.cursor.fetchone.return_value = {
            "review_id": "rev_7",
            "customer_id": "cus_1",
            "cosmetic_id": self.form["cosmetic_id"],
        }

        # 기존 데이터와 동일하여 변경된 행이 없는 상황
        self.cursor.rowcount = 0

        response = self.client.put(
            "/reviews_update",
            data={
                "review_id": "rev_7",
                "customer_id": "cus_1",
                "review_content": self.form["review_content"],
                "rating": self.form["rating"],
            },
        )

        self.assertEqual(response.status_code, 200)

        self.assertEqual(
            response.json(),
            {
                "result": "OK",
                "review_id": "rev_7",
                "customer_id": "cus_1",
                "cosmetic_id": self.form["cosmetic_id"],
                "message": "리뷰를 수정했습니다.",
            },
        )

        sql, params = self.cursor.execute.call_args.args

        self.assertIn("UPDATE reviews", sql)

        self.assertEqual(
            params,
            (
                self.form["review_content"],
                self.form["rating"],
                "rev_7",
                "cus_1",
            ),
        )

        self.conn.begin.assert_called_once()
        self.conn.commit.assert_called_once()
        self.conn.rollback.assert_not_called()
        self.conn.close.assert_called_once()

    def test_update_rejects_missing_review_or_different_author(self):
        cases = [
            (
                None,
                404,
                "존재하지 않는 리뷰입니다.",
            ),
            (
                {
                    "review_id": "rev_7",
                    "customer_id": "cus_2",
                    "cosmetic_id": self.form["cosmetic_id"],
                },
                403,
                "작성자만 리뷰를 수정·삭제할 수 있습니다.",
            ),
        ]

        for row, expected_status, expected_detail in cases:
            with self.subTest(expected_status=expected_status):
                self.conn.reset_mock()
                self.cursor.reset_mock()

                self.cursor.fetchone.return_value = row

                response = self.client.put(
                    "/reviews_update",
                    data={
                        "review_id": "rev_7",
                        "customer_id": "cus_1",
                        "review_content": "수정한 리뷰",
                        "rating": 4,
                    },
                )

                self.assertEqual(
                    response.status_code,
                    expected_status,
                )

                self.assertEqual(
                    response.json(),
                    {"detail": expected_detail},
                )

                # 리뷰 조회만 실행하고 UPDATE는 실행하지 않음
                self.assertEqual(self.cursor.execute.call_count, 1)

                sql = self.cursor.execute.call_args.args[0]
                self.assertIn("SELECT review_id", sql)

                # 수정이 거부되었으므로 롤백
                self.conn.begin.assert_called_once()
                self.conn.rollback.assert_called_once()
                self.conn.commit.assert_not_called()
                self.conn.close.assert_called_once()

    def test_invalid_update_does_not_access_database(self):
        cases = [
            {"rating": 0},
            {"rating": 6},
            {"review_content": "  "},
            {"review_content": "가" * 2001},
        ]

        for change in cases:
            with self.subTest(change=change):
                self.connection_mock.reset_mock()

                data = {
                    "review_id": "rev_7",
                    "customer_id": "cus_1",
                    "review_content": "정상 리뷰 내용",
                    "rating": 5,
                }

                data.update(change)

                response = self.client.put(
                    "/reviews_update",
                    data=data,
                )

                self.assertEqual(response.status_code, 422)

                # 잘못된 입력은 DB 접근 전에 차단
                self.connection_mock.assert_not_called()

    def test_delete_removes_selected_review(self):
        self.cursor.fetchone.return_value = {
            "review_id": "rev_7",
            "customer_id": "cus_1",
            "cosmetic_id": self.form["cosmetic_id"],
        }

        self.cursor.rowcount = 1

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
                "review_id": "rev_7",
                "customer_id": "cus_1",
                "cosmetic_id": self.form["cosmetic_id"],
                "deleted_count": 1,
            },
        )

        self.assertEqual(self.cursor.execute.call_count, 2)

        self.conn.begin.assert_called_once()
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
        self.cursor.execute.side_effect = pymysql.OperationalError(
            2013,
            "Lost connection",
        )

        response = self.client.request(
            "DELETE",
            "/reviews_delete",
            data=self.delete_form,
        )

        self.assertEqual(response.status_code, 503)

        self.assertEqual(
            response.json(),
            {
                "detail": "리뷰 요청을 처리하지 못했습니다. 다시 조회해 주세요.",
            },
        )

        # DB 연결 이후 SQL 오류가 발생했으므로 롤백
        self.conn.begin.assert_called_once()
        self.conn.rollback.assert_called_once()
        self.conn.commit.assert_not_called()
        self.conn.close.assert_called_once()

    def test_delete_connection_failure_does_not_close_missing_connection(self):
        self.connection_mock.side_effect = pymysql.OperationalError(
            2003,
            "Cannot connect",
        )

        response = self.client.request(
            "DELETE",
            "/reviews_delete",
            data=self.delete_form,
        )

        self.assertEqual(response.status_code, 503)

        self.assertEqual(
            response.json(),
            {
                "detail": "리뷰 요청을 처리하지 못했습니다. 다시 조회해 주세요.",
            },
        )

        # DB 연결 자체가 실패했으므로 트랜잭션 처리 및 연결 종료 없음
        self.conn.begin.assert_not_called()
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
                self.conn.reset_mock()
                self.cursor.reset_mock()

                # DB에 해당 리뷰가 존재하지 않는 상황
                self.cursor.fetchone.return_value = None

                response = self.client.request(
                    "DELETE",
                    "/reviews_delete",
                    data={
                        "review_id": review_id,
                        "customer_id": "cus_1",
                    },
                )

                self.assertEqual(response.status_code, 404)

                self.assertEqual(
                    response.json(),
                    {"detail": "존재하지 않는 리뷰입니다."},
                )

                self.conn.begin.assert_called_once()
                self.conn.rollback.assert_called_once()
                self.conn.commit.assert_not_called()
                self.conn.close.assert_called_once()

    def test_writing_failure_rolls_back_and_closes_connection(self):
        for operation in ("create", "update"):
            with self.subTest(operation=operation):
                self.conn.reset_mock()
                self.cursor.reset_mock()

                if operation == "create":
                    self.cursor.fetchone.side_effect = [
                        {"customer_id": "cus_1"},
                        {"cosmetic_id": self.form["cosmetic_id"]},
                        {"seq": 9},
                    ]
                else:
                    self.cursor.fetchone.side_effect = None
                    self.cursor.fetchone.return_value = {
                        "review_id": "rev_7",
                        "customer_id": "cus_1",
                        "cosmetic_id": self.form["cosmetic_id"],
                    }

                def execute(sql, params=None):
                    if any(
                        keyword in sql
                        for keyword in (
                            "INSERT INTO reviews",
                            "UPDATE reviews",
                            "DELETE FROM reviews",
                        )
                    ):
                        raise pymysql.OperationalError(
                            2013,
                            "Lost connection",
                        )

                self.cursor.execute.side_effect = execute

                if operation == "create":
                    response = self.client.post(
                        "/reviews_upload",
                        data=self.form,
                    )
                else:
                    response = self.client.put(
                        "/reviews_update",
                        data={
                            "review_id": "rev_7",
                            "customer_id": "cus_1",
                            "review_content": "수정한 리뷰",
                            "rating": 4,
                        },
                    )

                self.assertEqual(response.status_code, 503)

                self.assertEqual(
                    response.json(),
                    {
                        "detail": "리뷰 요청을 처리하지 못했습니다. 다시 조회해 주세요.",
                    },
                )

                self.conn.begin.assert_called_once()
                self.conn.rollback.assert_called_once()
                self.conn.commit.assert_not_called()
                self.conn.close.assert_called_once()


if __name__ == "__main__":
    unittest.main()
