import unittest
from unittest.mock import MagicMock, patch

import pymysql
from fastapi import FastAPI
from fastapi.testclient import TestClient
from routers.customer import customer, customer_categories_search


class CustomerSignupFieldsTests(unittest.TestCase):
    def setUp(self):
        app = FastAPI()
        app.include_router(customer.router)
        app.include_router(customer_categories_search.router)
        self.client = TestClient(app)
        self.conn = MagicMock()
        self.cursor = self.conn.cursor.return_value.__enter__.return_value
        self.patch = patch.object(customer, 'get_connection', return_value=self.conn)
        self.patch.start()
        self.addCleanup(self.patch.stop)
        self.form = {'customer_id': 'cus_test', 'login_id': 'signup', 'password': 'secret123',
                     'customer_name': '테스트', 'email': 'test@example.com', 'address': '서울시', 'phone': '01012345678'}

    def test_available_id_returns_only_trimmed_id_and_availability(self):
        self.cursor.fetchone.return_value = None
        response = self.client.get('/customer_login_id_available', params={'login_id': ' new_id '})
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json(), {'result': 'OK', 'login_id': 'new_id', 'available': True})
        self.assertEqual(self.cursor.execute.call_args.args[1], ('new_id',))
        self.conn.commit.assert_not_called()
        self.conn.close.assert_called_once()

    def test_existing_id_is_unavailable_without_customer_details(self):
        self.cursor.fetchone.return_value = {'found': 1}
        response = self.client.get('/customer_login_id_available', params={'login_id': 'used'})
        self.assertEqual(response.json(), {'result': 'OK', 'login_id': 'used', 'available': False})

    def test_invalid_ids_do_not_query_database(self):
        for value in ['', 'x', '  ', 'x' * 51]:
            response = self.client.get('/customer_login_id_available', params={'login_id': value})
            self.assertEqual(response.status_code, 422)
        self.assertEqual(self.cursor.execute.call_count, 0)

    def test_id_lookup_database_error_is_service_error(self):
        self.cursor.execute.side_effect = pymysql.OperationalError(2006, 'private database details')
        response = self.client.get('/customer_login_id_available', params={'login_id': 'new_id'})
        self.assertEqual(response.status_code, 503)
        self.assertNotIn('private', response.text)
        self.conn.close.assert_called_once()

    def test_signup_saves_gender_and_postal_address_without_birth_year(self):
        self.cursor.fetchone.return_value = {'seq': 1}
        response = self.client.post('/customer_upload', data={**self.form, 'gender': 'F', 'birth_year': '1997', 'address': '서울시' * 80})
        self.assertEqual(response.status_code, 200)
        inserts = [call.args for call in self.cursor.execute.call_args_list if 'INSERT INTO customers' in call.args[0]]
        self.assertNotIn('birth_year', inserts[0][0])
        self.assertEqual(inserts[0][1][-1], 'F')
        self.assertEqual(len(inserts[0][1]), 8)
        self.conn.commit.assert_called_once()

    def test_invalid_gender_is_rejected_before_any_database_write(self):
        for extra in [{'gender': 'UNKNOWN'}]:
            response = self.client.post('/customer_upload', data={**self.form, **extra})
            self.assertEqual(response.status_code, 422)
        self.assertEqual(self.cursor.execute.call_count, 0)

    def test_profile_updates_gender_without_reading_or_writing_birth_year(self):
        self.cursor.fetchone.return_value = {'customer_id': 'cus_test', 'gender': 'M', 'birth_year': 1990}
        fields = {'customer_name': '테스트', 'email': 'test@example.com', 'address': '서울시', 'phone': '01012345678'}
        response = self.client.put('/customer_update', params={'customer_id': 'cus_test'}, data={**fields, 'gender': 'F', 'birth_year': 1997})
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()['gender'], 'F')
        self.assertNotIn('birth_year', response.json())
        self.assertEqual(self.cursor.execute.call_args.args[1][-2:], ('F', 'cus_test'))
        for call in self.cursor.execute.call_args_list:
            self.assertNotIn('birth_year', call.args[0])

    def test_old_profile_client_preserves_existing_gender(self):
        self.cursor.fetchone.return_value = {'customer_id': 'cus_test', 'gender': 'M', 'birth_year': 1990}
        response = self.client.put('/customer_update', params={'customer_id': 'cus_test'}, data={'customer_name': '테스트', 'email': 'test@example.com', 'address': '서울시', 'phone': '01012345678'})
        self.assertEqual(response.status_code, 200)
        self.assertEqual(self.cursor.execute.call_args.args[1][-2:], ('M', 'cus_test'))

    def test_catalog_inventory_matches_normal_payment_option(self):
        with patch.object(customer_categories_search, 'get_connection', return_value=self.conn):
            self.cursor.fetchall.return_value = []
            response = self.client.get('/customers_categories_search')
        self.assertEqual(response.status_code, 200)
        self.assertIn("sale_option = 'NORMAL'", self.cursor.execute.call_args.args[0])


# 변경 내용(2026-10-30): 중복 확인·인구통계 저장·호환성·실제 결제 옵션 재고 범위를 검증한다.
if __name__ == '__main__':
    unittest.main()
