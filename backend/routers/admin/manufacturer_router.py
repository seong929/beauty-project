from uuid import uuid4

import pymysql
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, ConfigDict, Field

from database import get_connection
from services.staff.staff_auth_service import require_admin


router = APIRouter(prefix="/admin/manufacturers", tags=["본사 관리자 - 발주처"])


class ManufacturerCreate(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True, extra="forbid")
    manufacturer_name: str = Field(min_length=1, max_length=150)
    phone: str | None = Field(default=None, max_length=30)


@router.get("")
def list_manufacturers(employee: dict = Depends(require_admin)):
    conn = get_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute("SELECT manufacturer_id, manufacturer_name, phone FROM manufacturers ORDER BY manufacturer_name, manufacturer_id")
            return cursor.fetchall()
    finally:
        conn.close()


@router.post("", status_code=201)
def register_manufacturer(data: ManufacturerCreate, employee: dict = Depends(require_admin)):
    manufacturer_id = f"mfr_{uuid4().hex}"
    conn = get_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute("INSERT INTO manufacturers (manufacturer_id, manufacturer_name, phone) VALUES (%s, %s, %s)",
                           (manufacturer_id, data.manufacturer_name, data.phone or None))
        conn.commit()
        return {"manufacturer_id": manufacturer_id, "manufacturer_name": data.manufacturer_name, "phone": data.phone or None}
    except pymysql.IntegrityError as exc:
        conn.rollback()
        if exc.args and exc.args[0] == 1062:
            raise HTTPException(status_code=409, detail="이미 등록된 발주처 이름입니다.") from None
        raise
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()
