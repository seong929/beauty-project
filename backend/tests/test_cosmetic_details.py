import unittest
from decimal import Decimal
from unittest.mock import MagicMock, patch

from fastapi import HTTPException
from fastapi.testclient import TestClient
from main import app
from schemas.admin.cosmetic_schema import CosmeticDetailsUpdate
from services.admin import cosmetic_details_service as service
from services.staff import staff_auth_service


PAYLOAD = {'sale_price': '1250.75', 'unit_cost': '500.25', 'min_stock_qty': 5,
           'target_stock_qty': 90, 'volume_text': '55ml', 'sale_status': 'DISCONTINUED'}
CURRENT = {'cosmetic_id': 'c1', 'cosmetic_name': 'cream', 'manufacturer_id': 'm1', 'category_id': 'cat1',
           'sale_price': Decimal('1000'), 'unit_cost': Decimal('400'), 'min_stock_qty': 10,
           'target_stock_qty': 100, 'volume_text': '50ml', 'sale_status': 'ON_SALE'}


class DetailsApiTests(unittest.TestCase):
    def test_admin_only_updates_and_staff_can_read(self):
        client = TestClient(app)
        path = '/admin/cosmetics/c1'
        self.assertEqual(client.patch(path, json=PAYLOAD).status_code, 401)
        app.dependency_overrides[staff_auth_service.require_staff] = lambda: {'employee_id': 'E1', 'employee_role': 'STAFF'}
        app.dependency_overrides[staff_auth_service.bearer_scheme] = lambda: object()
        try:
            self.assertEqual(client.patch(path, json=PAYLOAD).status_code, 403)
            with patch('routers.staff.staff_cosmetics_related.get_cosmetic_details', return_value=CURRENT):
                self.assertEqual(client.get('/staff/cosmetics/c1/detail').status_code, 200)
            app.dependency_overrides[staff_auth_service.require_staff] = lambda: {'employee_id': 'E1', 'employee_role': 'ADMIN'}
            with patch('routers.admin.cosmetic_router.update_cosmetic_details', return_value={}) as update:
                self.assertEqual(client.patch(path, json=PAYLOAD).status_code, 200)
                self.assertEqual(update.call_args.args[1], 'E1')
                self.assertEqual(update.call_args.args[2].sale_price, Decimal('1250.75'))
            self.assertEqual(client.patch(path, json={**PAYLOAD, 'target_stock_qty': 1}).status_code, 422)
        finally:
            app.dependency_overrides.clear()


class DetailsTransactionTests(unittest.TestCase):
    def setUp(self):
        self.conn = MagicMock()
        self.cursor = self.conn.cursor.return_value.__enter__.return_value
        self.cursor.fetchall.return_value = [{'cosmetic_id': 'c1'}]
        self.cursor.fetchone.return_value = None
        self.data = CosmeticDetailsUpdate(**PAYLOAD)

    def run_update(self):
        with patch.object(service, 'get_connection', return_value=self.conn), \
             patch.object(service, '_read_details', return_value=CURRENT), \
             patch.object(service, '_allocate_id', side_effect=lambda c, scope, table, col, prefix: prefix+'10'):
            return service.update_cosmetic_details('c1', 'E1', self.data)

    def test_all_six_changes_share_one_transaction_and_actor(self):
        self.run_update()
        inserts = [call for call in self.cursor.execute.call_args_list if 'INSERT INTO' in call.args[0]]
        self.assertEqual(len(inserts), 6)
        self.assertTrue(all(call.args[1][1:3] == ('c1', 'E1') for call in inserts))
        self.conn.commit.assert_called_once()
        self.conn.rollback.assert_not_called()

    def test_history_failure_rolls_back_every_field(self):
        def execute(sql, *args):
            if 'INSERT INTO cosmetic_target_stock_history' in sql:
                raise RuntimeError('write failed')
        self.cursor.execute.side_effect = execute
        with self.assertRaises(RuntimeError): self.run_update()
        self.conn.commit.assert_not_called()
        self.conn.rollback.assert_called_once()

    def test_duplicate_current_volume_is_rejected(self):
        self.cursor.fetchone.return_value = {'cosmetic_id': 'other-option'}
        with self.assertRaises(HTTPException) as error: self.run_update()
        self.assertEqual(error.exception.status_code, 409)
        self.conn.commit.assert_not_called()

    def test_unchanged_values_do_not_create_new_history(self):
        self.data = CosmeticDetailsUpdate(**{key: CURRENT[key] for key in PAYLOAD})
        self.run_update()
        self.assertFalse(any('INSERT INTO' in call.args[0] for call in self.cursor.execute.call_args_list))
        self.conn.commit.assert_called_once()


if __name__ == '__main__': unittest.main()
