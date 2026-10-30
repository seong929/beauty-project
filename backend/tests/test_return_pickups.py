import unittest
from unittest.mock import MagicMock, patch
from fastapi import FastAPI
from fastapi.testclient import TestClient
from routers.delivery.delivery import router
from services.delivery.delivery_auth_service import require_carrier
from services.delivery import return_pickup_service as service
from services.delivery.delivery_service import update_delivery_status
from schemas.delivery.delivery_schema import DeliveryStatusUpdateRequest

class ReturnPickupTests(unittest.TestCase):
    def setUp(self):
        self.app = FastAPI()
        self.app.include_router(router)
        self.client = TestClient(self.app)
        self.conn = MagicMock()
        self.cursor = self.conn.cursor.return_value.__enter__.return_value
        self.cursor.rowcount = 1
        self.cursor.fetchone.return_value = {'return_status': 'COLLECTING', 'pickup_status': 'SCHEDULED'}
        p = patch.object(service, 'get_connection', return_value=self.conn)
        p.start()
        self.addCleanup(p.stop)

    def auth(self):
        self.app.dependency_overrides[require_carrier] = lambda: {'carrier_id': 'car_1'}

    def test_authentication_required(self):
        self.assertEqual(self.client.get('/delivery/return-pickups').status_code, 401)
        self.assertEqual(self.client.patch('/delivery/return-pickups/ret_1/complete').status_code, 401)
        self.conn.cursor.assert_not_called()

    def test_list_scoped_to_carrier(self):
        self.auth()
        self.cursor.fetchall.return_value = []
        self.assertEqual(self.client.get('/delivery/return-pickups').json(), [])
        sql, args = self.cursor.execute.call_args.args
        self.assertIn('rp.carrier_id = %s', sql)
        self.assertEqual(args, ('car_1',))

    def test_complete_only_pickup_fields(self):
        self.auth()
        response = self.client.patch('/delivery/return-pickups/ret_1/complete')
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()['pickup_status'], 'COLLECTED')
        lock, update = self.cursor.execute.call_args_list
        self.assertIn('FOR UPDATE', lock.args[0])
        self.assertEqual(lock.args[1], ('ret_1', 'car_1'))
        self.assertIn("pickup_status = 'COLLECTED'", update.args[0])
        self.assertNotIn('refund_status', update.args[0])
        self.assertNotIn('SET return_status', update.args[0])
        self.conn.commit.assert_called_once()

    def test_other_carrier_or_missing_return(self):
        self.auth()
        self.cursor.fetchone.return_value = None
        self.assertEqual(self.client.patch('/delivery/return-pickups/ret_1/complete').status_code, 404)
        self.conn.commit.assert_not_called()
        self.conn.rollback.assert_called_once()

    def test_invalid_and_duplicate_transitions(self):
        self.auth()
        for status, pickup in [('REQUESTED', 'WAITING'), ('APPROVED', 'WAITING'), ('COLLECTING', 'COLLECTED'), ('INSPECTING', 'COLLECTED'), ('COLLECTING', 'FAILED')]:
            self.cursor.fetchone.return_value = {'return_status': status, 'pickup_status': pickup}
            self.assertEqual(self.client.patch('/delivery/return-pickups/ret_1/complete').status_code, 409)
        self.conn.commit.assert_not_called()

    def test_failed_write_rolls_back(self):
        self.auth()
        self.cursor.rowcount = 0
        self.assertEqual(self.client.patch('/delivery/return-pickups/ret_1/complete').status_code, 409)
        self.conn.rollback.assert_called_once()

    def test_existing_delivery_start_and_complete(self):
        for current, target in [('READY', 'IN_TRANSIT'), ('IN_TRANSIT', 'DELIVERED')]:
            conn = MagicMock()
            cursor = conn.cursor.return_value.__enter__.return_value
            cursor.rowcount = 1
            cursor.fetchone.side_effect = [{'order_id': 'ord_1', 'delivery_status': current}, {'remaining_count': 0}]
            with patch('services.delivery.delivery_service.get_connection', return_value=conn):
                result = update_delivery_status('del_1', DeliveryStatusUpdateRequest(delivery_status=target), 'car_1')
            self.assertEqual(result['delivery_status'], target)
            conn.commit.assert_called_once()
