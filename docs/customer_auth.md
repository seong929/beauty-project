# 고객 로그인·회원가입·홈

## 반영 범위

사용자가 제공한 이미지를 기준으로 로그인·회원가입·고객 홈 화면을 구현했다.
추가 요청에 따라 `backend/routers/customer/customer.py`의 고객 등록과 조회 사이에 고객 로그인 API를 추가했다.
2026-10-30 추가 요청에 따라 아이디 중복 확인 API와 선택 성별 저장을 추가하고 가입·수량·재고 흐름을 개선했다. 후속 요청에 따라 출생연도 항목은 제거했다. [변경 내역](customer-20261030-changes.md)을 참고한다.

- 로그인: 버튼과 키보드 완료 동작을 Riverpod VM에 연결했다. 입력 검증 후 `POST /customer_login`으로 요청한다.
- 로그인 성공 시 고객 정보를 메모리에 저장하고 홈으로 이동한다. 비밀번호는 상태에 저장하지 않는다.
- 홈: 상단 안내, 검색·필터, 배너, 카테고리, 상품 목록과 하단 메뉴를 제공한다. 내 정보 메뉴에서 고객 정보와 로그아웃을 확인한다.
- 상단 사진 목록: 업로드한 사진 중 1~10번을 표시하며 전체 보기와 확대 보기를 제공한다.
- 하단·검색 상품: `GET /customers_categories_search`에서 실제 DB 상품번호·상품명·가격·등록된 용량을 불러온다. 임의의 `preview_...` 번호와 4개 용량은 실제 저장에 사용하지 않는다.
- 예시 상품 목록은 화면 테스트용으로만 보존한다. 앱의 기본 상품 Provider에는 예시 목록을 연결하지 않는다.
- 실제 상품 응답에는 이미지 경로가 없으므로 미등록 이미지는 기본 아이콘으로 표시한다. 업로드한 사진 10개는 상단 갤러리에 유지한다. DB 상품과 사진을 임의로 대응시키지 않는다.
- 상품 검색: 홈의 검색 완료, 하단 검색 메뉴, 상품 전체 보기에서 검색·정렬·필터 페이지로 이동한다. 최근 검색어, 카테고리·가격 범위, 별점순 정렬과 빈 결과 초기화를 제공한다.
- 상품 상세: 홈·검색에서 선택한 용량과 가격을 고정 표시하며 용량 선택 버튼은 제공하지 않는다. 사진·설명·단가와 장바구니 담기를 제공하며, 수량은 주문/결제에서 1~99개와 현재 판매 재고 한도 안에서 변경한다. 상세/추천/리뷰/배송 탭 줄은 제거하고 평균 별점·리뷰 수와 리뷰 목록을 본문에 직접 표시한다.
- 장바구니: 실제 로그인 고객번호와 상품번호로 `POST /incart_upload`가 성공한 뒤에만 담기를 표시한다. 페이지를 열면 `GET /incart_select?customer_id=...`로 복원하며 삭제는 `DELETE /incart_delete`로 처리한다. 중복 응답은 서버에 실제로 해당 행이 있는지 확인한 뒤 처리한다.
- 기존 테이블/API에는 수량·선택 용량 저장 필드가 없으므로 고객·상품 관계만 MySQL에 저장한다. 수량은 현재 앱에서 유지하고 새 세션에서는 1개로 표시한다. 상품 용량은 해당 실제 상품번호의 등록 용량을 사용한다.
- 결제: 선택한 실제 상품과 수량, 고객번호, 배송 주소를 기존 `POST /orders_pay`로 전송한다. 최종 가격과 재고는 서버가 확인하고, 주문·주문 상품·재고·장바구니를 같은 트랜잭션으로 처리한다. 일반 판매 옵션(`NORMAL`)을 사용한다.
- 결제 확정 전에 카드·계좌에서 금액이 청구되지 않는다는 안내를 표시한다. 현재 백엔드는 외부 결제 승인 없이 주문을 `PAID`로 저장하는 시스템이다.
- 주문·결제 UI는 첨부 이미지처럼 4단계로 구성한다: 주문자·배송지·상품 확인 → 할인·금액 확인 → 결제수단 선택 → 최종 확인·동의. 주문 화면에만 흰색·민트색 테마를 적용하며 하단의 `다음`과 `결제하기`로 진행한다.
- 앞의 세 단계는 서버에 주문을 전송하지 않는다. 마지막 단계에서 결제수단을 선택하고 구매 조건·주문 정보 전송 확인에 모두 동의한 뒤 `결제하기`를 눌러야 기존 주문 API를 호출한다. 이전 버튼과 시스템 뒤로가기로 단계를 이동할 수 있다.
- 상품·수량·배송주소·결제수단이 바뀌면 동의를 해제한다. 로그인 고객이 바뀌거나 주문 화면을 닫으면 단계와 결제수단·동의를 초기화한다. 주문 요청 중에는 뒤로가기와 입력을 막는다.
- 신용카드·실시간 계좌이체는 화면 선택만 제공한다. 기존 API에는 결제수단 저장 항목이 없으므로 선택값을 전송하거나 결제 승인된 것으로 처리하지 않는다. N pay·toss pay·PAYCO·kakao pay는 준비 중으로 선택할 수 없다.
- 주문 화면에서 쿠폰 할인 항목은 제거했다. 포인트 입력·전액 사용으로 결제 금액을 차감하고, 차감 후 결제 금액의 10%를 적립한다. 잔액·금액은 서버가 최종 검증하며 주문·재고·포인트를 함께 저장한다. 취소 시 사용 포인트를 복원하고 적립 포인트를 회수한다. [포인트 사용과 주문 취소](customer-points.md)를 참고한다.
- 배송지 정보 옆의 `배송지 변경` 버튼으로 이번 결제의 수령인·연락처·주소를 편집한다. 배송 요청사항은 요청사항 없음·문 앞·경비실·택배함·배송 전 연락·직접 입력 중 선택한다. 직접 입력은 공백을 제외한 내용이 있어야 하며 최대 200자까지 입력한다. 단계 이동 중 값을 유지하고 최종 단계에 다시 표시한다. 요청사항을 바꾸면 동의를 초기화한다. 요청사항은 `shipping_address`와 분리된 `delivery_request`로 전송해 주문에 저장한다.
- 서버의 `OK`·`PAID` 응답과 고객번호·주소·상품별 수량·합계가 확인된 뒤에만 완료 화면으로 이동한다. 완료 화면은 서버가 반환한 금액과 주문번호를 표시하며 구매한 상품만 앱 장바구니에서 제거한다. 선택하지 않은 상품은 유지한다.
- 요청 중에는 버튼·뒤로가기·상품 변경을 차단한다. 재고 부족 등 명확한 거절은 장바구니를 유지하고 오류를 표시한다. 통신 중단·5xx·불명확한 성공 응답은 저장 여부가 불확실하므로 현재 로그인 세션의 재전송을 막고 구매 내역 확인을 안내한다. 서버에는 멱등성 키가 없으므로 앱 재시작을 포함한 모든 중복 제출을 보장하지는 않는다.
- 구매 내역은 `GET /orders?customer_id=...`의 `results`를 주문별로 묶는다. 동일한 주문 상품의 조인 중복은 한 번만 계산하고, 재고 배치별로 나뉜 같은 상품·가격은 화면에서 수량을 합쳐 표시한다.
- 마이페이지: 로그인한 고객의 이름·아이디·마일리지, 구매 주문 수, 서버 주문의 배송 중 수를 표시한다. 구매 내역·배송 현황·리뷰 내역·개인정보 수정·로그아웃·확인 후 회원 탈퇴를 연결한다. `배송 주소 관리` 메뉴는 제거했다. 마일리지 내역에서 적립·회수 기록을 확인한다.
- 개인정보·기본 주소는 기존 `PUT /customer_update`, 탈퇴는 기존 `POST /customer_delect`를 사용한다. 저장 성공 후에만 로그인 프로필을 갱신한다. 기본 주소 변경은 이미 저장된 주문 주소를 수정하지 않는다.
- 로그아웃하면 화면 상태만 비우고 MySQL 장바구니는 유지한다. 다음 로그인 후 장바구니를 열면 다시 조회한다.
- 아이디 중복 확인: 전용 API로 사용 가능 여부를 확인한다. 아이디를 변경하면 재확인하며 최종 회원가입에서도 DB 고유키로 중복을 검증한다.
- 회원가입: 기존 `POST /customer_upload`로 실제 요청하는 코드를 연결했다.
- 성별: 선택 입력을 받아 가입 API로 저장하고 개인정보에서 수정한다. 출생연도 입력은 제거했다.
- 가입 성공 시 로그인 화면으로 돌아와 가입한 아이디를 채운다. 비밀번호는 비운다.
- 비밀번호 찾기는 준비 중이며, 마이페이지의 배송·반품 안내는 실제 조회·신청 화면으로 이동하는 방법을 안내한다.

