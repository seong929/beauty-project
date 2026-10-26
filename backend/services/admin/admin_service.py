from fastapi import HTTPException

from database import get_connection
from datetime import date
from schemas.admin.admin_schema import CosmeticCreateRequest


def generate_cosmetic_id(
    cursor,
    manufacturer_id: str,
    category_id: str,
    cosmetic_name: str,
):
    # 제조사 + 카테고리 단위의 잠금 범위
    name_scope = f"cosmetic_name:{manufacturer_id}:{category_id}"

    # 해당 범위의 카운터 행 생성
    cursor.execute(
        """
        INSERT INTO id_counters (scope_name, `last_value`)
        VALUES (%s, 0)
        ON DUPLICATE KEY UPDATE
            `last_value` = `last_value`
        """,
        (name_scope,),
    )

    # 같은 제조사 + 카테고리의 상품명 순번 발급을 직렬화
    cursor.execute(
        """
        SELECT `last_value`
        FROM id_counters
        WHERE scope_name = %s
        FOR UPDATE
        """,
        (name_scope,),
    )

    current_name_seq = cursor.fetchone()["last_value"]

    # 기존에 등록된 동일 상품명 확인
    cursor.execute(
        """
        SELECT cosmetic_name_seq
        FROM cosmetics
        WHERE manufacturer_id = %s
          AND category_id = %s
          AND cosmetic_name = %s
        LIMIT 1
        """,
        (manufacturer_id, category_id, cosmetic_name),
    )

    existing = cursor.fetchone()

    if existing:
        name_seq = existing["cosmetic_name_seq"]

    else:
        name_seq = current_name_seq + 1

        cursor.execute(
            """
            UPDATE id_counters
            SET `last_value` = %s
            WHERE scope_name = %s
            """,
            (name_seq, name_scope),
        )

    # 동일 상품명 묶음의 종류 순번
    type_scope = (
        f"cosmetic_type:{manufacturer_id}:"
        f"{category_id}:{name_seq}"
    )

    cursor.execute(
        """
        INSERT INTO id_counters (scope_name, `last_value`)
        VALUES (%s, LAST_INSERT_ID(1))
        ON DUPLICATE KEY UPDATE
            `last_value` = LAST_INSERT_ID(`last_value` + 1)
        """,
        (type_scope,),
    )

    cursor.execute("SELECT LAST_INSERT_ID() AS seq")
    type_seq = cursor.fetchone()["seq"]

    cosmetic_id = (
        f"{manufacturer_id}_{category_id}_{name_seq}_{type_seq}"
    )

    return cosmetic_id, name_seq, type_seq


