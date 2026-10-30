import unittest
from decimal import Decimal
from unittest.mock import MagicMock, patch

from fastapi import HTTPException
from fastapi import FastAPI
from fastapi.testclient import TestClient

from main import app
from schemas.admin.approval_schema import ApprovalDecisionRequest
from services.admin import approval_service
from services.staff import staff_auth_service
from services.system import automatic_approval_service
from routers.admin import approval_router


class ApprovalListCostTests(unittest.TestCase):
    def test_list_includes_decimal_cost_and_supports_missing_history(self):
        app = FastAPI()
        app.include_router(approval_router.router)
        app.dependency_overrides[approval_router.require_admin] = lambda: {"employee_role": "ADMIN"}
        row = {
            "approval_id": "a1", "cosmetic_id": "c1", "cosmetic_name": "Cream",
            "approval_seq": 1, "target_stock_snapshot": 100, "current_stock_snapshot": 20,
            "requested_quantity": 80, "approval_content": "Low stock", "requested_on": "2026-10-30",
        }
        for cost in (Decimal("500.25"), None):
            with self.subTest(cost=cost), patch.object(approval_router, "get_approval_list", return_value=[{**row, "unit_cost": cost}]):
                response = TestClient(app).get("/admin/approvals")
                self.assertEqual(response.status_code, 200, response.text)
                self.assertEqual(response.json()[0]["unit_cost"], "500.25" if cost is not None else None)


class ApprovalOrderTests(unittest.TestCase):
    def setUp(self):
        self.conn = MagicMock()
        self.cursor = self.conn.cursor.return_value.__enter__.return_value
        self.cursor.fetchone.side_effect = [
            {"employee_role": "ADMIN"},
            {"approval_id": "a1", "manufacturer_id": "m1"},
            {"approval_status": "REQUESTED"}, None,
        ]
        self.cursor.fetchall.return_value = [{"decision_id": "d1", "employee_id": "E_other"}]
        self.cursor.rowcount = 1
        self.data = ApprovalDecisionRequest(employee_id="E_admin", decision_status="APPROVED",
                                            manufacturer_id="m1", order_quantity=17, unit_supply_price=Decimal("120.50"))

    def run_decision(self):
        with patch.object(approval_service, "get_connection", return_value=self.conn), \
             patch.object(approval_service, "_allocate_id", return_value="ash_123"):
            return approval_service.decide_approval("a1", self.data)

    def test_approval_and_selected_quantity_commit_together(self):
        result = self.run_decision()
        self.assertEqual(result["purchase_order_id"], "a1_1")
        insert = next(call for call in self.cursor.execute.call_args_list
                      if "INSERT INTO purchase_orders" in call.args[0])
        self.assertEqual(insert.args[1], ("a1_1", "a1", "m1", 17, Decimal("120.50"), Decimal("2048.50")))
        self.conn.commit.assert_called_once()
        self.conn.rollback.assert_not_called()

    def test_failed_order_rolls_back_approval(self):
        def execute(sql, *args):
            if "INSERT INTO purchase_orders" in sql:
                raise RuntimeError("database failure")
        self.cursor.execute.side_effect = execute
        with self.assertRaises(RuntimeError):
            self.run_decision()
        self.conn.rollback.assert_called_once()
        self.conn.commit.assert_not_called()

    def test_wrong_supplier_cannot_approve(self):
        self.data.manufacturer_id = "m2"
        with self.assertRaises(HTTPException) as error:
            self.run_decision()
        self.assertEqual(error.exception.status_code, 400)
        self.conn.rollback.assert_called_once()
        self.conn.commit.assert_not_called()

    def test_approval_requires_order_details(self):
        with self.assertRaises(ValueError):
            ApprovalDecisionRequest(employee_id="E_admin", decision_status="APPROVED")
        self.assertEqual(ApprovalDecisionRequest(employee_id="E_admin", decision_status="REJECTED").decision_status, "REJECTED")


class AutomaticApprovalTests(unittest.TestCase):
    def test_scans_all_products_not_only_existing_approvals(self):
        conn = MagicMock()
        cursor = conn.cursor.return_value.__enter__.return_value
        cursor.fetchall.return_value = [{"cosmetic_id": "new_product"}]
        with patch.object(automatic_approval_service, "get_connection", return_value=conn), \
             patch.object(automatic_approval_service, "_process_cosmetic", return_value={"result": "SUFFICIENT"}) as process:
            result = automatic_approval_service.create_automatic_approvals()
        self.assertIn("FROM cosmetics", cursor.execute.call_args.args[0])
        process.assert_called_once_with("new_product")
        self.assertEqual(result["checked_count"], 1)

    def test_application_starts_and_stops_scheduler(self):
        with patch('main.start_daily_approval_scheduler', return_value='handle') as start, \
             patch('main.stop_daily_approval_scheduler') as stop:
            with TestClient(app) as client:
                self.assertEqual(client.get('/health').status_code, 200)
            start.assert_called_once()
            stop.assert_called_once_with('handle')


class ManufacturerApiTests(unittest.TestCase):
    def test_manufacturer_registration_requires_admin(self):
        client = TestClient(app)
        data = {"manufacturer_name": "example", "phone": "010"}
        self.assertEqual(client.post("/admin/manufacturers", json=data).status_code, 401)
        app.dependency_overrides[staff_auth_service.require_staff] = lambda: {"employee_id": "E1", "employee_role": "STAFF"}
        app.dependency_overrides[staff_auth_service.bearer_scheme] = lambda: object()
        try:
            self.assertEqual(client.post("/admin/manufacturers", json=data).status_code, 403)
            app.dependency_overrides[staff_auth_service.require_staff] = lambda: {"employee_id": "E1", "employee_role": "ADMIN"}
            conn = MagicMock()
            with patch("routers.admin.manufacturer_router.get_connection", return_value=conn):
                response = client.post("/admin/manufacturers", json=data)
            self.assertEqual(response.status_code, 201)
            self.assertTrue(response.json()["manufacturer_id"].startswith("mfr_"))
            conn.commit.assert_called_once()
        finally:
            app.dependency_overrides.clear()

    def test_approval_requires_details_and_admin_role(self):
        client = TestClient(app)
        app.dependency_overrides[staff_auth_service.bearer_scheme] = lambda: object()
        app.dependency_overrides[staff_auth_service.require_staff] = lambda: {"employee_id": "E1", "employee_role": "STAFF"}
        data = {"employee_id": "E1", "decision_status": "APPROVED", "manufacturer_id": "m1", "order_quantity": 8, "unit_supply_price": "2.50"}
        try:
            self.assertEqual(client.patch('/admin/approvals/a1/decision', json=data).status_code, 403)
            app.dependency_overrides[staff_auth_service.require_staff] = lambda: {"employee_id": "E1", "employee_role": "ADMIN"}
            self.assertEqual(client.patch('/admin/approvals/a1/decision', json={"employee_id": "E1", "decision_status": "APPROVED"}).status_code, 422)
            with patch('routers.admin.approval_router.decide_approval', return_value={"purchase_order_id": "a1_1"}) as decide:
                self.assertEqual(client.patch('/admin/approvals/a1/decision', json=data).status_code, 200)
                self.assertEqual(decide.call_args.args[1].order_quantity, 8)
        finally:
            app.dependency_overrides.clear()


if __name__ == "__main__":
    unittest.main()