로그인한 것으로 처리하는 데모 로직이나 존재하지 않는 중복 확인 API 호출은 없다.
기존 `/auth/login`은 직원 전용이므로 고객 인증에 사용하지 않는다.
로그인 성공·실패·홈 이동·로그아웃은 HTTP 응답과 DB 연결을 대체한 테스트로 검증한다.
실제 MySQL 환경에서의 회원가입·로그인은 별도 확인이 필요하다.

## 코드 위치

- `frontend/lib/view/customer/login/customer_login_screen.dart`: 로그인 화면
- `frontend/lib/view/customer/login/customer_signup_screen.dart`: 회원가입 화면
- `frontend/lib/view/customer/home_screen.dart`: 인증 성공 후 홈과 로그아웃
- `frontend/lib/view/customer/home/home_widgets.dart`: 홈 배너·카테고리·장식 일러스트
- `frontend/lib/view/customer/product/product_list.dart`: 검색·정렬·가격 및 카테고리 필터
- `frontend/lib/view/customer/product/product_detail.dart`: 상세·옵션·수량 선택
- `frontend/lib/view/customer/product/product_widgets.dart`: 상품 카드·하단 메뉴·장바구니 이동
- `frontend/lib/view/customer/product/product_cart_screen.dart`: 장바구니 페이지
- `frontend/lib/view/customer/product/cart_item_card.dart`: 장바구니 상품 편집 카드
- `frontend/lib/view/customer/order/check_screen.dart`: 배송지·상품 확인·주문 확정
- `frontend/lib/view/customer/order/checkout_widgets.dart`: 주문 단계별 공통 구성요소와 주문 전용 테마
- `frontend/lib/vm/customer/checkout_flow_handler.dart`: 단계·결제수단·동의 관리와 변경 시 동의 초기화
- `frontend/lib/view/customer/order/complete_screen.dart`: 주문 완료와 서버 응답 금액 표시
- `frontend/lib/view/customer/order/list_screen.dart`, `detail_screen.dart`: 구매 내역 조회
- `frontend/lib/view/customer/mypage/mypage_screen.dart`: 마이페이지
- `frontend/lib/view/customer/mypage/profile_edit_screen.dart`: 개인정보·기본 주소 수정
- `frontend/lib/service/customer/customer_order_service.dart`, `frontend/lib/vm/customer/order_handler.dart`: 주문 API와 결제 상태 관리
- `frontend/lib/vm/customer/customer_handler.dart`: `AsyncNotifier<Customers?>`로 로그인·로그아웃과 고객 정보 관리
- `frontend/lib/vm/customer/auth/customer_registration_model.dart`: 회원가입 전용 `AsyncNotifier<String?>`
- `frontend/lib/vm/customer/profile/customer_list_model.dart`: 기존 고객 조회·등록·수정·탈퇴 상태 관리
- `frontend/lib/vm/customer/customer_providers.dart`: HTTP 클라이언트·서비스 의존성 주입
- `frontend/lib/vm/customer/product_handler.dart`: 상품 로딩·검색·필터·정렬 상태
- `frontend/lib/vm/customer/product_search_handler.dart`: 최근 검색어 관리
- `frontend/lib/vm/customer/cart_handler.dart`: 장바구니 수량·선택 상태
- `frontend/lib/vm/customer/cart_persistence_handler.dart`: 장바구니 서버 저장·조회·삭제와 실패 상태 관리
- `frontend/lib/service/customer/customer_cart_service.dart`: 기존 장바구니 API 폼 요청
- `frontend/lib/vm/customer/checkout_handler.dart`: 결제 화면 배송지 상태
- `frontend/lib/vm/customer/customer_auth_validation.dart`: 입력값 검증
- `frontend/lib/service/customer/customer_auth_service.dart`: 가입 및 고객 로그인 API 요청
- `frontend/lib/service/customer/customer_service.dart`: 기존 고객 조회·수정·탈퇴 API 요청
- `frontend/lib/service/customer/customer_catalog_service.dart`: 고객 상품 조회 API 요청
- `frontend/lib/model/customer/customers.dart`: 고객 정보 모델 (`Customers`)

