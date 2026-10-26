# 고객·주문 코드 이식 검수

## 확인한 폴더

- `backend/main.py`: FastAPI 앱. 기존에는 관리자·배송 라우터만 연결되어 있었다.
- `backend/routers/customer/customer.py`: 고객 연결 확인용 API만 있었다.
- `backend/database.py`: `.env` 설정을 사용하는 공통 PyMySQL 연결 함수가 있다. 결과는 `DictCursor`로 반환한다.
- `backend/services`, `backend/schemas`: 관리자 기능이 구현되어 있으며 고객 기능은 없었다.
- `database/skin_project.sql`: 첨부된 `cosmetics_management_readable_string_keys.sql`과 SHA-256이 동일하다. 스키마 수정이나 중복 복사는 하지 않았다.
- `frontend/lib/main.dart`: Flutter 기본 카운터 화면이다. 이번 이식 범위는 첨부 Python 파일에 해당하는 백엔드이다.

## 사용한 원본

- `C:/Users/flutter/MYSQL/mysql_todo_list_app/python/customers/customers (2).py`
- `C:/Users/flutter/MYSQL/mysql_todo_list_app/python/customers/order.py`
- `C:/Users/mega/Downloads/cosmetics_management_readable_string_keys.sql`

외부 원본 파일은 수정하지 않았다. 사용자가 허용한 스키마 호환 수정을 현재 프로젝트에 적용했다. 기존 함수 이름, API 경로, 폼 입력 이름과 주요 응답 이름을 유지했다. 기존 프로젝트의 공통 DB 연결과 라우터 등록 방식을 사용한다.

## 이식한 파일

| 파일 | 역할 |
| --- | --- |
| `backend/routers/customer/customer.py` | 원본 회원가입·조회·수정·탈퇴 기능 이식 |
| `backend/routers/customer/order.py` | 원본 주문 등록·고객별 주문 조회 기능 이식 |
| `backend/services/customer/customer_service.py` | 순번 발급, 최신 회원 상태 조회, 회원 상태 이력 추가 |
| `backend/main.py` | 고객·주문 라우터 연결 |
| `backend/requirements.txt` | 원본의 비밀번호 해시 및 폼 처리 의존성 추가 |
| `backend/requirements-dev.txt` | 테스트 클라이언트 의존성 |
| `backend/tests/test_customer.py` | 고객·주문 API와 오류 시 트랜잭션 검증 |

## 스키마에 맞춘 변경

| 원본 | 현재 프로젝트에서의 처리 |
| --- | --- |
| 독립 `FastAPI()` 앱 | 기존 서버에 등록하는 `APIRouter` |
| 코드에 고정된 `beauty_erd_test` 연결 | `database.get_connection()`과 `.env` 설정 |
| 존재하지 않는 `deletesqldata.connect_beauty_erd_test` 가져오기 | 공통 DB 연결 함수 사용 |
| 숫자 회원·재고 ID와 `lastrowid` | 문자열 ID. 신규 회원 `cus_<순번>`, 주문 `ord_<순번>` |
| 고객의 `phone_number` 컬럼 | DB에는 `phone`, 요청·응답에서는 `phone_number` 유지 |
| 고객의 `account_status`, `withdrawn_at` 변경 | `customer_account_status_history`에 상태 이력 추가 |
| 조회 결과를 실제 행 대신 문자열 집합으로 반환 | DB에서 조회한 행을 `result` 배열로 반환 |
| `products.product_name` | `cosmetics.cosmetic_name`, 응답 이름은 `product_name` 유지 |
| 재고에 직접 있는 가격·판매 상태 | `cosmetic_price_history`, `cosmetic_sale_status_history`의 최신 이력 |
| `AVAILABLE`, `expiration_date` | `MAINTAIN`, `expires_on` |
| `reserved_quantity` 증가 | 주문과 같은 트랜잭션에서 `stock_quantity` 차감 |
| 주문 상태 `PLACED` | 스키마에 있는 `PENDING` |
| 주문의 `total_amount` | 주문 항목의 수량과 단가로 계산 |
| 주문의 `order_date` | DB에는 `ordered_at`, 조회 응답에는 `order_date` 유지 |
| 항목의 `quantity`, `unit_price`, `selected_sale_option` | `purchase_quantity`, `purchase_unit_price`, `sale_option` |
| 항목의 자동 숫자 ID | `<order_id>_1`, `order_item_seq=1` |
| `expiration_date_at_order` | 대응 컬럼이 없어 저장하지 않음 |

