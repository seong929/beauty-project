from fastapi import HTTPException

from database import get_connection
from schemas.admin.cosmetic_schema import CosmeticDetailsUpdate
from services.system.automatic_approval_service import _allocate_id

# 식별자는 서버 내부의 고정된 목록만 사용한다.
HISTORIES = (
    ('cosmetic_price_history', 'sale_price', 'prc_'),
    ('cosmetic_cost_history', 'unit_cost', 'cst_'),
    ('cosmetic_min_stock_history', 'min_stock_qty', 'min_'),
    ('cosmetic_target_stock_history', 'target_stock_qty', 'tgt_'),
    ('cosmetic_volume_history', 'volume_text', 'vol_'),
    ('cosmetic_sale_status_history', 'sale_status', 'sls_'),
)


def _read_details(cursor, cosmetic_id):
    values = []
    for table, field, _ in HISTORIES:
        values.append(f'''(SELECT h.{field} FROM {table} h WHERE h.cosmetic_id=c.cosmetic_id
                         ORDER BY h.changed_on DESC, CAST(SUBSTRING(h.change_id, 5) AS UNSIGNED) DESC LIMIT 1) AS {field}''')
    cursor.execute('SELECT c.cosmetic_id, c.cosmetic_name, c.manufacturer_id, c.category_id, '
                   + ', '.join(values) + ' FROM cosmetics c WHERE c.cosmetic_id=%s', (cosmetic_id,))
    result = cursor.fetchone()
    if result is None:
        raise HTTPException(status_code=404, detail='상품 옵션을 찾을 수 없습니다.')
    return result


def get_cosmetic_details(cosmetic_id):
    conn = get_connection()
    try:
        with conn.cursor() as cursor:
            return _read_details(cursor, cosmetic_id)
    finally:
        conn.close()


def update_cosmetic_details(cosmetic_id: str, employee_id: str, data: CosmeticDetailsUpdate):
    conn = get_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute('''SELECT c.cosmetic_id FROM cosmetics c
                              JOIN cosmetics selected ON selected.manufacturer_id=c.manufacturer_id
                                AND selected.category_id=c.category_id AND selected.cosmetic_name=c.cosmetic_name
                              WHERE selected.cosmetic_id=%s ORDER BY c.cosmetic_id FOR UPDATE''', (cosmetic_id,))
            if not cursor.fetchall():
                raise HTTPException(status_code=404, detail='상품 옵션을 찾을 수 없습니다.')
            current = _read_details(cursor, cosmetic_id)
            if current['volume_text'] != data.volume_text:
                cursor.execute('''SELECT c.cosmetic_id FROM cosmetics c
                                  WHERE c.manufacturer_id=%s AND c.category_id=%s
                                    AND c.cosmetic_name=%s AND c.cosmetic_id<>%s
                                    AND (SELECT h.volume_text FROM cosmetic_volume_history h
                                         WHERE h.cosmetic_id=c.cosmetic_id
                                         ORDER BY h.changed_on DESC, CAST(SUBSTRING(h.change_id,5) AS UNSIGNED) DESC LIMIT 1)=%s
                                  LIMIT 1''', (current['manufacturer_id'], current['category_id'], current['cosmetic_name'], cosmetic_id, data.volume_text))
                if cursor.fetchone() is not None:
                    raise HTTPException(status_code=409, detail='같은 상품에 동일한 용량의 옵션이 이미 있습니다.')
            for table, field, prefix in HISTORIES:
                value = getattr(data, field)
                if current[field] == value:
                    continue
                change_id = _allocate_id(cursor, f'history:{table}', table, 'change_id', prefix)
                cursor.execute(f'''INSERT INTO {table} (change_id, cosmetic_id, employee_id, changed_on, {field})
                                   VALUES (%s, %s, %s, CURDATE(), %s)''', (change_id, cosmetic_id, employee_id, value))
            result = _read_details(cursor, cosmetic_id)
        conn.commit()
        return result
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()
