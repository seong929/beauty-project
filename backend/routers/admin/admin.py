from fastapi import APIRouter

router = APIRouter(
    prefix="/admin",
    tags=["본사 관리자"],
)


@router.get("/test")
def admin_test():
    return {"message": "관리자 API 연결 성공"}