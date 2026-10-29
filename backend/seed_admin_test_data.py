"""관리자 업무의 개발용 데이터를 기존 DB 스키마에 추가한다.

기본 실행은 모든 INSERT를 롤백하는 검증 모드다. --apply를 지정하면 커밋한다.
기존 행을 수정하거나 삭제하지 않으며, 같은 데이터가 있으면 전체 트랜잭션을 롤백한다.
"""
import argparse
import os
from datetime import date, datetime, timedelta
from pathlib import Path

from dotenv import load_dotenv
from pwdlib import PasswordHash

from database import get_connection


TEST_PASSWORD = "BeautyTest!2026"
BASE = 900000001
ADMIN_ID = f"E_manager_{BASE}"
STAFF_ID = f"E_staff_{BASE}"
MANUFACTURER = "mfr_codex_fixture"
CATEGORY = "cat_codex_fixture"
CARRIER = "car_codex_fixture"


def _insert(cursor, table, row):
    # 테이블과 열 이름은 이 모듈의 고정된 값만 전달한다.
    columns = ", ".join(f"`{column}`" for column in row)
    placeholders = ", ".join(["%s"] * len(row))
    cursor.execute(
        f"INSERT INTO `{table}` ({columns}) VALUES ({placeholders})",
        tuple(row.values()),
    )


