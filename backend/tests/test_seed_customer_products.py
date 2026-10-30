import json
import unittest
from unittest.mock import MagicMock, patch

import seed_customer_products as seed


class CustomerProductSeedTests(unittest.TestCase):
    def setUp(self):
        self.data = json.loads(seed.MANIFEST.read_text(encoding='utf-8'))

    def test_all_uploaded_products_have_complete_values_and_keep_ui_prices(self):
        seed.validate_manifest(self.data)
        self.assertEqual(len(self.data['products']), 30)
        products = {p['cosmetic_name']: p for p in self.data['products']}
        self.assertEqual(products['1025 독도 로션']['sale_price'], 23900)
        self.assertEqual(products['1025 독도 토너']['sale_price'], 16900)
        for product in products.values():
            self.assertEqual(product['sale_price'], seed.preview_price(product['cosmetic_name'], product['category']))
            self.assertEqual(product['initial_stock'], 100)
        self.assertEqual({p['category'] for p in products.values()}, {'스킨', '로션', '크림'})

    def test_invalid_or_duplicate_data_is_rejected_before_connecting(self):
        for data in [
            {'bucket': seed.BUCKET, 'products': []},
            {**self.data, 'products': [self.data['products'][0]] * 2},
            {**self.data, 'products': [{**self.data['products'][0], 'initial_stock': -1}]},
        ]:
            with patch.object(seed, 'get_connection') as connect:
                with self.assertRaises(ValueError):
                    seed.run_seed(data, apply=True)
                connect.assert_not_called()

    def test_failed_transaction_rolls_back_and_closes_connection(self):
        conn = MagicMock()
        conn.cursor.return_value.__enter__.return_value.fetchone.return_value = {'acquired': 1}
        with patch.object(seed, 'get_connection', return_value=conn), patch.object(seed, 'seed_products', side_effect=ValueError('write failed')):
            with self.assertRaises(ValueError):
                seed.run_seed(self.data, apply=True)
        conn.rollback.assert_called_once()
        conn.commit.assert_not_called()
        conn.close.assert_called_once()

    def test_repeated_seed_does_not_change_existing_product_or_stock(self):
        cursor = MagicMock()
        cursor.fetchone.return_value = {'employee_id': 'E_manager_1'}
        cursor.fetchall.return_value = [{'cosmetic_id': 'existing_sku'}]
        data = {**self.data, 'products': [self.data['products'][0]]}
        with patch.object(seed, '_lookup', side_effect=lambda *args: args[4]), patch.object(seed, '_insert') as insert, patch.object(seed, 'generate_cosmetic_id') as allocate:
            result = seed.seed_products(cursor, data)
        self.assertEqual(result[0]['status'], 'existing')
        self.assertEqual(result[0]['cosmetic_id'], 'existing_sku')
        insert.assert_not_called()
        allocate.assert_not_called()


if __name__ == '__main__':
    unittest.main()
