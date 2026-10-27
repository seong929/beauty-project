"""개발용 임시 직원 인증. 운영 배포 전 main.py의 include_router를 삭제하세요."""
import logging
from fastapi import APIRouter, HTTPException, Request, Response
import pymysql
from database import get_connection
from services.staff.staff_auth_service import enable_tmp_staff_auth, create_tmp_staff_session

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/tmp", tags=["개발용 임시 인증"])
enable_tmp_staff_auth()  # 이 모듈이 등록될 때만 쿠키 인증 허용


@router.post("/staff-auth-grant", summary="테스트 직원 권한 부여 (한 번 클릭)")
def grant_staff_auth(request: Request, response: Response):
    if request.client is None or request.client.host not in ("127.0.0.1", "::1"):
        raise HTTPException(status_code=403, detail="로컬 개발 서버에서만 실행할 수 있습니다.")
    try:
        conn = get_connection()
    except pymysql.MySQLError:
        raise HTTPException(status_code=503, detail="DB 연결 실패") from None
    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                SELECT employee_id, employee_role FROM employees
                WHERE employee_role = 'STAFF'
                ORDER BY employee_id LIMIT 1
            """)
            employee = cursor.fetchone()
    except pymysql.MySQLError:
        logger.exception("테스트 직원 조회 실패")
        raise HTTPException(status_code=503, detail="직원 조회 실패") from None
    finally:
        conn.close()
    if employee is None:
        raise HTTPException(status_code=404, detail="테스트용 STAFF 직원이 없습니다.")
    session = create_tmp_staff_session(employee["employee_id"])
    response.set_cookie(
        key="tmp_staff_session", value=session,
        httponly=True, secure=False, samesite="strict",
        max_age=3600, path="/",
    )
    return {"message": "테스트 직원 권한이 부여되었습니다. 이제 직원 API의 Execute를 누르세요.",
            "employee_id": employee["employee_id"], "expires_in": 3600}


@router.post("/staff-auth-clear", summary="테스트 직원 권한 해제")
def clear_staff_auth(request: Request, response: Response):
    if request.client is None or request.client.host not in ("127.0.0.1", "::1"):
        raise HTTPException(status_code=403, detail="로컬 개발 서버 전용")
    response.delete_cookie("tmp_staff_session", path="/", samesite="strict")
    return {"message": "브라우저의 테스트 인증 쿠키를 삭제했습니다."}
