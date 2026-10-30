"""Firebase 고객 상품 30개의 임시 판매 데이터를 기존 스키마에 추가한다.

기본 실행은 검증 후 롤백한다. --apply로 저장한다. 기존 상품은 수정하지 않으며,
재실행해도 판매로 줄어든 재고를 다시 채우지 않는다. 고객·주문 데이터는 만들지 않는다.
"""
import argparse
import json
import re
from collections import Counter
from datetime import datetime, timedelta, timezone
from pathlib import Path
from urllib.parse import urlencode
from urllib.request import urlopen

from database import get_connection
from services.admin.cosmetic_service import generate_cosmetic_id
from services.system.automatic_approval_service import _allocate_id

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / 'database' / 'seeds' / 'firebase_customer_products.json'
REPORT = ROOT / 'database' / 'seeds' / 'firebase_customer_products_applied.json'
BUCKET = 'beauty-skin-20e94.firebasestorage.app'
MANUFACTURER_ID = 'mfr_sodam_demo'
MANUFACTURER_NAME = '소담 임시 상품 제조사'
CATEGORIES = {'스킨': 'cat_sodam_skin', '로션': 'cat_sodam_lotion', '크림': 'cat_sodam_cream'}
KST = timezone(timedelta(hours=9))


def product_type(name):
    value = name.lower()
    if re.search(r'선크림|썬크림|선로션|샴푸|틴트|클렌|테스트|sunscreen|shampoo|tint|cleanser', value):
        return None
    for pattern, category in [(r'크림|cream', '크림'), (r'로션|에멀전|lotion|emulsion', '로션'), (r'토너|스킨(?!케어)|toner|\bskin\b', '스킨')]:
        if re.search(pattern, value):
            return category
    return None


def preview_price(name, category):
    # Dart String.codeUnits와 동일하게 UTF-16 단위로 계산해 현재 화면 가격을 보존한다.
    encoded = name.encode('utf-16-le')
    total = sum(int.from_bytes(encoded[i:i + 2], 'little') for i in range(0, len(encoded), 2))
    return {'스킨': 15000, '로션': 18000, '크림': 22000}[category] + (total % 8) * 1000 + 900


def fetch_manifest():
    rows, tokens = [], set()
    token = None
    while True:
        query = {'maxResults': '1000', 'delimiter': '/'}
        if token:
            query['pageToken'] = token
        url = f'https://firebasestorage.googleapis.com/v0/b/{BUCKET}/o?{urlencode(query)}'
        with urlopen(url, timeout=20) as response:
            data = json.load(response)
        rows.extend(data.get('items', []))
        token = data.get('nextPageToken')
        if not token:
            break
        if token in tokens:
            raise ValueError('Firebase 페이지 토큰이 반복됩니다.')
        tokens.add(token)
    products = []
    for row in sorted(rows, key=lambda item: item['name']):
        filename = row['name']
        if '/' in filename or not re.search(r'\.(png|jpe?g|webp|gif)$', filename, re.I):
            continue
        name = re.sub(r'\.(png|jpe?g|webp|gif)$', '', filename, flags=re.I).strip()
        category = product_type(name)
        if category is None:
            continue
        price = preview_price(name, category)
        products.append({
            'image_object': filename, 'cosmetic_name': name, 'category': category,
            'volume_text': {'스킨': '200ml', '로션': '150ml', '크림': '50ml'}[category],
            'sale_price': price, 'unit_cost': price // 2, 'initial_stock': 100,
        })
    return {'bucket': BUCKET, 'description': '개발용 임시 가격·용량·재고. 실제 제조사 정보가 아님.', 'products': products}


def validate_manifest(data):
    if data.get('bucket') != BUCKET or not data.get('products'):
        raise ValueError('Firebase 상품 목록과 버킷을 확인하세요.')
    names, images = set(), set()
    for product in data['products']:
        name, image = product['cosmetic_name'], product['image_object']
        if not name or len(name) > 200 or name in names or image in images:
            raise ValueError('빈 상품명이나 중복된 상품·이미지가 있습니다.')
        if product['category'] not in CATEGORIES or product_type(name) != product['category']:
            raise ValueError('스킨·로션·크림만 등록할 수 있습니다.')
        if not product['volume_text'] or not isinstance(product['initial_stock'], int) or not 1 <= product['initial_stock'] <= 100000:
            raise ValueError('용량과 초기 재고를 확인하세요.')
        if not isinstance(product['sale_price'], int) or not 0 < product['sale_price'] <= 100000000:
            raise ValueError('판매 가격을 확인하세요.')
        if not isinstance(product['unit_cost'], int) or not 0 <= product['unit_cost'] <= product['sale_price']:
            raise ValueError('상품 원가를 확인하세요.')
        names.add(name)
        images.add(image)


