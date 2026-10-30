import os
import unittest
from unittest.mock import MagicMock, patch

from fastapi import FastAPI
from fastapi.testclient import TestClient

from routers.system import automatic_purchase_approval_router as api


class AutomaticApprovalApiTests(unittest.TestCase):
    def setUp(self):
        self.app = FastAPI()
        self.app.include_router(api.router)
        self.result = {"checked_count": 1, "created_count": 1, "error_count": 0, "results": []}

    def test_manual_run_works_with_test_flag_disabled_or_unset(self):
        for flag in (None, "0"):
            with self.subTest(flag=flag), patch.dict(os.environ), \
                    patch.object(api, "create_automatic_approvals", return_value=self.result) as create:
                os.environ.pop("AUTO_APPROVAL_TEST_API_ENABLED", None)
                if flag is not None:
                    os.environ["AUTO_APPROVAL_TEST_API_ENABLED"] = flag
                client = TestClient(self.app, client=("127.0.0.1", 50000))
                response = client.post("/system/automatic-approvals/run")
                self.assertEqual(response.status_code, 200, response.text)
                self.assertEqual(response.json(), self.result)
                create.assert_called_once_with()

    def test_list_and_status_work_with_test_flag_disabled(self):
        conn = MagicMock()
        cursor = conn.cursor.return_value.__enter__.return_value
        cursor.fetchone.return_value = {"total": 1}
        cursor.fetchall.return_value = [{"approval_id": "a1"}]
        with patch.dict(os.environ, {"AUTO_APPROVAL_TEST_API_ENABLED": "0"}), \
                patch.object(api, "get_connection", return_value=conn), \
                patch.object(api, "read_daily_run_status", return_value={"scheduler_enabled": True}):
            client = TestClient(self.app, client=("::1", 50000))
            response = client.get("/system/automatic-approvals", params={"page": 2, "count": 10})
            self.assertEqual(response.status_code, 200, response.text)
            self.assertEqual(response.json()["items"], [{"approval_id": "a1"}])
            self.assertEqual(cursor.execute.call_args.args[1], (10, 10))
            conn.close.assert_called_once()
            self.assertEqual(client.get("/system/automatic-approvals/status").json(), {"scheduler_enabled": True})

    def test_nonlocal_clients_cannot_read_or_run_even_with_forwarded_local_address(self):
        with patch.object(api, "create_automatic_approvals") as create, \
                patch.object(api, "get_connection") as connect, \
                patch.object(api, "read_daily_run_status") as status:
            for host in ("192.168.1.2", "203.0.113.1"):
                client = TestClient(self.app, client=(host, 50000))
                for method, path in (("GET", ""), ("GET", "/status"), ("POST", "/run")):
                    with self.subTest(host=host, path=path):
                        response = client.request(method, "/system/automatic-approvals" + path,
                                                  headers={"X-Forwarded-For": "127.0.0.1"})
                        self.assertEqual(response.status_code, 403, response.text)
            create.assert_not_called()
            connect.assert_not_called()
            status.assert_not_called()
