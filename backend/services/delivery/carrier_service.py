
from fastapi import HTTPException
from pymysql.err import IntegrityError

from database import get_connection
from schemas.delivery.carrier_schema import CarrierCreateRequest


def create_carrier(data: CarrierCreateRequest):
    conn = get_connection()

    try:
        with conn.cursor() as cursor:
            # 1. 배송업체 ID 중복 확인
            cursor.execute(
                """
                SELECT carrier_id
                FROM carriers
                WHERE carrier_id = %s
                """,
                (data.carrier_id,),
            )

            if cursor.fetchone() is not None:
                raise HTTPException(
                    status_code=409,
                    detail="이미 등록된 배송업체 ID입니다.",
                )

            # 2. 배송업체명 중복 확인
            cursor.execute(
                """
                SELECT carrier_id
                FROM carriers
                WHERE carrier_name = %s
                """,
                (data.carrier_name,),
            )

            if cursor.fetchone() is not None:
                raise HTTPException(
                    status_code=409,
                    detail="이미 등록된 배송업체명입니다.",
                )

            # 3. 배송업체 등록
            cursor.execute(
                """
                INSERT INTO carriers (
                    carrier_id,
                    carrier_name,
                    phone
                )
                VALUES (%s, %s, %s)
                """,
                (
                    data.carrier_id,
                    data.carrier_name,
                    data.phone,
                ),
            )

        # 4. 정상 등록 시 저장
        conn.commit()

        return {
            "carrier_id": data.carrier_id,
            "carrier_name": data.carrier_name,
            "phone": data.phone,
            "message": "배송업체 등록이 완료되었습니다.",
        }

    except IntegrityError:
        conn.rollback()
        raise HTTPException(
            status_code=409,
            detail="이미 등록된 배송업체 정보입니다.",
        )

    except Exception:
        conn.rollback()
        raise

    finally:
        conn.close()
