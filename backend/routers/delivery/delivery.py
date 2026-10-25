from fastapi import APIRouter

router = APIRouter(
    prefix="/delivery",
    tags=["배송업체"],
)


@router.get("/test")
def delivery_test():
    return {"message": "배송업체 API 연결 성공"}