def create_cosmetic(
    data: CosmeticCreateRequest,
):
    conn = get_connection()

    try:
        with conn.cursor() as cursor:
            # 1. 제조사 존재 여부 확인
            cursor.execute(
                """
                SELECT manufacturer_id
                FROM manufacturers
                WHERE manufacturer_id = %s
                """,
                (data.manufacturer_id,),
            )

            if cursor.fetchone() is None:
                raise HTTPException(
                    status_code=404,
                    detail="존재하지 않는 제조사입니다.",
                )

            # 2. 카테고리 존재 여부 확인
            cursor.execute(
                """
                SELECT category_id
                FROM categories
                WHERE category_id = %s
                """,
                (data.category_id,),
            )

            if cursor.fetchone() is None:
                raise HTTPException(
                    status_code=404,
                    detail="존재하지 않는 카테고리입니다.",
                )

            # 3. 관리자 권한 확인
            cursor.execute(
                """
                SELECT employee_role
                FROM employees
                WHERE employee_id = %s
                """,
                (data.employee_id,),
            )

            employee = cursor.fetchone()

            if employee is None:
                raise HTTPException(
                    status_code=404,
                    detail="존재하지 않는 직원입니다.",
                )

            if employee["employee_role"] != "ADMIN":
                raise HTTPException(
                    status_code=403,
                    detail="상품 등록은 관리자만 가능합니다.",
                )

            # 4. 상품번호 생성
            # 이 함수에서 제조사 + 카테고리 범위 잠금
            cosmetic_id, name_seq, type_seq = (
                generate_cosmetic_id(
                    cursor,
                    data.manufacturer_id,
                    data.category_id,
                    data.cosmetic_name,
                )
            )

            # 5. 동일 상품명 + 용량 중복 확인
            # 번호 생성 함수가 잠금을 획득한 뒤 검사
            cursor.execute(
                """
                SELECT c.cosmetic_id
                FROM cosmetics AS c
                JOIN cosmetic_volume_history AS v
                ON c.cosmetic_id = v.cosmetic_id
                WHERE c.manufacturer_id = %s
                AND c.category_id = %s
                AND c.cosmetic_name = %s
                AND v.volume_text = %s
                LIMIT 1
                """,
                (
                    data.manufacturer_id,
                    data.category_id,
                    data.cosmetic_name,
                    data.volume_text,
                ),
            )

            if cursor.fetchone() is not None:
                raise HTTPException(
                    status_code=409,
                    detail="동일한 상품명과 용량이 이미 등록되어 있습니다.",
                )

            # 6. 상품 기본 정보 등록
            cursor.execute(
                """
                INSERT INTO cosmetics (
                    cosmetic_id,
                    cosmetic_name,
                    manufacturer_id,
                    category_id,
                    cosmetic_name_seq,
                    cosmetic_type_seq
                )
                VALUES (%s, %s, %s, %s, %s, %s)
                """,
                (
                    cosmetic_id,
                    data.cosmetic_name,
                    data.manufacturer_id,
                    data.category_id,
                    name_seq,
                    type_seq,
                ),
            )

            
            # 7. 등록일 및 변경일
            today = date.today()

            # 8. 이력 ID 생성 함수
            def next_history_id(scope_name, prefix):
                cursor.execute(
                    """
                    INSERT INTO id_counters (
                        scope_name,
                        `last_value`
                    )
                    VALUES (%s, LAST_INSERT_ID(1))
                    ON DUPLICATE KEY UPDATE
                        `last_value` = LAST_INSERT_ID(`last_value` + 1)
                    """,
                    (scope_name,),
                )

                cursor.execute(
                    "SELECT LAST_INSERT_ID() AS seq"
                )

                seq = cursor.fetchone()["seq"]

                return f"{prefix}_{seq}"

            # 9. 상품 등록 이력 저장
            registration_id = next_history_id(
                "product_registration",
                "reg",
            )

            cursor.execute(
                """
                INSERT INTO product_registrations (
                    registration_id,
                    employee_id,
                    cosmetic_id,
                    registered_on
                )
                VALUES (%s, %s, %s, %s)
                """,
                (
                    registration_id,
                    data.employee_id,
                    cosmetic_id,
                    today,
                ),
            )

            # 10. 상품 정보 이력 저장
            history_items = [
                (
                    "cosmetic_price_history",
                    "sale_price",
                    data.sale_price,
                    "prc",
                ),
                (
                    "cosmetic_cost_history",
                    "unit_cost",
                    data.unit_cost,
                    "cst",
                ),
                (
                    "cosmetic_volume_history",
                    "volume_text",
                    data.volume_text,
                    "vol",
                ),
                (
                    "cosmetic_sale_status_history",
                    "sale_status",
                    data.sale_status,
                    "sls",
                ),
                (
                    "cosmetic_min_stock_history",
                    "min_stock_qty",
                    data.min_stock_qty,
                    "min",
                ),
                (
                    "cosmetic_target_stock_history",
                    "target_stock_qty",
                    data.target_stock_qty,
                    "tgt",
                ),
            ]

            for table_name, column_name, value, prefix in history_items:
                change_id = next_history_id(
                    f"history:{table_name}",
                    prefix,
                )

                # 테이블명과 컬럼명은 서버 내부에서
                # 정의한 고정 목록만 사용
                cursor.execute(
                    f"""
                    INSERT INTO {table_name} (
                        change_id,
                        cosmetic_id,
                        employee_id,
                        changed_on,
                        {column_name}
                    )
                    VALUES (%s, %s, %s, %s, %s)
                    """,
                    (
                        change_id,
                        cosmetic_id,
                        data.employee_id,
                        today,
                        value,
                    ),
                )

        # 11. 모든 INSERT 성공 시 최종 저장
        conn.commit()

        return {
            "cosmetic_id": cosmetic_id,
            "registration_id": registration_id,
            "message": "상품 등록이 완료되었습니다.",
        }


    except Exception:
        conn.rollback()
        raise

    finally:
        conn.close()
