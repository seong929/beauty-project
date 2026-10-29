import os
import time
import unittest
from unittest.mock import MagicMock, patch

import jwt
from fastapi.testclient import TestClient

from main import app
from services.staff import staff_auth_service
from services.admin import outbound_service
from schemas.admin.outbound_schema import OutboundCreateRequest


class AdminAuthorizationTests(unittest.TestCase):
    def setUp(self):
        self.client = TestClient(app)
        self.connection = MagicMock()
        self.cursor = self.connection.cursor.return_value.__enter__.return_value
        self.db_patch = patch.object(staff_auth_service, "get_connection", return_value=self.connection)
        self.db_patch.start()
        self.addCleanup(self.db_patch.stop)
        self.env_patch = patch.dict(os.environ, {"STAFF_JWT_SECRET": "x" * 32})
        self.env_patch.start()
        self.addCleanup(self.env_patch.stop)
        self.token = staff_auth_service.issue_staff_token("E_test")["access_token"]
        self.headers = {"Authorization": f"Bearer {self.token}"}

    def employee(self, role):
        self.cursor.fetchone.return_value = {"employee_id": "E_test", "employee_role": role}

    def test_admin_lists_require_authentication_and_admin_role(self):
        for path in ("/admin/approvals",):
            with self.subTest(path=path):
                self.assertEqual(self.client.get(path).status_code, 401)
                self.employee("STAFF")
                self.assertEqual(self.client.get(path, headers=self.headers).status_code, 403)
        self.employee("ADMIN")
        with patch("routers.admin.approval_router.get_approval_list", return_value=[]):
            self.assertEqual(self.client.get("/admin/approvals", headers=self.headers).status_code, 200)

    def test_returns_are_available_to_authenticated_staff_and_admin(self):
        self.assertEqual(self.client.get("/admin/returns").status_code, 401)
        with patch("routers.admin.return_router.get_return_list", return_value=[]):
            for role in ("STAFF", "ADMIN"):
                self.employee(role)
                self.assertEqual(self.client.get("/admin/returns", headers=self.headers).status_code, 200)

    def test_return_actions_reject_another_employee_identity(self):
        self.employee("ADMIN")
        cases = [
            ("patch", "/admin/returns/r1/decision", {"return_status": "APPROVED"}, "decide_return"),
            ("post", "/admin/returns/r1/pickup", {}, "assign_return_pickup"),
            ("patch", "/admin/returns/r1/pickup-status", {"pickup_status": "COLLECTED"}, "update_return_pickup_status"),
            ("patch", "/admin/returns/r1/receive", {}, "receive_return"),
            ("patch", "/admin/returns/r1/inspection", {"inspection_result": "ok"}, "complete_return_inspection"),
        ]
        for method, path, data, service in cases:
            with self.subTest(path=path):
                body = {**data, "employee_id": "E_other"}
                self.assertEqual(self.client.request(method, path, json=body).status_code, 401)
                for role in ("STAFF", "ADMIN"):
                    self.employee(role)
                    self.assertEqual(self.client.request(method, path, headers=self.headers, json=body).status_code, 403)
                    with patch(f"routers.admin.return_router.{service}", return_value={}) as action:
                        valid_body = {**data, "employee_id": "E_test"}
                        self.assertEqual(self.client.request(method, path, headers=self.headers, json=valid_body).status_code, 200)
                        action.assert_called_once()

    def test_cosmetic_registration_requires_admin_and_matching_identity(self):
        data = {"cosmetic_name": "cream", "manufacturer_id": "m1", "category_id": "c1",
                "employee_id": "E_other", "sale_price": 100, "unit_cost": 50,
                "volume_text": "50ml", "min_stock_qty": 1, "target_stock_qty": 2}
        self.assertEqual(self.client.post("/admin/cosmetics", json=data).status_code, 401)
        self.employee("STAFF")
        self.assertEqual(self.client.post("/admin/cosmetics", json=data, headers=self.headers).status_code, 403)
        self.employee("ADMIN")
        self.assertEqual(self.client.post("/admin/cosmetics", json=data, headers=self.headers).status_code, 403)
        data["employee_id"] = "E_test"
        with patch("routers.admin.cosmetic_router.create_cosmetic", return_value={
            "cosmetic_id": "c1", "registration_id": "reg1", "message": "ok"
        }) as create:
            self.assertEqual(self.client.post("/admin/cosmetics", json=data, headers=self.headers).status_code, 201)
            create.assert_called_once()

    def test_local_web_preflight_allows_authorization(self):
        response = self.client.options("/admin/approvals", headers={
            "Origin": "http://localhost:54321", "Access-Control-Request-Method": "GET",
            "Access-Control-Request-Headers": "authorization",
        })
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.headers["access-control-allow-origin"], "http://localhost:54321")

    def test_expired_token_and_temporary_session_cannot_access_admin_api(self):
        now = int(time.time())
        expired = jwt.encode({"sub": "E_test", "iss": staff_auth_service.JWT_ISSUER,
                              "aud": staff_auth_service.JWT_AUDIENCE,
                              "iat": now - 120, "exp": now - 60}, "x" * 32, algorithm="HS256")
        self.assertEqual(self.client.get("/admin/returns", headers={"Authorization": f"Bearer {expired}"}).status_code, 401)
        self.employee("ADMIN")
        with patch.object(staff_auth_service, "_get_tmp_employee_id", return_value="E_test"):
            self.assertEqual(self.client.get("/admin/returns").status_code, 401)


class OutboundInventoryTests(unittest.TestCase):
    def test_outbound_links_existing_reservation_without_deducting_inventory_again(self):
        connection = MagicMock()
        cursor = connection.cursor.return_value.__enter__.return_value
        cursor.fetchone.side_effect = [
            {"order_id": "o1", "order_status": "PREPARING"}, {"carrier_id": "c1"}, None,
        ]
        cursor.fetchall.return_value = [
            {
                "order_item_id": "oi1",
                "inventory_id": "inv1",
                "purchase_quantity": 2,
                "outbound_quantity": 2,
                "outbound_inventory_id": "inv1",
                "delivery_id": None,
                "outbound_on": None,
            }
        ]
        cursor.rowcount = 1
        with patch.object(outbound_service, "get_connection", return_value=connection):
            result = outbound_service.create_outbound(OutboundCreateRequest(order_id="o1", carrier_id="c1"))
        self.assertEqual(result["order_status"], "SHIPPED")
        queries = [call.args[0].lower() for call in cursor.execute.call_args_list]
        self.assertFalse(any("update product_inventory" in query for query in queries))
        connection.commit.assert_called_once()


if __name__ == "__main__":
    unittest.main()
