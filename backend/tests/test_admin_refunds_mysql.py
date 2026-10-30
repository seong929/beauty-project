"""RUN_MYSQL_REFUND_TEST=1 enables a real JWT/MySQL test with a removable fixture."""
import os
import unittest
from concurrent.futures import ThreadPoolExecutor

from database import get_connection


@unittest.skipUnless(os.getenv("RUN_MYSQL_REFUND_TEST") == "1", "opt-in MySQL test")
class MySQLRefundTests(unittest.TestCase):
    def test_jwt_concurrent_requests_commit_customer_reload_and_cleanup(self):
        from fastapi import FastAPI
        from fastapi.testclient import TestClient
        from routers.admin.return_router import router
        from routers.customer.return_api import router as customer_router
        from routers.delivery.delivery import router as delivery_router
        from services.staff.staff_auth_service import issue_staff_token
        from services.delivery.delivery_auth_service import issue_carrier_token

        app = FastAPI()
        app.include_router(router)
        app.include_router(customer_router)
        app.include_router(delivery_router)
        conn = get_connection()
        inserted = False
        return_id = None
        try:
            with conn.cursor() as q:
                q.execute("SELECT employee_id FROM employees WHERE employee_role = 'ADMIN' LIMIT 1")
                admin = q.fetchone()
                self.assertIsNotNone(admin, "Need an existing admin")
                q.execute("SELECT CURDATE() AS today")
                today = q.fetchone()["today"]
                q.execute("""SELECT oi.order_item_id, o.customer_id, ca.account_id
                    FROM order_items oi JOIN orders o ON o.order_id = oi.order_id
                    JOIN delivery_information d ON d.order_id = o.order_id
                    JOIN carrier_accounts ca ON ca.carrier_id = d.carrier_id
                    WHERE d.delivery_status = 'DELIVERED'
                      AND (SELECT COUNT(DISTINCT d2.carrier_id) FROM delivery_information d2
                           WHERE d2.order_id = o.order_id AND d2.delivery_status = 'DELIVERED') = 1
                    LIMIT 1""")
                item = q.fetchone()
                self.assertIsNotNone(item, "Need a delivered item with one carrier and account")
                q.execute("SELECT COALESCE(MAX(return_seq), 0) + 1 AS seq FROM return_requests WHERE order_item_id = %s", (item["order_item_id"],))
                seq = q.fetchone()["seq"]
                return_id = f"ret_{item['order_item_id']}_{seq}"
                q.execute("""INSERT INTO return_requests
                    (return_id, order_item_id, return_seq, requested_on, return_reason,
                     return_quantity, return_status, pickup_status)
                    VALUES (%s, %s, %s, CURDATE(), 'Internal refund integration fixture',
                            1, 'REQUESTED', 'WAITING')""",
                    (return_id, item["order_item_id"], seq))
            conn.commit()
            inserted = True
            token = issue_staff_token(admin["employee_id"])["access_token"]
            headers = {"Authorization": "Bearer " + token}
            path = f"/admin/returns/{return_id}/refund-status"

            def update(expected, target):
                with TestClient(app) as client:
                    return client.patch(path, headers=headers, json={
                        "employee_id": admin["employee_id"],
                        "expected_refund_status": expected, "refund_status": target,
                    })

            # Exercise the original workflow before testing the new refund stage.
            with TestClient(app) as client:
                base = f"/admin/returns/{return_id}"
                employee_body = {"employee_id": admin["employee_id"]}
                self.assertEqual(update("PENDING", "PROCESSING").status_code, 409)
                response = client.patch(base + "/decision", headers=headers, json={
                    **employee_body, "return_status": "APPROVED",
                })
                self.assertEqual(response.status_code, 200, response.text)
                dates = client.get('/return_requests', params={
                    'customer_id': item['customer_id'], 'order_item_id': item['order_item_id'],
                }).json()['result']
                approved = next(r for r in dates if r['return_id'] == return_id)
                self.assertEqual(approved['approved_on'], today.isoformat())
                self.assertIsNone(approved['inspection_completed_on'])
                response = client.post(base + "/pickup", headers=headers, json=employee_body)
                self.assertEqual(response.status_code, 200, response.text)
                carrier_headers = {"Authorization": "Bearer " + issue_carrier_token(item["account_id"])["access_token"]}
                response = client.patch(f"/delivery/return-pickups/{return_id}/complete", headers=carrier_headers)
                self.assertEqual(response.status_code, 200, response.text)
                response = client.patch(base + "/receive", headers=headers, json=employee_body)
                self.assertEqual(response.status_code, 200, response.text)
                self.assertEqual(update("PENDING", "PROCESSING").status_code, 409)
                response = client.patch(base + "/inspection", headers=headers, json={
                    **employee_body, "inspection_result": "Inspected",
                })
                self.assertEqual(response.status_code, 200, response.text)

            with ThreadPoolExecutor(max_workers=2) as pool:
                futures = [pool.submit(update, "PENDING", "PROCESSING") for _ in range(2)]
                responses = [future.result() for future in futures]
            self.assertEqual(sorted(r.status_code for r in responses), [200, 409])
            successful = next(r for r in responses if r.status_code == 200)
            self.assertFalse(successful.json()["external_refund_performed"])

            def verify_persisted(expected):
                fresh = get_connection()
                try:
                    with fresh.cursor() as q:
                        q.execute("SELECT refund_status, return_status, inspection_result, approved_on, inspection_completed_on FROM return_requests WHERE return_id = %s", (return_id,))
                        row = q.fetchone()
                    self.assertEqual(row["refund_status"], expected)
                    self.assertEqual(row["return_status"], "COMPLETED")
                    self.assertEqual(row["inspection_result"], "Inspected")
                    self.assertEqual(row['approved_on'], today)
                    self.assertEqual(row['inspection_completed_on'], today)
                finally:
                    fresh.close()
                with TestClient(app) as client:
                    response = client.get("/return_requests", params={
                        "customer_id": item["customer_id"], "order_item_id": item["order_item_id"],
                    })
                    self.assertEqual(response.status_code, 200, response.text)
                    row = next(r for r in response.json()["result"] if r["return_id"] == return_id)
                    self.assertEqual(row["refund_status"], expected)
                    self.assertEqual(row['approved_on'], today.isoformat())
                    self.assertEqual(row['inspection_completed_on'], today.isoformat())
                    admin_list = client.get("/admin/returns", headers=headers)
                    self.assertEqual(admin_list.status_code, 200, admin_list.text)
                    self.assertEqual(next(r for r in admin_list.json() if r["return_id"] == return_id)["refund_status"], expected)

            verify_persisted("PROCESSING")
            self.assertEqual(update("PROCESSING", "FAILED").status_code, 200)
            verify_persisted("FAILED")
            self.assertEqual(update("FAILED", "PROCESSING").status_code, 200)
            with ThreadPoolExecutor(max_workers=2) as pool:
                futures = [pool.submit(update, "PROCESSING", "COMPLETED") for _ in range(2)]
                responses = [future.result() for future in futures]
            self.assertEqual(sorted(r.status_code for r in responses), [200, 409])
            verify_persisted("COMPLETED")
            self.assertEqual(update("PROCESSING", "COMPLETED").status_code, 409)
        finally:
            conn.rollback()
            if inserted:
                with conn.cursor() as q:
                    q.execute("DELETE FROM return_pickups WHERE return_id = %s", (return_id,))
                    q.execute("DELETE FROM return_requests WHERE return_id = %s", (return_id,))
                conn.commit()
            conn.close()