모델은 `students.dart` 예시와 같이 필드·생성자·`fromJson()`·`toJson()`으로 구성한다.
고객번호·로그인 아이디·이름·이메일·전화번호·주소·성별·보유 마일리지·계정 상태를 담는다.
조회 API의 `phone_number`도 모델의 `phone`으로 읽으며, 응답에 없는 계정 상태는 빈 값으로 유지한다.
`toJson()`은 고객 정보만 반환하고, 비밀번호는 가입 요청용 `toForm()`에만 포함한다.
성별은 선택 저장 항목이며 가입·로그인·개인정보 수정에 연결한다. 출생연도는 처리하지 않는다.

첨부 `riverpod_json_movie-main.zip`의 `ProviderScope`, `ConsumerWidget`,
`AsyncNotifierProvider`, `AsyncValue.guard` 구조를 사용한다.
로그인·가입 화면은 입력 컨트롤러의 수명을 관리하기 위해 `ConsumerStatefulWidget`으로 구성한다.
로그인 상태와 회원가입 결과는 별도 Provider로 분리하며, 가입 성공을 로그인으로 처리하지 않는다.
로그인 화면에서는 전체 고객 목록을 가져오지 않는다.

## 고객 로그인 API

`POST /customer_login`에 `login_id`, `password` 폼 필드를 보낸다.
로그인 ID는 앞뒤 공백을 제거하고, 비밀번호 공백은 그대로 유지한다.
가입 시 저장된 Argon2 해시를 `pwdlib`로 검증하고 최신 계정 상태가 `ACTIVE`인 경우만 성공한다.
응답은 `{"result":"OK","customer":{...},"message":"로그인 완료"}`이며 비밀번호·해시는 제외한다.
아이디 또는 비밀번호가 틀리면 같은 401 오류를, 비활성 계정에는 403 오류를 반환한다.
데이터베이스 장애 시에는 내부 상세 정보를 제외한 503 오류를 반환한다.
로그아웃 시 앱 메모리의 고객 정보를 제거하며, 토큰 발급·영구 로그인은 이번 범위에 포함하지 않는다.

