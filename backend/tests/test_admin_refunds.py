import datetime
import unittest
from unittest.mock import MagicMock, patch

import pymysql
from fastapi import FastAPI
from fastapi.testclient import TestClient

from routers.admin.return_router import router
from services.admin import return_service
from services.staff.staff_auth_service import require_authenticated_staff


class AdminRefundTests(unittest.TestCase):
    def setUp(self):
        self.app = FastAPI()
        self.app.include_router(router)
        self.client = TestClient(self.app)
        self.employee = {"employee_id": "emp_admin", "employee_role": "ADMIN"}
        self.app.dependency_overrides[require_authenticated_staff] = lambda: self.employee
        self.conn = MagicMock()
        self.cursor = self.conn.cursor.return_value.__enter__.return_value
        self.cursor.rowcount = 1
        self.row = {
            "return_status": "COMPLETED", "pickup_status": "COLLECTED",
            "headquarters_received_on": datetime.date(2026, 10, 30),
            "inspection_result": "Inspected", "refund_status": "PENDING",
        }
        self.cursor.fetchone.side_effect = [self.employee, self.row]
        connection_patch = patch.object(return_service, "get_connection", return_value=self.conn)
        connection_patch.start()
        self.addCleanup(connection_patch.stop)

    def update(self, **extra):
        return self.client.patch("/admin/returns/ret_test/refund-status", json={
            "employee_id": "emp_admin", "expected_refund_status": "PENDING",
            "refund_status": "PROCESSING", **extra,
        })

    def test_requires_real_authentication(self):
        self.app.dependency_overrides.clear()
        self.assertEqual(self.update().status_code, 401)
        self.conn.cursor.assert_not_called()

    def test_staff_and_spoofed_employee_rejected(self):
        self.employee = {"employee_id": "emp_staff", "employee_role": "STAFF"}
        self.assertEqual(self.update().status_code, 403)
        self.employee = {"employee_id": "emp_admin", "employee_role": "ADMIN"}
        self.assertEqual(self.update(employee_id="emp_other").status_code, 403)
        self.conn.cursor.assert_not_called()

    def test_service_rechecks_admin_role(self):
        self.cursor.fetchone.side_effect = [{"employee_role": "STAFF"}]
        self.assertEqual(self.update().status_code, 403)
        self.conn.rollback.assert_called_once()

    def test_start_commits_internal_status_only(self):
        response = self.update()
        self.assertEqual(response.status_code, 200, response.text)
        self.assertFalse(response.json()["external_refund_performed"])
        self.assertEqual(response.json()["refund_status"], "PROCESSING")
        role, lock, update = self.cursor.execute.call_args_list
        self.assertIn("FOR UPDATE", lock.args[0])
        self.assertEqual(update.args[1], ("PROCESSING", "ret_test", "PENDING"))
        self.assertNotIn("SET return_status", update.args[0])
        self.assertNotIn("UPDATE orders", update.args[0])
        self.conn.commit.assert_called_once()
        self.conn.close.assert_called_once()

    def test_fail_and_retry_are_allowed(self):
        for current, target in [("PROCESSING", "FAILED"), ("FAILED", "PROCESSING")]:
            with self.subTest(current=current):
                self.row["refund_status"] = current
                self.cursor.fetchone.side_effect = [self.employee, self.row]
                response = self.update(expected_refund_status=current, refund_status=target)
                self.assertEqual(response.status_code, 200)
                self.assertEqual(response.json()["previous_refund_status"], current)

    def test_uninspected_or_inconsistent_return_rejected(self):
        for field, value in [
            ("return_status", "REQUESTED"), ("return_status", "APPROVED"),
            ("return_status", "COLLECTING"), ("return_status", "INSPECTING"),
            ("pickup_status", "SCHEDULED"), ("headquarters_received_on", None),
            ("inspection_result", None), ("inspection_result", "  "),
        ]:
            with self.subTest(field=field, value=value):
                row = {**self.row, field: value}
                self.cursor.fetchone.side_effect = [self.employee, row]
                self.assertEqual(self.update().status_code, 409)
        self.conn.commit.assert_not_called()

    def test_duplicate_stale_terminal_and_illegal_transitions_rejected(self):
        for current, expected, target in [
            ("PROCESSING", "PENDING", "PROCESSING"),
            ("PROCESSING", "PROCESSING", "PROCESSING"),
            ("FAILED", "PENDING", "PROCESSING"),
            ("PENDING", "PENDING", "FAILED"),
            ("COMPLETED", "FAILED", "PROCESSING"),
        ]:
            with self.subTest(current=current, expected=expected):
                self.cursor.fetchone.side_effect = [self.employee, {**self.row, "refund_status": current}]
                self.assertEqual(self.update(expected_refund_status=expected, refund_status=target).status_code, 409)
        self.conn.commit.assert_not_called()

    def test_external_completion_and_unknown_fields_not_accepted(self):
        self.assertEqual(self.update(refund_status="COMPLETED").status_code, 422)
        self.assertEqual(self.update(refund_status="PENDING").status_code, 422)
        self.assertEqual(self.update(external_refund_performed=True).status_code, 422)
        self.conn.cursor.assert_not_called()

    def test_missing_return(self):
        self.cursor.fetchone.side_effect = [self.employee, None]
        self.assertEqual(self.update().status_code, 404)
        self.conn.rollback.assert_called_once()

    def test_failed_compare_and_set_rolls_back(self):
        self.cursor.rowcount = 0
        self.assertEqual(self.update().status_code, 409)
        self.conn.rollback.assert_called_once()
        self.conn.commit.assert_not_called()

    def test_database_error_rolls_back(self):
        self.cursor.execute.side_effect = [None, None, pymysql.OperationalError(1205, "timeout")]
        client = TestClient(self.app, raise_server_exceptions=False)
        response = client.patch("/admin/returns/ret_test/refund-status", json={
            "employee_id": "emp_admin", "expected_refund_status": "PENDING", "refund_status": "PROCESSING",
        })
        self.assertEqual(response.status_code, 500)
        self.conn.rollback.assert_called_once()
        self.conn.commit.assert_not_called()
