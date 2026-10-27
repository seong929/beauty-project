from fastapi import FastAPI

from routers.admin.cosmetic_router import router as cosmetic_router
from routers.admin.approval_router import router as approval_router
from routers.delivery.delivery import router as delivery_router
from routers.customer.customer import router as customer_router
from routers.customer.order import router as order_router
from routers.customer.review import router as review_router
from routers.admin.purchase_order_router import router as purchase_order_router


app = FastAPI(
    title="온라인 화장품 판매 및 유통 관리 시스템",
    description="자율 팀 프로젝트",
    version="1.0.0",
)

app.include_router(cosmetic_router)
app.include_router(approval_router)
app.include_router(delivery_router)
app.include_router(customer_router)
app.include_router(order_router)
app.include_router(review_router)
app.include_router(purchase_order_router)


@app.get("/")
def home():
    return {"message": "FastAPI 서버 정상 실행"}


@app.get("/health")
def health_check():
    return {"status": "ok"}


if __name__ == "__main__":
    import uvicorn

    uvicorn.run("main:app", host="127.0.0.1", port=8000, reload=True)
