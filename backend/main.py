import os

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from routers.admin.approval_router import router as approval_router
from routers.admin.cosmetic_router import router as cosmetic_router
from routers.admin.inbound_router import router as inbound_router
from routers.admin.outbound_router import router as outbound_router
from routers.admin.purchase_order_router import router as purchase_order_router
from routers.admin.return_router import router as admin_return_router
from routers.staff.staff_auth_related import router as staff_auth_router
from routers.staff.staff_cosmetics_related import router as staff_cosmetics_router
from routers.staff.staff_inventory_related import router as staff_inventory_router
from routers.staff.staff_order_related import router as staff_order_router
from routers.system.automatic_purchase_approval_router import router as automatic_approval_router
from routers.customer.customer import router as customer_router
from routers.customer.customer_categories_search import router as customer_categories_router
from routers.customer.cart_items import router as cart_items_router
from routers.customer.order import router as order_router
from routers.customer.order_item import router as order_item_router
from routers.customer.delivery import router as customer_delivery_router
from routers.customer.review import router as review_router
from routers.delivery.delivery import router as carrier_delivery_router
from routers.delivery.carrier_router import router as carrier_router
from routers.delivery.delivery_auth_router import router as delivery_auth_router
from routers.admin.delivery_router import router as admin_delivery_router
from routers.staff.staff_delivery_router import router as staff_delivery_router


app = FastAPI(
    title="온라인 화장품 판매 및 유통 관리 시스템",
    description="자율 팀 프로젝트",
    version="1.0.0",
)

# Flutter Web의 로컬 개발 주소와 명시적으로 설정된 배포 주소를 허용한다.
app.add_middleware(
    CORSMiddleware,
    allow_origins=[origin.strip() for origin in os.getenv("CORS_ALLOWED_ORIGINS", "").split(",") if origin.strip()],
    allow_origin_regex=r"^https?://(localhost|127\.0\.0\.1)(:\d+)?$",
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type"],
)

app.include_router(cosmetic_router)
app.include_router(approval_router)
app.include_router(purchase_order_router)
app.include_router(inbound_router)
app.include_router(outbound_router)
app.include_router(admin_return_router)
app.include_router(carrier_router)
app.include_router(customer_router)
app.include_router(customer_categories_router)
app.include_router(cart_items_router)
app.include_router(order_router)
app.include_router(order_item_router)
app.include_router(customer_delivery_router)
app.include_router(review_router)
app.include_router(carrier_delivery_router)
app.include_router(delivery_auth_router)
app.include_router(staff_order_router)
app.include_router(staff_auth_router)
app.include_router(staff_cosmetics_router)
app.include_router(staff_inventory_router)
app.include_router(staff_delivery_router)
app.include_router(automatic_approval_router)
app.include_router(admin_delivery_router)


@app.get("/")
def home():
    return {"message": "FastAPI 서버 정상 실행"}


@app.get("/health")
def health_check():
    return {"status": "ok"}


if __name__ == "__main__":
    import uvicorn

    uvicorn.run("main:app", host="127.0.0.1", port=8000, reload=True)
