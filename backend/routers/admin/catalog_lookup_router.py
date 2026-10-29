from fastapi import APIRouter, Depends

from database import get_connection
from services.staff.staff_auth_service import require_admin, require_authenticated_staff

router = APIRouter(tags=["업무 선택 목록"])


@router.get('/staff/carriers')
def list_carriers(employee: dict = Depends(require_authenticated_staff)):
    conn = get_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute('SELECT carrier_id, carrier_name FROM carriers ORDER BY carrier_name, carrier_id')
            return cursor.fetchall()
    finally:
        conn.close()


@router.get('/admin/categories')
def list_categories(employee: dict = Depends(require_admin)):
    conn = get_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute('SELECT category_id, category_name FROM categories ORDER BY category_name, category_id')
            return cursor.fetchall()
    finally:
        conn.close()