def _insert(cursor, table, row):
    # 테이블·열 이름은 아래 코드의 상수만 사용한다. 값은 모두 바인딩한다.
    columns = ', '.join(f'`{column}`' for column in row)
    cursor.execute(f'INSERT INTO `{table}` ({columns}) VALUES ({", ".join(["%s"] * len(row))})', tuple(row.values()))


def _history_id(cursor, table, column, prefix):
    return _allocate_id(cursor, f'history:{table}', table, column, prefix)


def _lookup(cursor, table, id_column, name_column, key, name):
    cursor.execute(f'SELECT `{id_column}`, `{name_column}` FROM `{table}` WHERE `{id_column}`=%s OR `{name_column}`=%s FOR UPDATE', (key, name))
    rows = cursor.fetchall()
    if not rows:
        _insert(cursor, table, {id_column: key, name_column: name})
        return key
    if len(rows) != 1 or rows[0][name_column] != name:
        raise ValueError(f'{table}: 기존 코드와 이름이 충돌합니다.')
    return rows[0][id_column]


def seed_products(cursor, data):
    validate_manifest(data)
    cursor.execute("SELECT employee_id FROM employees WHERE employee_role='ADMIN' ORDER BY employee_id LIMIT 1")
    employee = cursor.fetchone()
    if employee is None:
        raise ValueError('상품 등록 이력에 사용할 기존 관리자가 필요합니다.')
    actor = employee['employee_id']
    manufacturer = _lookup(cursor, 'manufacturers', 'manufacturer_id', 'manufacturer_name', MANUFACTURER_ID, MANUFACTURER_NAME)
    categories = {name: _lookup(cursor, 'categories', 'category_id', 'category_name', key, name) for name, key in CATEGORIES.items()}
    now = datetime.now(KST).replace(tzinfo=None)
    today = now.date()
    results = []
    for product in data['products']:
        name = product['cosmetic_name']
        cursor.execute('SELECT cosmetic_id FROM cosmetics WHERE manufacturer_id=%s AND cosmetic_name=%s FOR UPDATE', (manufacturer, name))
        existing = cursor.fetchall()
        if len(existing) > 1:
            raise ValueError(f'동일 상품의 옵션을 확인하세요: {name}')
        if existing:
            results.append({**product, 'cosmetic_id': existing[0]['cosmetic_id'], 'status': 'existing'})
            continue
        category = categories[product['category']]
        cosmetic_id, name_seq, type_seq = generate_cosmetic_id(cursor, manufacturer, category, name)
        _insert(cursor, 'cosmetics', {'cosmetic_id': cosmetic_id, 'cosmetic_name': name,
            'manufacturer_id': manufacturer, 'category_id': category,
            'cosmetic_name_seq': name_seq, 'cosmetic_type_seq': type_seq})
        _insert(cursor, 'product_registrations', {
            'registration_id': _history_id(cursor, 'product_registrations', 'registration_id', 'reg_'),
            'employee_id': actor, 'cosmetic_id': cosmetic_id, 'registered_on': today})
        for table, prefix, field, value in [
            ('cosmetic_volume_history', 'vol_', 'volume_text', product['volume_text']),
            ('cosmetic_price_history', 'prc_', 'sale_price', product['sale_price']),
            ('cosmetic_cost_history', 'cst_', 'unit_cost', product['unit_cost']),
            ('cosmetic_sale_status_history', 'sls_', 'sale_status', 'ON_SALE'),
            ('cosmetic_min_stock_history', 'min_', 'min_stock_qty', min(20, product['initial_stock'])),
            ('cosmetic_target_stock_history', 'tgt_', 'target_stock_qty', product['initial_stock']),
        ]:
            _insert(cursor, table, {'change_id': _history_id(cursor, table, 'change_id', prefix),
                'cosmetic_id': cosmetic_id, 'employee_id': actor, 'changed_on': today, field: value})
        # 신규 상품에만 초기 품의·발주·입고를 연결한다. 이미 판매된 재고는 다시 만들지 않는다.
        quantity = product['initial_stock']
        approval_id = f'pa_{cosmetic_id}_1'
        purchase_id = f'{approval_id}_1'
        inbound_id = f'{purchase_id}_1'
        inventory_id = f'inv_{inbound_id}'
        _insert(cursor, 'approvals', {'approval_id': approval_id, 'cosmetic_id': cosmetic_id,
            'approval_seq': 1, 'target_stock_snapshot': quantity, 'current_stock_snapshot': 0,
            'requested_quantity': quantity, 'approval_content': 'Firebase 고객 상품 초기 임시 재고', 'requested_on': today})
        for status in ['REQUESTED', 'APPROVED']:
            _insert(cursor, 'approval_status_history', {
                'status_history_id': _history_id(cursor, 'approval_status_history', 'status_history_id', 'ash_'),
                'approval_id': approval_id, 'approval_status': status, 'changed_at': now})
        _insert(cursor, 'approval_decisions', {
            'decision_id': _history_id(cursor, 'approval_decisions', 'decision_id', 'dec_'),
            'employee_id': actor, 'approval_id': approval_id, 'decision_status': 'APPROVED', 'decided_at': now})
        _insert(cursor, 'purchase_orders', {'purchase_order_id': purchase_id, 'approval_id': approval_id,
            'purchase_order_seq': 1, 'manufacturer_id': manufacturer, 'ordered_on': today,
            'order_quantity': quantity, 'purchase_status': 'RECEIVED', 'unit_supply_price': product['unit_cost'],
            'order_total_amount': product['unit_cost'] * quantity})
        _insert(cursor, 'product_inventory', {'inventory_id': inventory_id, 'cosmetic_id': cosmetic_id,
            'stock_quantity': quantity, 'received_on': today, 'expires_on': today + timedelta(days=730),
            'inventory_status': 'MAINTAIN', 'sale_option': 'NORMAL'})
        _insert(cursor, 'inbound_history', {'inbound_id': inbound_id, 'inventory_id': inventory_id,
            'purchase_order_id': purchase_id, 'inbound_seq': 1, 'inbound_quantity': quantity, 'inbound_on': today})
        results.append({**product, 'cosmetic_id': cosmetic_id, 'inventory_id': inventory_id, 'status': 'created'})
    return results


