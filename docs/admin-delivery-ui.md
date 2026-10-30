# 관리자·배송업체 전용 UI

기준 커밋: `6099587` (PR #34 포함). 코드 변경은 승인된 ADMIN·DELIVERY UI 범위에 한정한다.

## 실행

```powershell
cd frontend
flutter run -t lib/main_operations.dart
flutter run -t lib/main_delivery.dart
```

두 명령은 각각 관리자와 배송업체를 실행한다. 고객용 `main.dart`, 기존 관리자·직원용 `main_admin.dart`, `main_sodam.dart`는 변경하지 않았다. 기존 관리자 진입점에서는 기존 화면이 계속 표시된다.

새 관리자 진입점은 기존 직원 JWT 로그인 API를 사용하고 ADMIN만 업무 화면에 접근시킨다. STAFF 계정에는 기존 직원 실행 경로를 이용하도록 안내한다. 로그인 세션별 ProviderContainer를 분리하고 로그아웃·인증 만료 시 세션을 정리한다.

## 구현

- 관리자: 흰색 카드·녹색 작업 버튼·일관된 제목과 폼을 사용하는 독립 업무 공간.
- 대시보드: 실제 품의·발주 목록에 근거한 대기 건수와 업무 바로가기. 실패는 0건으로 표시하지 않는다.
- 품의·발주·본사 배송: 넓은 화면에서 목록/상세, 좁은 화면에서 전체 높이 상세와 목록 복귀.
- 상품 등록: 이미지, 기본 정보, 가격·재고 기준 구역화. 기존 이미지 업로드 재시도 유지.
- 재고: 기존 상품별/상태별 조회, 사용기한, 옵션·배치 상세, 입출고 이력·폐기 흐름 유지.
- 주문: 기존 검색·정렬·정확한 시각 입력을 유지하면서 달력 기간 선택 추가.
- 발주처: 목록 검색과 등록 대화상자를 분리.
- 입출고: 기존 대상 선택·검증·API·확인·결과 표시를 유지.
- 반품·환불: 조회된 목록 내 ID 검색, 반품/수거/환불 독립 필터, 독립 상태 배지, 읽기 쉬운 날짜·검수 상세.
- PR #34: 환불 접수·실패·재접수·완료 기록, `expected_refund_status`, 완료 후 재변경 금지 및 외부 금액 반환 미수행 확인 문구 유지.
- 배송업체: 클릭 가능한 상태 집계, 작은 화면의 목록→상세, 지속 오류·빈 결과 안내, 배송 시작·완료 확인 유지.
- 반품 수거: ID·수거지 검색, 상태별 건수, 주소 요약·상세, 수거 완료 확인 및 재조회.

기존 업무 Model·Service·Provider/Notifier는 재사용했다. 새 업무 선택·검색·필터 상태는 전용 NotifierProvider와 불변 State로 관리한다. 기존 폼 컨트롤러 등 화면 내부 상태는 View에 유지한다.

## 격리

직원과 공유하던 View는 수정하지 않고 `view/admin/operations/` 아래에 관리자 전용 presentation을 분리했다. 기존 공용 API·인증·상태 변경 로직을 복제하지 않았다. 신규 업무 기능이나 Endpoint, 요청·응답, 상태값, 운송장 번호, 외부 패키지는 추가하지 않았다.

고객 UI, 직원 UI, 공용 이미지·테마, 기존 Model·Service·VM, 기존 공통 진입점, 백엔드·DB·마이그레이션은 원본과 같다. 보호 경로의 내용 해시 9개와 Git diff 허용 목록을 검증했다. commit/push/merge는 수행하지 않았다.

## 수정한 기존 파일

| 파일 | 내용 |
|---|---|
| `frontend/lib/main_delivery.dart` | 배송업체 전용 테마 |
| `frontend/lib/view/auth/carrier_login_page.dart` | 배송업체 로그인 스타일, 기존 인증 동작 유지 |
| `frontend/lib/view/delivery/delivery_page.dart` | 상태 집계 바로가기, 작은 화면 상세 탐색, 오류·빈 상태 |
| `frontend/lib/view/delivery/return_pickup_page.dart` | 검색·건수·주소·상태·상세 정보 |
| `frontend/test/return_pickup_test.dart` | 주소가 목록과 상세 모두에 표시되는 동작 검증 |

## 추가한 파일

- `frontend/lib/main_operations.dart`
- `frontend/lib/app/operations_app.dart`
- `frontend/lib/view/operations/operations_theme.dart`
- `frontend/lib/view/operations/operations_widgets.dart`
- `frontend/lib/vm/operations/workspace_notifier.dart`
- `frontend/lib/vm/operations/return_filters_notifier.dart`
- `frontend/lib/vm/operations/pickup_query_notifier.dart`
- `frontend/lib/view/admin/operations/workspace.dart`
- `frontend/lib/view/admin/operations/login_page.dart`
- `frontend/lib/view/admin/operations/inventory_page.dart`
- `frontend/lib/view/admin/operations/product_detail_page.dart`
- `frontend/lib/view/admin/operations/product_create_page.dart`
- `frontend/lib/view/admin/operations/inventory_batch_page.dart`
- `frontend/lib/view/admin/operations/inventory_discard_page.dart`
- `frontend/lib/view/admin/operations/orders_page.dart`
- `frontend/lib/view/admin/operations/order_detail_page.dart`
- `frontend/lib/view/admin/operations/approval_page.dart`
- `frontend/lib/view/admin/operations/approval_order_dialog.dart`
- `frontend/lib/view/admin/operations/list_controls.dart`
- `frontend/lib/view/admin/operations/purchase_order_page.dart`
- `frontend/lib/view/admin/operations/manufacturer_page.dart`
- `frontend/lib/view/admin/operations/inbound_orders_page.dart`
- `frontend/lib/view/admin/operations/inbound_page.dart`
- `frontend/lib/view/admin/operations/outbound_page.dart`
- `frontend/lib/view/admin/operations/delivery_page.dart`
- `frontend/lib/view/admin/operations/returns_page.dart`
- `frontend/test/operations_ui_test.dart`
- 이 문서

## 검증

- `flutter analyze`: No issues found.
- `flutter test --reporter expanded`: 전체 232개 통과. 기존 고객·직원·환불 테스트 포함.
- 새 UI 테스트: 320/768/1280px의 전체 관리자 메뉴, 배송 시작→완료, 수거 완료, PR #34 완료 기록, 목록 검색, 오류 복구, 상품 등록 검증, STAFF 접근 제한 확인.
- `flutter build web --target lib/main_operations.dart --output build/web-operations`: 성공.
- `flutter build web --target lib/main_delivery.dart --output build/web-delivery --no-wasm-dry-run`: 성공.
- `git diff --check`: 통과.

화면 테스트에는 MockClient와 테스트용 Service를 사용했다. 실제 DB의 변경 API나 PG 환불은 실행하지 않았다. 실제 앱 실행 시에는 기존 Service가 설정된 FastAPI에 연결한다.

미리보기는 `output/operations_ui/`에 출력한 테스트 데이터 화면이다. `OPERATIONS_PREVIEW_DIR`를 설정하고 새 UI 테스트를 실행하면 다시 생성할 수 있다.
