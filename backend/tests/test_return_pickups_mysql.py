"""Opt-in real MySQL + JWT integration; deletes its fixture in finally."""
import os
import unittest
from database import get_connection

@unittest.skipUnless(os.getenv('RUN_MYSQL_PICKUP_TEST') == '1', 'opt-in MySQL test')
class MySQLPickupTests(unittest.TestCase):
    def test_commit_and_reload_through_authenticated_api(self):
        from fastapi import FastAPI
        from fastapi.testclient import TestClient
        from routers.delivery.delivery import router
        from services.delivery.delivery_auth_service import issue_carrier_token
        app = FastAPI()
        app.include_router(router)
        client = TestClient(app)
        return_id = None
        conn = get_connection()
        try:
            with conn.cursor() as q:
                q.execute("SELECT ca.account_id, ca.carrier_id, oi.order_item_id FROM carrier_accounts ca CROSS JOIN order_items oi LIMIT 1")
                seed = q.fetchone()
                self.assertIsNotNone(seed, 'Need one carrier account and order item')
                q.execute('SELECT COALESCE(MAX(return_seq), 0) + 1 AS seq FROM return_requests WHERE order_item_id = %s', (seed['order_item_id'],))
                seq = q.fetchone()['seq']
                return_id = f"ret_{seed['order_item_id']}_{seq}"
                q.execute("""INSERT INTO return_requests
                    (return_id, order_item_id, return_seq, requested_on, return_reason,
                     return_quantity, return_status, pickup_status, pickup_requested_on)
                    VALUES (%s, %s, %s, CURDATE(), 'Automated pickup integration fixture',
                            1, 'COLLECTING', 'SCHEDULED', CURDATE())""",
                    (return_id, seed['order_item_id'], seq))
                q.execute('INSERT INTO return_pickups (return_id, carrier_id) VALUES (%s, %s)', (return_id, seed['carrier_id']))
            conn.commit()
            headers = {'Authorization': 'Bearer ' + issue_carrier_token(seed['account_id'])['access_token']}
            response = client.get('/delivery/return-pickups', headers=headers)
            self.assertEqual(response.status_code, 200, response.text)
            self.assertTrue(any(r['return_id'] == return_id for r in response.json()))
            response = client.patch(f'/delivery/return-pickups/{return_id}/complete', headers=headers)
            self.assertEqual(response.status_code, 200, response.text)
            fresh = get_connection()
            try:
                with fresh.cursor() as q:
                    q.execute('SELECT pickup_status, pickup_completed_on, return_status, refund_status FROM return_requests WHERE return_id = %s', (return_id,))
                    row = q.fetchone()
                self.assertEqual(row['pickup_status'], 'COLLECTED')
                self.assertIsNotNone(row['pickup_completed_on'])
                self.assertEqual(row['return_status'], 'COLLECTING')
                self.assertEqual(row['refund_status'], 'PENDING')
            finally:
                fresh.close()
            reloaded = client.get('/delivery/return-pickups', headers=headers)
            saved = next(r for r in reloaded.json() if r['return_id'] == return_id)
            self.assertEqual(saved['pickup_status'], 'COLLECTED')
            self.assertEqual(client.patch(f'/delivery/return-pickups/{return_id}/complete', headers=headers).status_code, 409)
        finally:
            conn.rollback()
            if return_id:
                with conn.cursor() as q:
                    q.execute('DELETE FROM return_pickups WHERE return_id = %s', (return_id,))
                    q.execute('DELETE FROM return_requests WHERE return_id = %s', (return_id,))
                conn.commit()
            conn.close()