def run_seed(data, apply=False):
    validate_manifest(data)
    conn = get_connection()
    locked = False
    try:
        with conn.cursor() as cursor:
            cursor.execute("SELECT GET_LOCK('seed:sodam-firebase-products', 10) AS acquired")
            locked = cursor.fetchone()['acquired'] == 1
            if not locked:
                raise RuntimeError('다른 상품 등록 작업이 진행 중입니다.')
            conn.begin()
            results = seed_products(cursor, data)
        if apply:
            conn.commit()
        else:
            conn.rollback()
        return results
    except Exception:
        conn.rollback()
        raise
    finally:
        try:
            if locked:
                with conn.cursor() as cursor:
                    cursor.execute("SELECT RELEASE_LOCK('seed:sodam-firebase-products')")
        finally:
            conn.close()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true')
    parser.add_argument('--manifest', type=Path, default=MANIFEST)
    parser.add_argument('--refresh-manifest', action='store_true', help='Firebase에서 현재 사진 목록과 임시 표시 값을 가져온다')
    args = parser.parse_args()
    if args.refresh_manifest:
        data = fetch_manifest()
        validate_manifest(data)
        args.manifest.parent.mkdir(parents=True, exist_ok=True)
        args.manifest.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    else:
        data = json.loads(args.manifest.read_text(encoding='utf-8'))
    results = run_seed(data, apply=args.apply)
    if args.apply:
        REPORT.write_text(json.dumps({'applied_at': datetime.now(KST).isoformat(), 'products': results}, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'committed': args.apply, 'products': len(results), 'categories': dict(Counter(p['category'] for p in results)), 'results': dict(Counter(p['status'] for p in results))}, ensure_ascii=True))


if __name__ == '__main__':
    main()

# 변경 내용(2026-10-30): 현 스키마에 Firebase 상품·가격·용량·판매 상태·초기 입고 재고를 원자적으로 추가한다.