신규 회원가입은 `ACTIVE` 상태 이력을 함께 저장한다. 상태 이력이 없는 기존 고객은 `ACTIVE`로 취급한다. 같은 날짜의 이력은 ID의 숫자 순번으로 최신 항목을 선택한다. 가격·판매 상태 이력이 없거나 판매 중이 아닌 상품, 보류·폐기 재고, 사용기한이 오늘까지인 재고는 주문할 수 없다. `expires_on`이 `NULL`인 재고는 기한 제한 없이 취급한다.

ID는 `id_counters`를 통해 같은 트랜잭션에서 발급하며 `MAX(id)+1`을 사용하지 않는다. 순번 범위는 `customer`, `order`, `history:customer_account_status_history`이다. 기존 데이터를 수동으로 넣는 경우 해당 범위의 카운터도 발급된 순번에 맞게 유지해야 한다.

주문과 탈퇴는 먼저 동일한 고객 행을 잠근다. 주문은 재고 행을 잠그고 조건부 차감 후 주문과 항목을 저장한다. 중간에 실패하면 전체 작업을 롤백하고 연결을 닫는다. 원본과 같이 주문 한 요청에서는 재고 한 종류와 구매 수량을 받는다.

## API 사용

기존 경로를 유지하기 위해 `/customer` 접두사를 추가하지 않았다. 연결 확인 API `/customer/test`도 유지한다.

| 메서드 | 경로 | 입력 |
| --- | --- | --- |
| POST | `/customers_upload` | 폼: `login_id`, `password`, `customer_name`, `email`, `address`, `phone_number` |
| GET | `/customers_select` | 없음 |
| PUT | `/customers_update` | 쿼리: `customer_id`; 폼: `customer_name`, `email`, `address`, `phone_number` |
| POST | `/customers_delect` | 폼: `seq`에 문자열 회원 ID 전달 |
| POST | `/orders` | 폼: `customer_id`, `inventory_id`, `quantity` |
| GET | `/orders` | 쿼리: `customer_id` |

회원·재고 ID에는 DB에 존재하는 문자열 값을 전달한다. `phone_number`는 필수 입력이다. 중복 아이디·이메일, 중복 탈퇴, 재고 부족은 HTTP 409를 반환한다. 없는 고객은 HTTP 404, 판매 불가 상품이나 배송지 누락은 HTTP 400, 잘못된 입력은 HTTP 422를 반환한다.

## 실행

프로젝트 루트에서 다음 명령을 실행한다.

```powershell
cd backend
python -m pip install -r requirements.txt
```

`backend/.env`에 실제 MySQL 접속 정보를 설정한다. 예시는 아래와 같다.

```dotenv
DB_HOST=127.0.0.1
DB_PORT=3306
DB_USER=your_mysql_user
DB_PASSWORD=your_mysql_password
DB_NAME=cosmetics_management
```

데이터베이스가 아직 없다면 MySQL에서 `database/skin_project.sql`로 초기 스키마를 생성한다. 이 파일은 새 스키마 생성용이며 이미 테이블이 있는 DB에 반복 실행하는 마이그레이션 파일은 아니다. 이번 작업에서는 실제 DB에 SQL을 실행하지 않았다.

```powershell
python -m uvicorn main:app --host 127.0.0.1 --port 8000 --reload
```

API 문서는 `http://127.0.0.1:8000/docs`에서 확인한다.

## 검증 결과

`backend` 폴더에서:

```powershell
python -m pip install -r requirements-dev.txt
python -m unittest discover -s tests -v
```

21개 테스트 통과. 실제 비밀번호 해시 저장값, 라우터 연결, 고객 조회·수정·탈퇴, 문자열 ID, 주문 금액, 재고 부족, 탈퇴 고객 주문 차단, 입력 검증, 중간 저장 실패 시 롤백과 연결 종료를 검증했다.

테스트는 DB 연결을 모의 객체로 대체한다. 실제 MySQL에서 SQL 실행, 제약 조건 적용, 동시 요청 간 잠금은 검증하지 않았다. 실제 DB 연결 정보와 서버가 있는 환경에서 별도 확인이 필요하다.
