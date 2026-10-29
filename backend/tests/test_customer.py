import unittest
from decimal import Decimal
from unittest.mock import MagicMock, patch

import pymysql
from fastapi.testclient import TestClient

from main import app
from routers.customer import customer, order


class CustomerApiTests(unittest.TestCase):
    def setUp(self):
        self.client = TestClient(app)
        self.conn = MagicMock()
        self.cursor = self.conn.cursor.return_value.__enter__.return_value
        self.cursor.rowcount = 1
        self.customer_patch = patch.object(customer, "get_connection", return_value=self.conn)
        self.order_patch = patch.object(order, "get_connection", return_value=self.conn)
        self.customer_patch.start()
        self.order_patch.start()
        self.addCleanup(self.customer_patch.stop)
        self.addCleanup(self.order_patch.stop)
        self.profile = {
            "customer_id": "cus_1",
            "login_id": "customer1",
            "password": "secret123",
            "customer_name": "고객",
            "email": "customer@example.com",
            "address": "서울시",
            "phone": "010-1234-5678",
        }
        self.buyer = {"customer_id": "cus_1", "customer_name": "고객", "address": "서울시"}
        self.product = {
            "inventory_id": "inv_pa_mfr_demo_cat_skin_1_1_1_1_1",
            "sale_price": Decimal("1234.50"), "sale_status": "ON_SALE",
            "sale_option": "NORMAL", "product_name": "크림",
        }
        self.order_form = {
            "customer_id": "cus_1", "inventory_id": self.product["inventory_id"], "quantity": 2,
        }

    def executed(self, fragment):
        return [call.args for call in self.cursor.execute.call_args_list
                if fragment in call.args[0]]

    def assert_rolled_back(self):
        self.conn.rollback.assert_called_once()
        self.conn.commit.assert_not_called()
        self.conn.close.assert_called_once()

    def test_server_and_all_original_routes_are_registered(self):
        self.assertEqual(
            self.client.get("/health").json(),
            {"status": "ok"},
        )
        self.assertEqual(
            self.client.get("/customer/test").status_code,
            200,
        )

        paths = self.client.get("/openapi.json").json()["paths"]

        for route in (
            "/customer_upload",
            "/customer_select",
            "/customer_update",
            "/customer_delect",
            "/orders",
            "/orders_pay",
            "/admin/cosmetics",
            "/delivery/test",
        ):
            self.assertIn(route, paths)

    def test_registration_hashes_password_and_commits_active_history(self):
        self.cursor.fetchone.side_effect = [{"seq": 10}]
        response = self.client.post("/customer_upload", data=self.profile)
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["customer_id"], "cus_1")
        params = self.executed("INSERT INTO customers")[0][1]
        self.assertNotEqual(params[2], self.profile["password"])
        self.assertTrue(customer.password_hasher.verify(self.profile["password"], params[2]))
        self.assertEqual(params[-1], self.profile["phone"])
        self.assertEqual(self.executed("INSERT INTO customer_account_status_history")[0][1],
                         ("csh_10", "cus_1", "ACTIVE"))
        self.conn.commit.assert_called_once()
        self.conn.rollback.assert_not_called()
        self.conn.close.assert_called_once()

    def test_duplicate_registration_returns_conflict_and_rolls_back(self):
        self.cursor.fetchone.return_value = {"seq": 1}

        def execute(sql, params=None):
            if "INSERT INTO customers" in sql:
                raise pymysql.IntegrityError(1062, "Duplicate entry")
        self.cursor.execute.side_effect = execute
        response = self.client.post("/customer_upload", data=self.profile)
        self.assertEqual(response.status_code, 409)
        self.assert_rolled_back()

    def test_registration_history_failure_also_rolls_back_customer(self):
        self.cursor.fetchone.side_effect = [{"seq": 1}, {"seq": 2}]

        def execute(sql, params=None):
            if "INSERT INTO customer_account_status_history" in sql:
                raise pymysql.OperationalError(2013, "Lost connection")
        self.cursor.execute.side_effect = execute
        with TestClient(app, raise_server_exceptions=False) as client:
            self.assertEqual(client.post("/customer_upload", data=self.profile).status_code, 500)
        self.assert_rolled_back()

    def test_registration_requires_phone(self):
        self.profile.pop("phone")
        self.assertEqual(self.client.post("/customer_upload", data=self.profile).status_code, 422)
        self.conn.begin.assert_not_called()

    def test_customer_list_returns_actual_rows(self):
        rows = [{"customer_id": "cus_1", "customer_name": "고객",
                 "phone_number": "010-1234-5678", "address": "서울시"}]
        self.cursor.fetchall.return_value = rows
        response = self.client.get("/customer_select")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json(), {"result": rows})
        customer.get_connection.assert_called_once_with()
        self.conn.close.assert_called_once()

    def test_customer_list_without_customers_returns_empty_array(self):
        self.cursor.fetchall.return_value = []
        response = self.client.get("/customer_select")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json(), {"result": []})
        customer.get_connection.assert_called_once_with()
        self.conn.close.assert_called_once()

    def test_customer_list_failure_still_closes_connection(self):
        self.cursor.execute.side_effect = pymysql.OperationalError(2013, "Lost connection")
        with TestClient(app, raise_server_exceptions=False) as client:
            response = client.get("/customer_select")
        self.assertEqual(response.status_code, 500)
        customer.get_connection.assert_called_once_with()
        self.conn.close.assert_called_once()
        self.conn.commit.assert_not_called()

    def test_unchanged_profile_is_still_successful(self):
        self.cursor.fetchone.return_value = {"customer_id": "cus_1"}
        self.cursor.rowcount = 0
        response = self.client.put("/customer_update?customer_id=cus_1", data=self.profile)
        self.assertEqual(response.status_code, 200)
        self.conn.commit.assert_called_once()

    def test_missing_customer_update_returns_404(self):
        self.cursor.fetchone.return_value = None
        response = self.client.put("/customer_update?customer_id=cus_missing", data=self.profile)
        self.assertEqual(response.status_code, 404)
        self.assert_rolled_back()

    def test_duplicate_email_update_returns_conflict(self):
        self.cursor.fetchone.return_value = {"customer_id": "cus_1"}

        def execute(sql, params=None):
            if "UPDATE customers" in sql:
                raise pymysql.IntegrityError(1062, "Duplicate email")
        self.cursor.execute.side_effect = execute
        response = self.client.put("/customer_update?customer_id=cus_1", data=self.profile)
        self.assertEqual(response.status_code, 409)
        self.assert_rolled_back()

    def test_withdrawal_appends_history_and_keeps_customer(self):
        self.cursor.fetchone.side_effect = [self.buyer, {"account_status": "ACTIVE"}, {"seq": 11}]
        response = self.client.post("/customer_delect", data={"customer_id": "cus_1"})
        self.assertEqual(response.status_code, 200)
        self.assertEqual(self.executed("INSERT INTO customer_account_status_history")[0][1],
                         ("csh_11", "cus_1", "WITHDRAWN"))
        self.assertFalse(self.executed("DELETE FROM customers"))
        self.conn.commit.assert_called_once()

    def test_repeated_withdrawal_does_not_append_history(self):
        self.cursor.fetchone.side_effect = [self.buyer, {"account_status": "WITHDRAWN"}]
        response = self.client.post("/customer_delect", data={"customer_id": "cus_1"})
        self.assertEqual(response.status_code, 409)
        self.assertFalse(self.executed("INSERT INTO customer_account_status_history"))
        self.assert_rolled_back()

    def test_missing_customer_withdrawal_returns_404(self):
        self.cursor.fetchone.return_value = None
        self.assertEqual(self.client.post("/customer_delect", data={"customer_id": "missing"}).status_code, 404)
        self.assert_rolled_back()

    def test_order_uses_database_price_and_string_ids(self):
        cosmetic_id = "cos_1"
        inventory_id = self.product["inventory_id"]

        checkout_data = {
            "customer_id": "cus_1",
            "shipping_address": "서울시",
            "items": [
                {
                    "cosmetic_id": cosmetic_id,
                    "quantity": 2,
                    "sale_option": "NORMAL",
                }
            ],
        }

        # 고객 조회 → 계정 상태 → 상품 조회 → 주문번호 순번
        self.cursor.fetchone.side_effect = [
            self.buyer,
            {"account_status": "ACTIVE"},
            {
                "cosmetic_name": "크림",
                "sale_status": "ON_SALE",
                "sale_price": Decimal("1234.50"),
            },
            {"seq": 12},
        ]

        # 장바구니 조회 → 재고 로트 조회
        self.cursor.fetchall.side_effect = [
            [],
            [
                {
                    "inventory_id": inventory_id,
                    "stock_quantity": 10,
                }
            ],
        ]

        response = self.client.post(
            "/orders_pay",
            json=checkout_data,
        )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["order_id"], "ord_12")
        self.assertEqual(
            Decimal(str(response.json()["total_amount"])),
            Decimal("2469.00"),
        )
        self.assertEqual(response.json()["order_status"], "PAID")

        self.assertEqual(
            self.executed("INSERT INTO order_items")[0][1],
            (
                "ord_12_1",
                "ord_12",
                1,
                inventory_id,
                2,
                Decimal("1234.50"),
                "NORMAL",
            ),
        )

        self.conn.commit.assert_called_once()
        self.conn.rollback.assert_not_called()
        self.conn.close.assert_called_once()

    def test_legacy_customer_without_history_can_order(self):
        self.cursor.fetchone.side_effect = [
            self.buyer,
            None,
            {
                "cosmetic_name": "크림",
                "sale_status": "ON_SALE",
                "sale_price": Decimal("1234.50"),
            },
            {"seq": 1},
        ]

        self.cursor.fetchall.side_effect = [
            [],
            [
                {
                    "inventory_id": self.product["inventory_id"],
                    "stock_quantity": 10,
                }
            ],
        ]

        checkout_data = {
            "customer_id": "cus_1",
            "shipping_address": "서울시",
            "items": [
                {
                    "cosmetic_id": "cos_1",
                    "quantity": 2,
                    "sale_option": "NORMAL",
                }
            ],
        }

        response = self.client.post(
            "/orders_pay",
            json=checkout_data,
        )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["order_status"], "PAID")
        self.conn.commit.assert_called_once()

    def test_missing_or_withdrawn_customer_cannot_order(self):
        checkout_data = {
            "customer_id": "cus_1",
            "shipping_address": "서울시",
            "items": [
                {
                    "cosmetic_id": "cos_1",
                    "quantity": 2,
                    "sale_option": "NORMAL",
                }
            ],
        }

        test_cases = [
            ("존재하지 않는 고객", [None], 404),
            (
                "탈퇴한 고객",
                [self.buyer, {"account_status": "WITHDRAWN"}],
                409,
            ),
        ]

        for name, mock_rows, expected_status in test_cases:
            with self.subTest(name=name):
                self.cursor.reset_mock()
                self.conn.reset_mock()
                self.cursor.fetchone.side_effect = mock_rows

                response = self.client.post(
                    "/orders_pay",
                    json=checkout_data,
                )

                self.assertEqual(
                    response.status_code,
                    expected_status,
                )

                self.assertFalse(
                    self.executed("INSERT INTO orders")
                )

                self.conn.rollback.assert_called_once()
                self.conn.commit.assert_not_called()
                self.conn.close.assert_called_once()

    def test_missing_address_cannot_order(self):
        checkout_data = {
            "customer_id": "cus_1",
            "shipping_address": "",
            "items": [
                {
                    "cosmetic_id": "cos_1",
                    "quantity": 2,
                    "sale_option": "NORMAL",
                }
            ],
        }

        response = self.client.post(
            "/orders_pay",
            json=checkout_data,
        )

        self.assertEqual(response.status_code, 422)

        # 요청 데이터 검증 단계에서 차단되어야 함
        self.conn.begin.assert_not_called()
        self.conn.commit.assert_not_called()
        self.conn.rollback.assert_not_called()

    def test_unavailable_or_unpriced_product_cannot_order(self):
        checkout_data = {
            "customer_id": "cus_1",
            "shipping_address": "서울시",
            "items": [
                {
                    "cosmetic_id": "cos_1",
                    "quantity": 2,
                    "sale_option": "NORMAL",
                }
            ],
        }

        test_cases = [
            ("존재하지 않는 상품", None),
            (
                "판매 중단 상품",
                {
                    "cosmetic_name": "크림",
                    "sale_status": "DISCONTINUED",
                    "sale_price": Decimal("1234.50"),
                },
            ),
            (
                "가격 정보 없는 상품",
                {
                    "cosmetic_name": "크림",
                    "sale_status": "ON_SALE",
                    "sale_price": None,
                },
            ),
        ]

        for name, product in test_cases:
            with self.subTest(name=name):
                self.cursor.reset_mock()
                self.conn.reset_mock()

                self.cursor.fetchone.side_effect = [
                    self.buyer,
                    {"account_status": "ACTIVE"},
                    product,
                ]

                # 장바구니에 등록된 상품 없음
                self.cursor.fetchall.return_value = []

                response = self.client.post(
                    "/orders_pay",
                    json=checkout_data,
                )

                self.assertEqual(response.status_code, 409)

                # 주문이 생성되지 않아야 함
                self.assertFalse(
                    self.executed("INSERT INTO orders")
                )

                self.conn.rollback.assert_called_once()
                self.conn.commit.assert_not_called()
                self.conn.close.assert_called_once()

    def test_insufficient_stock_does_not_save_order(self):
        checkout_data = {
            "customer_id": "cus_1",
            "shipping_address": "서울시",
            "items": [
                {
                    "cosmetic_id": "cos_1",
                    "quantity": 2,
                    "sale_option": "NORMAL",
                }
            ],
        }

        self.cursor.fetchone.side_effect = [
            self.buyer,
            {"account_status": "ACTIVE"},
            {
                "cosmetic_name": "크림",
                "sale_status": "ON_SALE",
                "sale_price": Decimal("1234.50"),
            },
            {"seq": 12},
        ]

        self.cursor.fetchall.side_effect = [
            [],  # 장바구니 조회
            [
                {
                    "inventory_id": self.product["inventory_id"],
                    "stock_quantity": 1,
                }
            ],  # 재고 1개, 주문 수량 2개
        ]

        response = self.client.post(
            "/orders_pay",
            json=checkout_data,
        )

        self.assertEqual(response.status_code, 409)

        # 주문 INSERT가 시도되더라도 트랜잭션 전체가 롤백되어야 함
        self.conn.rollback.assert_called_once()
        self.conn.commit.assert_not_called()
        self.conn.close.assert_called_once()

        # 재고 부족이므로 실제 재고 차감과 주문 상품 저장은 실행되지 않음
        self.assertFalse(
            self.executed("UPDATE product_inventory")
        )
        self.assertFalse(
            self.executed("INSERT INTO order_items")
        )

    def test_order_item_failure_rolls_back_stock_and_order(self):
        checkout_data = {
            "customer_id": "cus_1",
            "shipping_address": "서울시",
            "items": [
                {
                    "cosmetic_id": "cos_1",
                    "quantity": 2,
                    "sale_option": "NORMAL",
                }
            ],
        }

        self.cursor.fetchone.side_effect = [
            self.buyer,
            {"account_status": "ACTIVE"},
            {
                "cosmetic_name": "크림",
                "sale_status": "ON_SALE",
                "sale_price": Decimal("1234.50"),
            },
            {"seq": 12},
        ]

        self.cursor.fetchall.side_effect = [
            [],
            [
                {
                    "inventory_id": self.product["inventory_id"],
                    "stock_quantity": 10,
                }
            ],
        ]

        def execute(sql, params=None):
            if "INSERT INTO order_items" in sql:
                raise pymysql.OperationalError(
                    2013,
                    "Lost connection during order item insert",
                )

        self.cursor.execute.side_effect = execute

        response = self.client.post(
            "/orders_pay",
            json=checkout_data,
        )

        self.assertEqual(response.status_code, 500)

        # 주문 생성과 재고 차감이 먼저 시도되었는지 확인
        self.assertTrue(self.executed("INSERT INTO orders"))
        self.assertTrue(self.executed("UPDATE product_inventory"))

        # DB 오류가 발생했으므로 전체 트랜잭션 롤백
        self.conn.rollback.assert_called_once()
        self.conn.commit.assert_not_called()
        self.conn.close.assert_called_once()

    def test_nonpositive_quantity_is_rejected_before_database_access(self):
        for quantity in [0, -1]:
            with self.subTest(quantity=quantity):
                self.conn.reset_mock()

                checkout_data = {
                    "customer_id": "cus_1",
                    "shipping_address": "서울시",
                    "items": [
                        {
                            "cosmetic_id": "cos_1",
                            "quantity": quantity,
                            "sale_option": "NORMAL",
                        }
                    ],
                }

                response = self.client.post(
                    "/orders_pay",
                    json=checkout_data,
                )

                self.assertEqual(response.status_code, 422)

                # 요청 검증 단계에서 차단되므로 DB에 접근하지 않음
                self.conn.begin.assert_not_called()
                self.conn.commit.assert_not_called()
                self.conn.rollback.assert_not_called()

    def test_order_history_returns_rows(self):
        rows = [{"order_id": "ord_1", "quantity": 2, "unit_price": "1234.50"}]
        self.cursor.fetchall.return_value = rows
        self.assertEqual(self.client.get("/orders?customer_id=cus_1").json(), {"results": rows})
        self.conn.close.assert_called_once()


if __name__ == "__main__":
    unittest.main()