def create_data(cursor):
    today = date.today()
    password_hash = PasswordHash.recommended().hash(TEST_PASSWORD)
    for role, key_role, employee_id, login_id, name in (
        ("ADMIN", "manager", ADMIN_ID, "fixture_admin", "테스트 관리자"),
        ("STAFF", "staff", STAFF_ID, "fixture_staff", "테스트 직원"),
    ):
        _insert(cursor, "employees", {
            "employee_id": employee_id, "login_id": login_id,
            "password_hash": password_hash, "employee_name": name,
            "employee_role": role, "key_role": key_role,
            "employee_seq": BASE, "hired_on": today,
        })

    _insert(cursor, "manufacturers", {
        "manufacturer_id": MANUFACTURER, "manufacturer_name": "테스트 제조사 (fixture)",
    })
    _insert(cursor, "categories", {
        "category_id": CATEGORY, "category_name": "테스트 카테고리 (fixture)",
    })
    _insert(cursor, "carriers", {
        "carrier_id": CARRIER, "carrier_name": "테스트 배송업체 (fixture)",
    })
    customer_id = "fixture_customer_900000001"
    _insert(cursor, "customers", {
        "customer_id": customer_id, "login_id": "fixture_customer",
        "password_hash": password_hash, "customer_name": "테스트 고객",
        "email": "fixture-customer-900000001@example.invalid",
        "phone": "010-0000-0000", "address": "테스트 주소",
    })

    cosmetics = []
    for index, name in enumerate(("테스트 수분 크림", "테스트 토너", "테스트 선크림"), 1):
        name_seq = BASE + index
        cosmetic_id = f"{MANUFACTURER}_{CATEGORY}_{name_seq}_1"
        cosmetics.append(cosmetic_id)
        _insert(cursor, "cosmetics", {
            "cosmetic_id": cosmetic_id, "cosmetic_name": name,
            "manufacturer_id": MANUFACTURER, "category_id": CATEGORY,
            "cosmetic_name_seq": name_seq, "cosmetic_type_seq": 1,
        })
        _insert(cursor, "product_registrations", {
            "registration_id": f"reg_{BASE + index}", "employee_id": ADMIN_ID,
            "cosmetic_id": cosmetic_id, "registered_on": today,
        })
        for table, prefix, field, value in (
            ("cosmetic_volume_history", "vol", "volume_text", "50ml"),
            ("cosmetic_price_history", "prc", "sale_price", "25000.00"),
            ("cosmetic_cost_history", "cst", "unit_cost", "12000.00"),
            ("cosmetic_sale_status_history", "sls", "sale_status", "ON_SALE"),
            ("cosmetic_min_stock_history", "min", "min_stock_qty", 20),
            ("cosmetic_target_stock_history", "tgt", "target_stock_qty", 100),
        ):
            _insert(cursor, table, {
                "change_id": f"{prefix}_{BASE + index}", "cosmetic_id": cosmetic_id,
                "employee_id": ADMIN_ID, "changed_on": today, field: value,
            })

    approvals = []
    for index, cosmetic_id in enumerate(cosmetics, 1):
        approval_seq = BASE + index
        approval_id = f"pa_{cosmetic_id}_{approval_seq}"
        approvals.append(approval_id)
        is_pending = index == 2
        _insert(cursor, "approvals", {
            "approval_id": approval_id, "cosmetic_id": cosmetic_id, "approval_seq": approval_seq,
            "target_stock_snapshot": 100, "current_stock_snapshot": 0,
            "requested_quantity": 100, "approval_content": "테스트용 재고 보충 품의",
            "requested_on": today - timedelta(days=14),
        })
        _insert(cursor, "approval_status_history", {
            "status_history_id": f"ash_{BASE + index}", "approval_id": approval_id,
            "approval_status": "REQUESTED" if is_pending else "APPROVED",
            "changed_at": datetime.now() - timedelta(days=14),
        })
        _insert(cursor, "approval_decisions", {
            "decision_id": f"dec_{BASE + index}", "employee_id": ADMIN_ID,
            "approval_id": approval_id,
            "decision_status": "PENDING" if is_pending else "APPROVED",
            "decided_at": None if is_pending else datetime.now() - timedelta(days=14),
        })

    purchase_id = f"{approvals[0]}_1"
    _insert(cursor, "purchase_orders", {
        "purchase_order_id": purchase_id, "approval_id": approvals[0],
        "purchase_order_seq": 1, "manufacturer_id": MANUFACTURER,
        "ordered_on": today - timedelta(days=12), "order_quantity": 100,
        "purchase_status": "PARTIALLY_RECEIVED", "unit_supply_price": "12000.00",
        "order_total_amount": "1200000.00",
    })
    inventory_ids = []
    for index, (status, quantity, received) in enumerate((
        ("MAINTAIN", 34, 40), ("HOLD", 20, 20), ("DISCARD", 4, 10),
        ("DISCARD", 0, 5),
    ), 1):
        inbound_id = f"{purchase_id}_{index}"
        inventory_id = f"inv_{inbound_id}"
        inventory_ids.append(inventory_id)
        _insert(cursor, "product_inventory", {
            "inventory_id": inventory_id, "cosmetic_id": cosmetics[0],
            "stock_quantity": quantity, "received_on": today - timedelta(days=10),
            "expires_on": today + timedelta(days=180), "inventory_status": status,
            "sale_option": "NORMAL",
        })
        _insert(cursor, "inbound_history", {
            "inbound_id": inbound_id, "inventory_id": inventory_id,
            "purchase_order_id": purchase_id, "inbound_seq": index,
            "inbound_quantity": received, "inbound_on": today - timedelta(days=10),
        })

    # 구형 스키마에는 예약 출고용 order_item_id와 NULL 허용 컬럼이 없다.
    cursor.execute("SHOW COLUMNS FROM stock_outbounds")
    columns = {row["Field"]: row for row in cursor.fetchall()}
    supports_reservation = (
        "order_item_id" in columns
        and columns["delivery_id"]["Null"] == "YES"
        and columns["outbound_on"]["Null"] == "YES"
    )
    for index, (status, quantity) in enumerate((
        ("PAID", 2), ("PREPARING", 1), ("DELIVERED", 3),
    )):
        order_seq = BASE + index
        order_id = f"ord_{order_seq}"
        item_id = f"{order_id}_1"
        _insert(cursor, "orders", {
            "order_id": order_id, "customer_id": customer_id, "order_seq": order_seq,
            "order_status": status, "ordered_at": datetime.now() - timedelta(days=5 - index),
            "shipping_address": "테스트 배송 주소",
        })
        _insert(cursor, "order_items", {
            "order_item_id": item_id, "order_id": order_id, "order_item_seq": 1,
            "inventory_id": inventory_ids[0], "purchase_quantity": quantity,
            "purchase_unit_price": "25000.00", "sale_option": "NORMAL",
        })
        if status == "DELIVERED":
            delivery_id = f"dlv_{order_id}_1"
            _insert(cursor, "delivery_information", {
                "delivery_id": delivery_id, "order_id": order_id, "delivery_seq": 1,
                "carrier_id": CARRIER, "shipped_at": datetime.now() - timedelta(days=3),
                "arrived_at": datetime.now() - timedelta(days=2), "delivery_status": "DELIVERED",
            })
            outbound = {
                "inventory_id": inventory_ids[0], "delivery_id": delivery_id,
                "outbound_quantity": quantity, "outbound_on": today - timedelta(days=3),
            }
            if "order_item_id" in columns:
                outbound["order_item_id"] = item_id
            _insert(cursor, "stock_outbounds", outbound)
            _insert(cursor, "return_requests", {
                "return_id": f"ret_{item_id}_1", "order_item_id": item_id, "return_seq": 1,
                "requested_on": today, "return_reason": "테스트 반품 신청",
                "return_quantity": 1, "return_status": "REQUESTED",
                "refund_status": "PENDING", "pickup_status": "WAITING",
            })
        elif supports_reservation:
            _insert(cursor, "stock_outbounds", {
                "order_item_id": item_id, "inventory_id": inventory_ids[0],
                "delivery_id": None, "outbound_quantity": quantity, "outbound_on": None,
            })
    return supports_reservation


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true", help="검증 후 트랜잭션 커밋")
    parser.add_argument("--env-file", help="DB 설정이 담긴 dotenv 파일 경로")
    args = parser.parse_args()
    if args.env_file:
        load_dotenv(Path(args.env_file), override=True)
    elif Path(__file__).with_name(".env").exists():
        load_dotenv(Path(__file__).with_name(".env"), override=False)
    if not os.getenv("DB_USER") or not os.getenv("DB_NAME"):
        parser.error("DB_USER와 DB_NAME을 환경변수 또는 backend/.env에 설정해야 합니다.")

    conn = get_connection()
    try:
        with conn.cursor() as cursor:
            supports_reservation = create_data(cursor)
        if args.apply:
            conn.commit()
            print("테스트 데이터가 생성되었습니다.")
        else:
            conn.rollback()
            print("검증 성공: 테스트 INSERT를 모두 롤백했습니다. 저장하려면 --apply를 사용하세요.")
        print("관리자: fixture_admin / 직원: fixture_staff / 비밀번호: " + TEST_PASSWORD)
        print("제조사:", MANUFACTURER, "카테고리:", CATEGORY, "배송업체:", CARRIER)
        if not supports_reservation:
            print("현재 stock_outbounds는 예약 출고를 지원하지 않아 PAID/PREPARING 출고 시나리오는 사용할 수 없습니다. 스키마는 변경하지 않았습니다.")
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


if __name__ == "__main__":
    main()
