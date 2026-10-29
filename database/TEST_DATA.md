# 관리자 업무 테스트 데이터

`backend/seed_admin_test_data.py`는 기존 MySQL 스키마를 유지하면서 개발용 데이터를 생성한다. 실행 전에 `backend/.env` 또는 환경변수에 `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `DB_NAME`을 설정한다. 데이터 생성기 기본 실행은 트랜잭션을 롤백하며, 실제 저장은 `--apply`를 명시한다.

```powershell
cd backend
python seed_admin_test_data.py          # INSERT 후 롤백 검증
python seed_admin_test_data.py --apply  # 저장
```

`--env-file <경로>`로 다른 설정 파일을 지정할 수 있다. 고정된 테스트 ID와 로그인 ID를 사용하므로 이미 생성한 환경에서 재실행하면 중복 오류가 발생하고 전체 트랜잭션이 롤백된다. 기존 데이터는 변경하거나 삭제하지 않는다.

로그인 테스트 계정은 아래와 같다. 비밀번호는 테스트 전용이며 운영 계정에 사용해서는 안 된다.

| 역할 | 로그인 ID | 비밀번호 |
| --- | --- | --- |
| 관리자 | `fixture_admin` | `BeautyTest!2026` |
| 직원 | `fixture_staff` | `BeautyTest!2026` |

생성되는 주요 데이터:

- 제조사 `mfr_codex_fixture`, 카테고리 `cat_codex_fixture`, 배송업체 `car_codex_fixture`, 고객 `fixture_customer_900000001`
- 상품 3개와 상품 정보 이력, 승인 대기 품의 1개와 승인된 품의 2개
- 부분 입고 발주 1개와 `MAINTAIN`, `HOLD`, 수량이 남은 `DISCARD`, 수량이 0인 `DISCARD` 재고
- `PAID` 주문 `ord_900000001`, `PREPARING` 주문 `ord_900000002`, `DELIVERED` 주문 `ord_900000003`
- 배송 완료 건 1개와 승인 대기 반품 `ret_ord_900000003_1_1`

`stock_outbounds`가 주문별 예약 출고와 NULL 배송 정보를 지원하면 결제·준비 주문에 예약 출고를 생성한다. 구형 구조는 기존 스키마를 바꾸지 않고 예약 출고 생성을 생략한다. 주문 목록의 기본 필터는 진행 중인 주문만 포함하므로 배송 완료 주문은 상태 필터 또는 상세 조회에서 확인한다.

실제 개발 DB에서는 관리자·직원 로그인, 품의·발주·상품·주문·배송·반품 조회, 비로그인 반품 조회 401과 직원의 관리자 품의 조회 403을 확인했다. 직원은 반품 API에 접근할 수 있다. 데이터의 상태 변경 업무는 초기 테스트 상태를 보존하기 위해 실행하지 않았다.
