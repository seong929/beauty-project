"""직원 로그인: 기존 pwdlib 비밀번호 해시 및 employees 정보 활용."""
from fastapi import APIRouter
from pydantic import BaseModel, Field
from services.staff.staff_auth_service import authenticate_employee, issue_staff_token

router = APIRouter(prefix="/auth", tags=["직원-인증"])

class StaffLoginRequest(BaseModel):
    login_id: str = Field(min_length=1, max_length=50, description="직원 로그인 ID")
    password: str = Field(min_length=1, description="직원 비밀번호")

class StaffTokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    expires_in: int

@router.post(
    "/login",
    response_model=StaffTokenResponse,
    summary="직원 로그인 및 인증 토큰 발급",
    description="employees의 login_id 및 pwdlib 해시를 검증한 후 직원용 Bearer 토큰을 발급합니다.",
    responses={401: {"description": "아이디 또는 비밀번호 오류"},
               403: {"description": "직원 권한 없음"},
               503: {"description": "인증 서버 또는 DB 장애"}},
)
def staff_login(data: StaffLoginRequest):
    employee = authenticate_employee(data.login_id, data.password)
    return issue_staff_token(employee["employee_id"])