## 기존 회원가입 API 요청

기존 API가 요구하는 폼 필드 일곱 개를 모두 보낸다.

| 필드 | 값 |
| --- | --- |
| `customer_id` | 프런트엔드에서 생성한 `cus_` + 128비트 보안 난수의 16진수 문자열 |
| `login_id` | 입력한 아이디 |
| `password` | 입력한 비밀번호. 앞뒤 공백을 임의로 제거하지 않음 |
| `customer_name` | 이름 |
| `email` | 이메일 |
| `address` | 기본 주소 |
| `phone` | 전화번호 |

고객번호는 한 요청마다 생성하며 기존 API의 최대 60자 제한 안에 들어간다.
이메일·전화번호는 기존 API의 필수 필드이므로 화면 아래에 배치했다.
중복 아이디·이메일 등의 409 오류는 가입 화면에서 안내한다.
아이디는 `GET /customer_login_id_available?login_id=...`로 확인하며 수정하면 재확인이 필요하다. 선택 성별(`gender`)을 전송하며 출생연도 필드는 보내지 않는다. 주소는 우편번호 API 검색 결과와 상세주소를 합쳐 최대 500자로 저장한다.

## 배송지 변경

- 결제 화면의 `주문 배송 정보 변경 → 우편번호 · 주소 검색`에서 첨부 예제와 같은 Daum 우편번호 검색을 사용한다. 선택한 우편번호·주소에 상세주소를 합쳐 반영한다. 검색 취소 시 입력값을 유지하며, 직접 입력도 가능하다. 주문 화면에서는 현재 배송지를 표시한다.
- 결제 전 배송지 변경은 이번 주문을 위한 화면 상태이다. 주문 확정 시 선택한 주소·수령인·연락처·배송 요청사항을 `orders_pay`로 전송해 주문에 저장한다.
- 결제 화면의 `주문 배송 정보 변경`은 현재 결제 중인 주문의 배송 정보 편집창을 연다. 이미 저장된 주문은 구매 상세의 `배송 주소 변경`에서 선택해 배송 정보를 MySQL에 저장한다. 회원 기본 정보는 수정하지 않는다.
- `PUT /customer_delivery_update`는 JSON `customer_id`, `order_id`, `shipping_address`와 선택 필드 `shipping_recipient`, `shipping_phone`, `delivery_request`를 받는다. 배송 주소는 공백을 제외한 1~500자이며, 우편번호와 상세주소를 포함한다. 선택 필드를 생략한 기존 클라이언트는 저장된 값을 유지한다.
- `PENDING`, `PAID`, `PREPARING` 상태이며 배송 정보가 아직 등록되지 않은 주문만 수정할 수 있다. 출고 처리와 같은 주문 행을 잠근 뒤 확인하고 갱신한다. 없는 주문이나 고객 번호가 일치하지 않는 주문은 404, 변경 불가능한 상태는 409로 응답한다.
- 현재 회원 로그인은 인증 토큰을 발급하지 않는다. 배송 API도 기존 고객 API와 같은 고객 번호 전달 방식을 사용한다. 회원 번호 확인을 서버 인증으로 간주하면 안 된다.
- `database/migrations/20261030_order_shipping_details.sql`로 주문 수령인·연락처·배송 요청사항 컬럼을 추가했다. 적용 방법과 검증 범위는 [고객 주문 배송 정보](customer-shipping.md)를 참고한다.
- `webview_flutter` 플러그인을 추가했으므로 앱을 완전히 종료한 뒤 다시 실행한다. 주소 검색에는 인터넷 연결과 Android 시스템 WebView가 필요하다. Windows·웹에서는 주소 직접 입력을 사용한다. [WebView 공식 패키지 문서](https://pub.dev/packages/webview_flutter)

```json
{
  "customer_id": "cus_1",
  "order_id": "ord_1",
  "shipping_address": "(04524) 서울 중구 세종대로 110 101호",
  "shipping_recipient": "김소담",
  "shipping_phone": "010-1234-5678",
  "delivery_request": "문 앞에 놓아 주세요."
}
```

배송 수정 검증은 `backend`에서 `python -m unittest discover -s tests -p test_customer_delivery_update.py -v`, 프런트 검증은 `frontend`에서 `flutter test test/customer_delivery_test.dart`로 실행한다. 실제 사용자 주문을 수정하지 않고 HTTP·DB 모의 객체로 검증한다.

## 구매 내역·배송 현황

구매 내역 목록은 상품 사진·주문 상태·구매 당시 금액을 카드로 표시한다. 상품명·주문번호 검색과 주문 상태 필터를 제공한다. 구매 상세는 선택 상품의 구매번호·수량·옵션·당시 가격과 주문 전체 금액·배송 주소를 표시한다. 재고 배치별 구매항목은 같은 상품·가격·판매옵션·배송 건끼리 묶어 표시하되, 반품은 실제 구매항목 번호별로 신청한다. 상품 사진·브랜드·용량은 현재 카탈로그에서 보충하며 사진 연결이 없으면 기본 아이콘을 사용한다. 현재 판매 가격으로 과거 주문 금액을 덮어쓰지 않는다.

마이페이지의 배송 현황 메뉴와 구매 상세의 배송 현황 보기에서 기존 `GET /customer_delivery_select`를 사용한다. 준비·배송 중·수령 완료별 필터와 분할 배송 선택, 실제 주문 접수·출발·도착 시각을 표시한다. 새로고침은 서버에 다시 조회한다. 운송장 이동 기록이나 실시간 위치는 API에 없으므로 만들지 않는다. 상태만 있고 날짜가 없는 단계에는 날짜 미제공을 표시한다.

## 반품 신청·진행 조회

사용자가 승인한 백엔드 최소 수정으로 `backend/main.py`에 고객 반품 라우터를 등록하고 `backend/routers/customer/return_api.py`를 보완했다. DB 스키마와 관리자 반품 처리 API는 유지한다.

- `POST /return_requests`: JSON `customer_id`, `order_item_id`, `return_reason`(1~500자), `return_quantity`(양의 정수)를 받는다. 주문상품과 고객번호가 일치하는 행을 잠그고, 기존과 같이 `SHIPPED`·`DELIVERED`·`RETURNED` 주문에 대해서만 신청한다. 반려된 신청을 제외한 기존 신청 수량을 차감해 잔여 수량을 확인한다. 성공은 HTTP 201이며 `REQUESTED`·`PENDING`·`WAITING` 상태로 저장한다.
- `GET /return_requests?customer_id=...&order_item_id=...`: 고객별 반품과 수거·검수·환불 상태를 조회한다. `order_item_id`는 선택 필터다. 고객 화면에서 관리자 전체 조회 API를 사용하지 않는다. 고객번호 전달 방식은 기존 고객 API와 동일하며 인증 토큰 발급 방식은 변경하지 않았다.
- 구매 상세 → 반품 신청에서 사유·상세 내용·수량·확인을 입력한다. 이미 신청된 수량과 현재 주문 상태를 확인하고, 서버 성공 응답 후에만 결과 화면으로 이동한다. 재고 배치가 나뉜 상품은 구매항목을 선택한다.
- 결과 화면은 실제 접수·승인·회수·본사 수령·검수 상태와 별도의 환불 상태를 표시한다. 반품 신청 성공을 환불 완료로 간주하지 않는다. 관리자에게서 등록되지 않은 날짜나 결과는 대기·미제공으로 표시한다.
- 중복 클릭을 막고, 통신 중단 등으로 저장 결과를 알 수 없을 때는 같은 세션에서 해당 항목의 재전송을 막아 내역 확인을 안내한다. 앱 재시작까지 포함하는 서버 멱등성 키는 이번 변경에 포함하지 않았다.

검증: `backend`에서 `python -m unittest discover -s tests -p test_customer_returns.py -v`. 실제 고객의 반품 데이터를 자동 생성하지 않고 모의 DB·HTTP로 검증한다. 실행 중인 서버의 라우터 등록과 빈 테스트 고객 조회, 기존 반품 테이블 컬럼은 읽기 전용으로 확인했다.

## 찜하기 제거

2026-10-30 요청에 따라 상품 카드·상세·마이페이지의 찜 버튼·메뉴·목록·상태 관리를 제거했다.

## 리뷰·별점

기존 `backend/routers/customer/review.py`의 경로와 폼 요청 방식을 유지하면서 배송 완료 확인과 입력 검증을 보완했다. DB 테이블 변경은 없다.

- `GET /reviews_eligibility?customer_id=...&cosmetic_id=...`: 리뷰를 작성할 수 있는 구매 상품을 조회한다. `cosmetic_id`는 선택 필터다. 주문 전체가 `DELIVERED`이거나 해당 구매항목에 연결된 분할 배송이 `DELIVERED`이어야 한다. 취소된 주문은 제외한다. 같은 주문의 다른 상품만 도착한 경우에는 작성 권한을 부여하지 않는다.
- `POST /reviews_upload`: `customer_id`, `cosmetic_id`, `review_content`, `rating` 폼을 받는다. 배송 완료 여부를 서버에서 재확인하고 리뷰와 1~5점 정수 별점을 함께 저장한다. 내용은 앞뒤 공백을 제외하고 1~2000자이다. 기존 고객·상품 고유키에 따라 상품당 리뷰 한 개를 허용하며 중복은 409로 안내한다.
- `PUT /reviews_update`: `review_id`, `customer_id`, `review_content`, `rating` 폼으로 본인 리뷰를 수정한다. `DELETE /reviews_delete`는 `review_id`, `customer_id` 폼을 받는다. 해당 리뷰를 잠근 뒤 작성자 번호를 확인하며 존재하지 않거나 다른 고객의 리뷰를 변경하지 않는다. 수정 내용이 같아도 정상 응답하고 삭제는 실제 한 행을 삭제했을 때만 성공한다.
- `GET /reviews_select?cosmetic_id=...`로 상품 리뷰를, `customer_id=...`로 내 리뷰를 조회한다. 기존 고객번호 전달 방식과 공개 리뷰 조회를 유지하며 인증 토큰 방식은 바꾸지 않았다.

구매 상세의 리뷰 버튼과 마이페이지 `리뷰 내역 → 작성 가능한 상품`에서 배송 완료 상품의 리뷰를 작성한다. `내 리뷰`에서는 수정·삭제할 수 있으며 삭제 전 확인을 받는다. 상품 상세에서도 본인의 리뷰만 관리 버튼을 표시한다.

상품 상세 상단에 평균·리뷰 수를 표시하고 누르면 본문의 리뷰 영역으로 이동한다. 본문에는 전체 리뷰의 평균, 1~5점별 개수·비율과 최신 리뷰를 표시한다. 5개 이후에는 더 보기를 제공한다. 등록·수정·삭제 성공 뒤 서버 목록을 다시 조회하여 집계를 갱신하며 실패를 성공으로 표시하지 않는다. 리뷰가 없을 때는 평균을 `—`로 표시하고 조회 실패와 빈 목록을 구분한다. 다른 작성자의 이름은 화면에서 일부 가린다. 예시 상품에는 리뷰 API를 연결하지 않는다.

주요 위치: `frontend/lib/model/customer/review.dart`, `frontend/lib/service/customer/customer_review_service.dart`, `frontend/lib/vm/customer/review_handler.dart`, `frontend/lib/view/customer/review/`. 검증은 `backend`에서 `python -m unittest discover -s tests -p test_customer_reviews.py -v`, `frontend`에서 `flutter test test/customer_reviews_test.dart`로 실행한다. 실제 고객의 리뷰를 자동으로 등록·수정·삭제하지 않고 모의 DB와 HTTP로 검증했다. 리뷰 테이블 컬럼·고유키와 실행 중인 서버의 빈 테스트 고객 작성 가능 조회는 읽기 전용으로 확인했다.

## 실행

백엔드는 기존 `.env`의 DB 설정을 그대로 사용한다.

```powershell
cd backend
python -m uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

Android 에뮬레이터는 `http://10.0.2.2:8000`, 나머지 환경은 `http://127.0.0.1:8000`으로 요청한다.
Android 디버그 빌드만 로컬 HTTP를 허용한다. 실물 기기에서는 PC 주소를 지정한다.

```powershell
cd frontend
flutter run --dart-define=API_BASE_URL=http://192.168.0.10:8000
```

배포 빌드에는 `--dart-define=API_BASE_URL=https://실제서버주소`를 사용한다.

## 검증

```powershell
# frontend 폴더
flutter test
flutter analyze
flutter build apk --debug
```

테스트는 HTTP 연결을 모의 객체로 대체한다. 실제 MySQL·기기 네트워크 연동은 별도 확인이 필요하다.
디버그 APK는 `frontend/build/app/outputs/flutter-apk/app-debug.apk`에 생성된다.

서체는 Google Fonts의 Noto Sans KR이다. 원본은
`https://github.com/google/fonts/tree/main/ofl/notosanskr`이며
라이선스는 `frontend/assets/fonts/OFL.txt`에 보관한다.
# 고객 화면 디자인과 검색 별점순 정렬

- 고객 화면의 공용 테마는 흰 배경, 민트 강조색, 회색 구분선으로 통일한다. 로그인·가입, 장바구니·결제, 마이페이지, 구매·배송·반품·리뷰 화면에도 같은 테마를 사용한다.
- 홈·검색의 상품 카드는 기본 3열이며, 작은 화면이나 확대된 글자에서는 2열로 전환한다. 상품 사진의 찜 버튼은 제거했다.
- 메인 카테고리 탭과 검색 필터는 `전체 → 스킨 → 로션 → 크림`을 공통 사용한다. DB 세부 분류를 우선 사용하며, 기존 스킨케어 등 대분류만 있으면 상품명에서 스킨·토너, 로션·에멀전, 크림을 구분한다. 분류되지 않은 상품은 전체 목록에서 계속 볼 수 있으며 DB 값은 변경하지 않는다.
- 상세 화면은 큰 상품 사진, 브랜드·상품명·실제 가격·별점, 고정 용량과 수량, 리뷰 목록을 표시한다. 하단의 장바구니·구매하기 버튼을 고정한다. 수량은 결제 단계에서 선택한다. 임의 할인율·정상가·회원 할인가는 표시하지 않는다.
- 구매하기는 장바구니 API 저장 성공 후 현재 상품만 선택해 기존 결제 화면으로 이동한다. 다른 장바구니 상품은 보존하며, 실제 결제 요청은 기존 최종 동의 단계에서만 실행한다.
- 홈 필터와 검색 정렬에 `별점 높은 순`을 추가한다. 기존 `GET /reviews_select`를 한 번 호출해 실제 리뷰의 평균을 상품번호별로 집계한다. 평균 동점은 리뷰 개수순, 그다음 기존 목록 순서를 유지한다. 용량별 카드는 같은 상품번호의 별점을 사용하며 리뷰 없는 상품은 마지막에 표시한다.
- 별점 조회는 별점순을 선택했을 때만 실행하며, 조회 중·실패 시 정렬되지 않은 목록을 별점순으로 표시하지 않는다. 실패 시 다시 조회할 수 있고 리뷰 등록·수정·삭제 시 집계를 무효화해 재조회한다. 백엔드·DB 스키마는 변경하지 않는다.
