# 고객 기능의 Riverpod 구성

적용 경로는 `lib/view/customer`, `lib/vm/customer`, `lib/model/customer`, `lib/service/customer`이다. 별도의 `custormer` 폴더를 만들지 않는다.

## 검수한 예제

- `riverpod_incre_decrement_button-main.zip`: final 필드·copyWith의 불변 State, Notifier·NotifierProvider, 화면의 ref.watch와 버튼의 ref.read(provider.notifier)를 사용한다.
- `riverpod_json_movie-main.zip`: 모델·화면·VM을 분리하고 AsyncNotifier·AsyncNotifierProvider·AsyncValue.guard·when(data/error/loading)으로 HTTP 조회를 관리한다.
- 두 예제에 GetX·ChangeNotifier·Provider 패키지는 없다. 현재 프로젝트의 flutter_riverpod ^3.4.3가 예제와 같아 패키지를 교체할 필요가 없다.

## 기능별 적용

| 기능 | 상태와 처리 |
| --- | --- |
| 로그인·가입 | 기존 로그인·가입 AsyncNotifier를 유지한다. 비밀번호 표시·가입 시도·성별·주소 검색 표시 상태는 CustomerAuthFormState와 Notifier에 둔다. |
| 상품·장바구니 | 상품 조회·서버 장바구니 처리의 AsyncNotifier, 선택·수량·옵션의 Notifier를 사용한다. 필터 창은 독립 draft에서 편집하고 적용할 때 실제 목록을 갱신한다. |
| 결제·포인트 | 기존 결제·취소 AsyncNotifier와 배송지·포인트·단계 Notifier를 사용한다. 확인창·주소 편집의 잠금은 화면·작업별 상태로 분리한다. |
| 구매·배송 조회 | 검색어·주문 상태·배송 필터·배송 건 선택을 불변 State에 보관한다. API 조회의 AsyncValue를 구독한다. |
| 리뷰 | 별점·내용·목록 탭·더 보기 수량은 화면별 Notifier가 관리한다. 등록·수정·삭제는 기존 리뷰 변경 AsyncNotifier를 호출한다. |
| 반품 | 상품·사유·확인 동의를 불변 draft로 관리한다. 입력 변경 시 동의를 해제하고 서버 요청은 기존 반품 AsyncNotifier에 위임한다. |
| 개인정보·배송지 | 저장·주소 검색·오류·성별을 Riverpod 상태로 반영한다. 기존 API와 검증을 유지한다. |
| 우편번호 WebView | 연결·실패·결과 반환을 Notifier가 관리하고 컨트롤러·타이머는 화면이 해제한다. |

## 주요 파일

- `vm/customer/state/customer_screen_state.dart`: 불변 화면 State와 copyWith.
- `vm/customer/state/customer_screen_handler.dart`: 상태 변경 메서드와 화면별 family Provider.
- `vm/customer/state/product_filter_draft_handler.dart`: 필터 창의 적용 전 편집 상태.
- `model/customer`: 순수 API 데이터 모델. 상태관리 패키지나 컨트롤러를 넣지 않는다.
- `service/customer`: HTTP/Firebase 요청과 응답 검증. UI 상태를 직접 수정하지 않는다.
- `view/customer`: ref.watch로 구독하고 사용자 동작을 ref.read(...notifier)로 전달한다. 순수 표시 위젯은 전달받은 데이터를 그린다.

기존 Provider는 서비스 주입·계산에, FutureProvider는 읽기 전용 비동기 조회에 사용한다. 이들도 Riverpod이다. 변경 명령이 있는 비동기 작업은 예제처럼 AsyncNotifier를 사용한다. 화면 작업의 실행 잠금·실패도 CustomerOperationHandler의 AsyncLoading·AsyncData·AsyncError로 표현하고 별도 loading/error 필드를 만들지 않는다. 중복 캐시나 다른 상태관리 패키지를 추가하지 않는다.

## 화면의 수명과 입력

화면 인스턴스를 family 키로 사용하고 autoDispose를 적용한다. 같은 화면을 두 번 열어도 선택이 섞이지 않고 마지막 구독이 끝나면 편집 상태를 정리한다.

폼·입력·포커스·스크롤·WebView 컨트롤러는 위젯의 수명이 필요하므로 ConsumerStatefulWidget에서 생성·해제한다. 비밀번호는 Notifier에 저장하지 않는다. 컨트롤러를 쓴다는 이유로 setState를 호출하지 않으며 화면을 바꾸는 선택·진행·실패는 Riverpod로 갱신한다.

고객 Dart 파일마다 기능·계층 역할을, 주요 처리 메서드에 Function 주석을 추가했다. 이번 변경은 프런트엔드에만 적용하며 백엔드·DB·가격·포인트 정책은 변경하지 않는다.

## 검증

flutter analyze와 flutter test를 실행한다. `test/customer_screen_state_test.dart`는 불변 스냅샷·화면별 상태 분리·autoDispose·필터 취소·별점·반품 재확인·주소 재시도를 검증한다. 기존 화면 테스트로 로그인·가입·결제·취소·배송지·리뷰·반품을 함께 검증한다.
