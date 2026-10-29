import re
import unittest
from unittest.mock import MagicMock

from pwdlib import PasswordHash

from seed_admin_test_data import TEST_PASSWORD, create_data


class SeedTests(unittest.TestCase):
    def rows(self, supports_reservation):
        cursor = MagicMock()
        cursor.fetchall.return_value = [
            {"Field": "inventory_id", "Null": "NO"},
            {"Field": "delivery_id", "Null": "YES" if supports_reservation else "NO"},
            {"Field": "outbound_on", "Null": "YES" if supports_reservation else "NO"},
            *([{"Field": "order_item_id", "Null": "NO"}] if supports_reservation else []),
        ]
        self.assertEqual(create_data(cursor), supports_reservation)
        result = {}
        for call in cursor.execute.call_args_list:
            sql = call.args[0]
            if not sql.startswith("INSERT INTO"):
                self.assertEqual(sql, "SHOW COLUMNS FROM stock_outbounds")
                continue
            table, columns = re.match(r"INSERT INTO `([^`]+)` \((.*?)\) VALUES", sql).groups()
            keys = re.findall(r"`([^`]+)`", columns)
            result.setdefault(table, []).append(dict(zip(keys, call.args[1])))
        return result

    def test_fixture_is_consistent_and_reserves_orders_when_supported(self):
        rows = self.rows(True)
        self.assertEqual({row["employee_role"] for row in rows["employees"]}, {"ADMIN", "STAFF"})
        self.assertTrue(PasswordHash.recommended().verify(TEST_PASSWORD, rows["employees"][0]["password_hash"]))
        self.assertEqual(sum(r["inbound_quantity"] for r in rows["inbound_history"]), 75)
        self.assertEqual(rows["purchase_orders"][0]["order_quantity"], 100)
        self.assertEqual({r["inventory_status"] for r in rows["product_inventory"]}, {"MAINTAIN", "HOLD", "DISCARD"})
        self.assertEqual(len(rows["stock_outbounds"]), 3)
        self.assertEqual(sum(r["outbound_quantity"] for r in rows["stock_outbounds"]), 6)
        self.assertEqual(len(rows["return_requests"]), 1)

    def test_legacy_schema_does_not_insert_invalid_reservations(self):
        rows = self.rows(False)
        self.assertEqual(len(rows["stock_outbounds"]), 1)
        self.assertIsNotNone(rows["stock_outbounds"][0]["delivery_id"])
        self.assertNotIn("order_item_id", rows["stock_outbounds"][0])


if __name__ == "__main__":
    unittest.main()
