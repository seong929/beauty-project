# 내부 환불 상태 관리

## 구현 범위

- 기존 `/orders_pay`는 주문·재고를 저장하고 주문을 `PAID`로 처리한다.
- 응답의 `payment_note`는 외부 결제 승인 연동이 없음을 명시한다.
- 현재 MySQL에는 결제 거래·PG 취소 정보를 저장하는 테이블이 없다.
- 이번 구현은 내부 업무 상태 관리다. 결제 취소, 실제 금액 반환, 주문 금액 변경을 수행하지 않는다.
- DB의 `COMPLETED` 값은 유지하지만 이번 API로 변경할 수 없다. PG 결과 검증을 통한 실제 환불 완료는 후속 구현 범위다.
- DB 스키마 변경은 없다.

## API

`PATCH /admin/returns/{return_id}/refund-status`

직원 JWT가 필요하며, DB에서 확인한 `ADMIN`만 실행할 수 있다. 요청의 `employee_id`는 로그인 사용자와 일치해야 한다.

```json
{
  "employee_id": "로그인한 관리자 직원 ID",
  "expected_refund_status": "PENDING",
  "refund_status": "PROCESSING"
}
```

성공 응답에는 `previous_refund_status`, `refund_status`, `external_refund_performed: false`와 실제 금액 반환을 수행하지 않았다는 메시지가 포함된다.

| 현재 상태 | 요청 상태 | 의미 |
|---|---|---|
| PENDING | PROCESSING | 내부 환불 업무 접수 |
| PROCESSING | FAILED | 내부 처리 실패 기록 |
| FAILED | PROCESSING | 내부 업무 재접수 |
| COMPLETED | 변경 불가 | 기존 완료 데이터 재처리 금지 |

전제 조건은 `return_status = COMPLETED`, `pickup_status = COLLECTED`, 본사 수령일 존재, 공백이 아닌 검수 결과다.

`SELECT ... FOR UPDATE`와 현재 상태 비교 후 조건부 UPDATE를 같은 트랜잭션에서 수행한다. 동일 요청의 동시 실행·현재 상태 불일치·허용되지 않은 전이는 `409`다. 요청 상태로 `COMPLETED`를 전송하면 `422`다. 실패 시 롤백한다.

## 화면

- 기존 본사 반품 관리 화면에 내부 접수·실패 기록·재접수 버튼 추가.
- 검수 전, 일반 직원, 이미 완료된 환불에는 버튼을 제공하지 않음.
- 기존 목록 조회와 반품 업무 유지. 필터·환불 작업 상태는 불변 `ReturnManagementState`와 `NotifierProvider`로 관리.
- 처리 중 중복 클릭 차단, 오류 표시, 성공 후 서버 목록·상세 재조회.
- 저장 성공 후 목록 조회가 실패하면 저장 여부를 구분하여 안내. 조회 실패는 자동 재시도 없이 새로고침으로 복구.
- 고객은 기존 반품 현황 새로고침으로 변경 상태 확인. 본사와 고객 화면에 실제 결제 취소가 연동되지 않았음을 표시.

## 변경 파일

수정:

- `backend/schemas/admin/return_schema.py`
- `backend/services/admin/return_service.py`
- `backend/routers/admin/return_router.py`
- `frontend/lib/service/admin/management_service.dart`
- `frontend/lib/vm/admin/management_vm.dart`
- `frontend/lib/view/admin/return_management_page.dart`
- `frontend/lib/view/customer/return/return_status_screen.dart`
- `frontend/test/customer_history_return_test.dart`
- `frontend/test/customer_screens_test.dart` — 기존 unused import 제거

추가:

- `frontend/lib/vm/admin/return_management_state.dart`
- `frontend/test/admin_refund_test.dart`
- `backend/tests/test_admin_refunds.py`
- `backend/tests/test_admin_refunds_mysql.py`
- 이 문서

## 검증 (2026-10-30)

- `flutter analyze`: 문제 없음.
- `flutter test test/admin_refund_test.dart test/return_management_page_test.dart test/management_service_test.dart test/customer_history_return_test.dart test/return_pickup_test.dart test/customer_delivery_test.dart`: 36개 통과.
- 백엔드 `.venv/Scripts/python.exe -m pytest tests -q`: 134개 통과, 2개 선택 실행 MySQL 테스트 제외, 87개 subtest 통과.
- `RUN_MYSQL_REFUND_TEST=1`로 `tests/test_admin_refunds_mysql.py` 별도 실행: 1개 통과.
- MySQL 통합 검증: 실제 JWT 인증, 기존 승인·회수 배정·배송업체 수거·본사 수령·검수 완료, 검수 전 환불 거절, 동시 요청 1건 성공/1건 거절, 실패·재접수, 외부 완료 요청 거절, 새 DB 연결의 저장 확인, 본사·고객 조회 반영 확인.
- 통합 테스트는 별도 반품을 생성하고 `finally`에서 배정·반품 데이터를 삭제한다. 사용자 반품 `ret_ord_910080_1_1`은 변경하지 않는다.
- 기존 백엔드 경고: Starlette TestClient의 httpx 관련 deprecation, 중복 주문 취소 OpenAPI operation ID. 테스트 실패는 없다.
