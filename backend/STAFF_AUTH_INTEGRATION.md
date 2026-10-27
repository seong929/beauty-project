# 기존 backend.zip 직원 권한 보완

## 확인한 기존 구조
- `pwdlib[argon2]`은 고객 회원가입에서 비밀번호 해싱에 사용됨.
- 직원 로그인/토큰 발급/공통 권한 검증 구현은 원본 `backend.zip`에서 확인되지 않음.
- 기존 관리자 서비스의 `employee_id` 요청값 조회는 *인증이 아니며* 위조할 수 있음.
- 스키마 `employees.employee_role`은 `STAFF`/`ADMIN`, 현재 역할 판정에 사용함 (`key_role`은 생성 당시 값).

## 변경 사항
- 기존 파일 3개 (`routers/staff/staff_order_related.py`, `staff_cosmetics_related.py`, `staff_inventory_related.py`)에 Bearer 인증 적용.
- 기존 `pwdlib` 활용하여 `POST /staff/auth/login`에서 로그인 ID/비밀번호 확인 후 JWT 발급.
- 추가: `routers/staff/staff_auth_related.py`, `security/{__init__.py, staff_auth.py}`.
- `requirements.txt`에 `PyJWT>=2.8,<3` 추가.
- **`main.py` 미변경**: 기존 `staff_order_related`에 공개 로그인 하위 라우터를 포함. 로그인 경로에는 인증 의존성이 걸리지 않음.
- 기존 service SQL 및 비즈니스 동작 변경하지 않음.

## 필수 설정
1. `pip install -r requirements.txt`
2. 서버 환경변수 `STAFF_JWT_SECRET`에 예측 불가능한 32바이트 이상 문자열 지정 (`python -c "import secrets; print(secrets.token_urlsafe(48))"`).
3. 직원 테이블의 `password_hash`는 반드시 실제 `pwdlib` 해시가 저장되어야 함. 샘플 데이터의 `__DEMO_HASH...`는 로그인 불가능.
4. HTTPS 사용, 운영 환경에서 로그인 요청 횟수 제한 및 접근 로그·경고 추가 권장.

### 로그인 예시
`POST /staff/auth/login` JSON 요청: `{"login_id":"<실제 직원 ID>","password":"<비밀번호>"}`
응답 `access_token`을 Swagger Authorize의 HTTP Bearer 또는 직원 API의 `Authorization: Bearer <token>`으로 전달.

### 오류 응답
- 401: 토큰 없음/위조/만료 또는 로그인 실패
- 403: 계정 존재하지만 직원 권한 없음
- 503: 비밀키 미설정·DB 장애

### 제한사항 (중요)
- 이 패치는 **직원용 라우터 3개만 보호**. 기존 `/admin` 라우터와 `/customer` 라우터는 별개이며 기존의 권한 취약점이 남아 있음. 실제 공개 서비스 전에 동일한 인증/인가 방식으로 보호 필요.
- 직원 로그인은 `employees`에 이미 유효한 비밀번호 해시가 있다는 전제. 별도 직원 계정 등록/암호 변경 기능은 신규 구현하지 않음.
- JWT 로그아웃/개별 토큰 폐기 및 rate limiting은 미구현. 토큰 기본 만료는 1시간, 직원 역할 변경은 각 요청에서 DB로 반영됨.
- `database.py`에 하드코딩된 DB 비밀번호가 존재함. 별도 환경 변수로 옮기고 즉시 교체 권장. 사용자가 요청하지 않은 DB 설정 파일은 수정하지 않음.
