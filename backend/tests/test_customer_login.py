import unittest
from unittest.mock import MagicMock, patch

import pymysql
from fastapi import FastAPI
from fastapi.testclient import TestClient

from routers.customer import customer


class CustomerLoginTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.password = " secret123 "
        cls.password_hash = customer.password_hasher.hash(cls.password)
        app = FastAPI()
        app.include_router(customer.router)
        cls.client = TestClient(app)

    def setUp(self):
        self.conn = MagicMock()
        self.cursor = self.conn.cursor.return_value.__enter__.return_value
        self.profile = {
            "customer_id": "cus_1", "login_id": "sodam",
            "password_hash": self.password_hash, "customer_name": "소담고객",
            "email": "sodam@example.com", "address": "서울시",
            "phone": "01012345678", "gender": "UNDISCLOSED", "points_balance": 0,
        }
        self.cursor.fetchone.side_effect = [self.profile, {"account_status": "ACTIVE"}]
        self.connection_patch = patch.object(customer, "get_connection", return_value=self.conn)
        self.connection_patch.start()
        self.addCleanup(self.connection_patch.stop)

    def login(self, **overrides):
        return self.client.post("/customer_login", data={
            "login_id": "sodam", "password": self.password, **overrides,
        })

    def test_login_sits_between_registration_and_select(self):
        routes = [route.path for route in customer.router.routes]
        self.assertLess(routes.index("/customer_upload"), routes.index("/customer_login"))
        self.assertLess(routes.index("/customer_login"), routes.index("/customer_select"))

    def test_valid_credentials_return_only_public_customer_fields(self):
        response = self.login()
        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertEqual(body["result"], "OK")
        self.assertEqual(body["customer"], {
            key: value for key, value in self.profile.items() if key != "password_hash"
        } | {"account_status": "ACTIVE"})
        self.assertNotIn(self.password_hash, response.text)
        self.assertNotIn("password", body["customer"])
        self.conn.close.assert_called_once()
        self.conn.commit.assert_not_called()

    def test_unknown_id_and_wrong_password_have_the_same_response(self):
        self.cursor.fetchone.side_effect = [None]
        missing = self.login()
        self.cursor.fetchone.side_effect = [self.profile]
        wrong = self.login(password="wrong-password")
        self.assertEqual(missing.status_code, 401)
        self.assertEqual(wrong.status_code, 401)
        self.assertEqual(missing.json(), wrong.json())
        self.assertNotIn("customer", wrong.json())

    def test_withdrawn_customer_cannot_log_in(self):
        self.cursor.fetchone.side_effect = [self.profile, {"account_status": "WITHDRAWN"}]
        response = self.login()
        self.assertEqual(response.status_code, 403)
        self.assertNotIn("customer", response.json())
        self.conn.close.assert_called_once()

    def test_legacy_customer_without_status_history_is_active(self):
        self.cursor.fetchone.side_effect = [self.profile, None]
        response = self.login()
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["customer"]["account_status"], "ACTIVE")

    def test_invalid_stored_hash_is_never_treated_as_a_plaintext_password(self):
        for invalid_hash in ("secret123", None, "__DEMO_HASH__"):
            with self.subTest(hash_value=invalid_hash):
                self.cursor.fetchone.side_effect = [dict(self.profile, password_hash=invalid_hash)]
                response = self.login(password="secret123")
                self.assertEqual(response.status_code, 401)

    def test_login_id_is_parameterized_and_trimmed(self):
        attempted_id = " x' OR '1'='1 "
        self.cursor.fetchone.side_effect = [None]
        self.assertEqual(self.login(login_id=attempted_id).status_code, 401)
        sql, params = self.cursor.execute.call_args.args
        self.assertIn("WHERE login_id = %s", sql)
        self.assertNotIn(attempted_id.strip(), sql)
        self.assertEqual(params, (attempted_id.strip(),))

    def test_password_spaces_are_significant(self):
        self.cursor.fetchone.side_effect = [self.profile]
        self.assertEqual(self.login(password=self.password.strip()).status_code, 401)

    def test_query_failure_returns_service_error_without_database_details(self):
        self.cursor.execute.side_effect = pymysql.OperationalError(2006, "private database detail")
        response = self.login()
        self.assertEqual(response.status_code, 503)
        self.assertNotIn("private database detail", response.text)
        self.conn.close.assert_called_once()

    def test_connection_failure_returns_service_error(self):
        with patch.object(customer, "get_connection", side_effect=pymysql.OperationalError(2003, "private")):
            response = self.login()
        self.assertEqual(response.status_code, 503)
        self.assertNotIn("private", response.text)

    def test_missing_password_is_rejected_before_database_access(self):
        response = self.client.post("/customer_login", data={"login_id": "sodam"})
        self.assertEqual(response.status_code, 422)
        customer.get_connection.assert_not_called()


if __name__ == "__main__":
    unittest.main()
