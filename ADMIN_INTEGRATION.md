# 통합 관리자 기능

## 구성과 권한

- 관리자 로그인 후 대시보드에서 상품 등록, 재고, 주문, 품의, 발주, 입고, 출고, 배송, 반품 메뉴에 접근한다. 직원은 같은 화면에서 재고·주문·입고·출고·배송·반품을 사용한다. 좁은 화면에서는 메뉴가 서랍으로 표시된다.
- 재고·주문은 기존 직원 화면과 지연 조회를 재사용한다. 상품 목록 및 상세는 재고 관리의 화장품별 목록과 옵션에서 확인한다.
- 품의와 발주 대시보드 수치는 각각의 전체 목록 응답에서 집계한다. 나머지 카드는 추정된 건수 없이 해당 메뉴로 이동한다.
- 반품 화면은 서버에서 허용하는 현재 상태의 승인·반려, 회수 요청, 회수 완료·실패, 수령, 검수 동작만 제공한다. 상품 등록에는 실제 제조사 및 카테고리 ID가 필요하다.
- 로그인 토큰을 공통 HTTP 클라이언트로 전달하며 401에서는 세션을 정리한다. 다른 계정으로 로그인할 때 기존 업무 캐시를 초기화한다.
- 상품 등록, 품의, 관리자 배송 조회, 발주 등록은 서버에서 JWT와 현재 DB의 ADMIN 역할을 검증한다. 반품 업무는 실제 로그인 JWT가 있는 STAFF와 ADMIN 모두 사용할 수 있고, 요청 직원 ID는 로그인 계정과 일치해야 한다. 직원 배송 화면은 기존 `/staff/deliveries`를 사용한다. 발주 조회 및 입출고의 기존 STAFF/ADMIN 권한은 유지한다.
- 직원용 임시 인증 라우터는 기본 `main.py`에 등록하지 않는다. 테스트용 엔트리포인트는 유지하며 운영 화면에서는 실제 JWT를 사용한다.
- 주문 생성은 기존 재고를 차감하면서 출고 예약을 생성한다. 출고 처리는 예약에 배송 정보를 연결하며 재고를 다시 차감하지 않는다. 예약이 없는 과거 주문은 서버에서 거절할 수 있다.
- DB 스키마와 마이그레이션은 변경하지 않았다. 기존 코드가 특정 DB 컬럼을 요구하는 경우에도 자동으로 스키마를 변경하지 않는다.

## 변경 파일

- 신규: `frontend/lib/service/api_config.dart`, `frontend/lib/service/admin/management_service.dart`, `frontend/lib/vm/auth/api_client_provider.dart`, `frontend/lib/vm/admin/management_vm.dart`, `frontend/lib/view/admin/admin_dashboard_page.dart`, `cosmetic_create_page.dart`, `return_management_page.dart`, `frontend/web/`, `backend/tests/test_admin_authorization.py`, `frontend/test/api_client_test.dart`, `management_service_test.dart`, `return_management_page_test.dart`.
- 수정: `backend/main.py`, `backend/services/staff/staff_auth_service.py`, `backend/routers/admin/{approval,cosmetic,delivery,purchase_order,return}_router.py`.
- 수정: `frontend/lib/main.dart`, `frontend/lib/service/admin/`의 품의·발주·입고·출고·배송 서비스, `frontend/lib/service/auth/auth_service.dart`, `frontend/lib/vm/admin/`의 해당 Notifier와 출고 상태, `frontend/lib/vm/auth/`의 인증 Notifier, `frontend/lib/vm/delivery/delivery_notifier.dart`, `frontend/lib/vm/staff/staff_inventory_vm.dart`.
- 수정: `frontend/lib/view/admin/`의 품의·발주·직원 발주·출고 화면, `frontend/lib/view/auth/login_page.dart`, `frontend/test/widget_test.dart`, `frontend/.metadata`, Android 기본·디버그 매니페스트. 기존 화면과 테스트용 진입점은 삭제하지 않았다.

## 실행

기존 MySQL 데이터베이스에 연결할 `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `DB_NAME`과 32바이트 이상의 예측 불가능한 `STAFF_JWT_SECRET`을 환경변수 또는 기존 `.env`에 설정한다. `employees`에는 유효한 비밀번호 해시가 있는 ADMIN/STAFF 계정이 필요하다. 운영용 웹 주소는 쉼표로 구분한 `CORS_ALLOWED_ORIGINS`에 등록한다. 로컬 `localhost`와 `127.0.0.1` 웹 주소는 개발용으로 허용한다.

```powershell
cd backend
pip install -r requirements.txt
python -m uvicorn main:app --host 127.0.0.1 --port 8000
```

별도 터미널에서:

```powershell
cd frontend
flutter pub get
flutter run -d chrome
# Android 에뮬레이터: flutter run -d <device-id>
# 서버 주소 지정: flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

기본 서버 주소는 Android 에뮬레이터의 `10.0.2.2:8000`, 웹과 기타 로컬 플랫폼의 `127.0.0.1:8000`이다. `API_BASE_URL`은 이를 덮어쓴다. Android 디버그 빌드는 로컬 개발용 HTTP를 허용하며, 릴리스에서는 HTTPS 서버를 사용해야 한다.

## 검증과 남은 사항

- Flutter 의존성 설치, Flutter 테스트 6개, 웹 빌드 및 Android 디버그 APK 빌드, 관리자 인증/역할/작업자 검증과 출고 재고 차감에 관한 백엔드 단위 테스트 6개, Python 구문 검사를 통과했다.
- 기존 백엔드 전체 테스트 48개 실행에서는 고객·리뷰 테스트에서 다수 실패했다(서브테스트 포함 실패 45건, 오류 6건). 현재 라우트와 테스트의 계약 차이 등이 있어 별도 정리가 필요하다.
- `flutter analyze --no-fatal-infos`는 통과했으며 기존 직원 재고 코드의 정보 수준 항목 7개가 남아 있다. 일반 `flutter analyze`는 이 정보 항목 때문에 0이 아닌 종료 코드를 반환한다.
- 기존 서버의 고객 주문 라우트에는 중복 OpenAPI operation ID 경고가 있다.
- 실제 MySQL 계정과 데이터로 로그인, 결재, 입출고 및 반품 처리의 종단 간 검증은 수행하지 않았다. 실데이터 상태 및 DB 연결 설정을 확인한 후 검증해야 한다.
- 출고 화면은 서버에 배송업체 목록 API가 없으므로 실제 배송업체 ID를 입력받는다. 반품 회수 실패 이후의 재시도 업무는 현재 제공된 API 계약에서 확인되지 않아 임의로 상태를 변경하지 않는다.
