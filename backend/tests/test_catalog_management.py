import unittest
from unittest.mock import MagicMock, patch

from fastapi.testclient import TestClient
from main import app
from services.admin import cosmetic_service
from services.staff import staff_auth_service


class CatalogPermissionsTests(unittest.TestCase):
    def setUp(self):
        self.client = TestClient(app)
        self.conn = MagicMock()
        self.cursor = self.conn.cursor.return_value.__enter__.return_value
        self.addCleanup(app.dependency_overrides.clear)

    def role(self, role):
        app.dependency_overrides[staff_auth_service.require_staff] = lambda: {'employee_id': 'E_staff_1', 'employee_role': role}
        app.dependency_overrides[staff_auth_service.bearer_scheme] = lambda: object()

    def test_carrier_lookup_is_available_to_staff_and_categories_only_to_admin(self):
        self.assertEqual(self.client.get('/staff/carriers').status_code, 401)
        self.assertEqual(self.client.get('/admin/categories').status_code, 401)
        with patch('routers.admin.catalog_lookup_router.get_connection', return_value=self.conn):
            self.role('STAFF')
            self.cursor.fetchall.return_value = [{'carrier_id': 'car_1', 'carrier_name': 'carrier'}]
            self.assertEqual(self.client.get('/staff/carriers').json()[0]['carrier_id'], 'car_1')
            self.assertEqual(self.client.get('/admin/categories').status_code, 403)
            self.role('ADMIN')
            self.cursor.fetchall.return_value = [{'category_id': 'cat_1', 'category_name': 'category'}]
            self.assertEqual(self.client.get('/admin/categories').json()[0]['category_id'], 'cat_1')

    def test_sale_status_change_uses_authenticated_admin(self):
        payload = {'sale_status': 'DISCONTINUED'}
        path = '/admin/cosmetics/c1/sale-status'
        self.assertEqual(self.client.patch(path, json=payload).status_code, 401)
        self.role('STAFF')
        self.assertEqual(self.client.patch(path, json=payload).status_code, 403)
        self.role('ADMIN')
        with patch('routers.admin.cosmetic_router.change_sale_status', return_value={}) as change:
            self.assertEqual(self.client.patch(path, json=payload).status_code, 200)
            change.assert_called_once_with('c1', 'E_staff_1', 'DISCONTINUED')
            self.assertEqual(self.client.patch(path, json={'sale_status': 'INVALID'}).status_code, 422)


class SaleHistoryTests(unittest.TestCase):
    def test_appends_history_and_rolls_back_on_failure(self):
        for fail in (False, True):
            with self.subTest(fail=fail):
                conn = MagicMock()
                cursor = conn.cursor.return_value.__enter__.return_value
                cursor.fetchone.side_effect = [{'cosmetic_id': 'c1'}, {'sale_status': 'ON_SALE'}]
                def execute(sql, *args):
                    if fail and 'INSERT INTO cosmetic_sale_status_history' in sql:
                        raise RuntimeError('write failed')
                cursor.execute.side_effect = execute
                with patch.object(cosmetic_service, 'get_connection', return_value=conn), patch.object(cosmetic_service, '_allocate_id', return_value='sls_12'):
                    if fail:
                        with self.assertRaises(RuntimeError): cosmetic_service.change_sale_status('c1', 'E1', 'DISCONTINUED')
                        conn.rollback.assert_called_once()
                        conn.commit.assert_not_called()
                    else:
                        cosmetic_service.change_sale_status('c1', 'E1', 'DISCONTINUED')
                        conn.commit.assert_called_once()
                        self.assertEqual(cursor.execute.call_args.args[1], ('sls_12', 'c1', 'E1', 'DISCONTINUED'))

    def test_same_status_does_not_append_duplicate_history(self):
        conn = MagicMock()
        cursor = conn.cursor.return_value.__enter__.return_value
        cursor.fetchone.side_effect = [{'cosmetic_id': 'c1'}, {'sale_status': 'ON_SALE'}]
        with patch.object(cosmetic_service, 'get_connection', return_value=conn), patch.object(cosmetic_service, '_allocate_id') as allocate:
            cosmetic_service.change_sale_status('c1', 'E1', 'ON_SALE')
        allocate.assert_not_called()
        conn.commit.assert_called_once()


if __name__ == '__main__': unittest.main()
