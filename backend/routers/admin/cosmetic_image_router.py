from fastapi import APIRouter, Depends, HTTPException, File, UploadFile

from database import get_connection
from services.admin.cosmetic_image_service import get_image_info, upload_image, MAX_IMAGE_BYTES
from services.staff.staff_auth_service import require_admin, require_authenticated_staff

router = APIRouter(tags=['화장품 이미지'])


def _require_cosmetic(cosmetic_id):
    conn = get_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute('SELECT cosmetic_id FROM cosmetics WHERE cosmetic_id=%s', (cosmetic_id,))
            if cursor.fetchone() is None:
                raise HTTPException(status_code=404, detail='화장품을 찾을 수 없습니다.')
    finally:
        conn.close()


@router.get('/staff/cosmetics/{cosmetic_id}/image')
def read_cosmetic_image(cosmetic_id: str, employee: dict = Depends(require_authenticated_staff)):
    _require_cosmetic(cosmetic_id)
    return get_image_info(cosmetic_id)


@router.post('/admin/cosmetics/{cosmetic_id}/image')
def upload_cosmetic_image(cosmetic_id: str, file: UploadFile = File(...), employee: dict = Depends(require_admin)):
    _require_cosmetic(cosmetic_id)
    try:
        content = file.file.read(MAX_IMAGE_BYTES + 1)
        return upload_image(cosmetic_id, content, file.filename or '')
    finally:
        file.file.close()
