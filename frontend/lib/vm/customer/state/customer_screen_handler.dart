// 기능: 화면 인스턴스별 Notifier·AsyncNotifier 상태와 autoDispose 수명 관리.
// 상태 계층: 변경은 Notifier/AsyncNotifier에서 발행하고 View는 watch, 동작은 read로 연결한다.

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'customer_screen_state.dart';
export 'customer_screen_state.dart';

/// 예제의 Notifier 방식: state = state.copyWith(...)로만 새 화면 상태를 발행한다.
class CustomerChoiceHandler<T> extends Notifier<CustomerChoiceState<T>> {
  CustomerChoiceHandler(this.initial);
  final T initial;
  @override
  CustomerChoiceState<T> build() => CustomerChoiceState(initial);
  void select(T value) => state = state.copyWith(value: value);
}

class CustomerAuthFormHandler extends Notifier<CustomerAuthFormState> {
  /// Function: Provider가 처음 구독될 때 초기 상태 또는 초기 조회 결과를 준비한다.
  @override
  CustomerAuthFormState build() => const CustomerAuthFormState();

  /// Function: 새 State로 비밀번호 표시 여부를 전환한다.
  void togglePassword() =>
      state = state.copyWith(showPassword: !state.showPassword);

  /// Function: 새 State로 비밀번호 확인의 표시 여부를 전환한다.
  void toggleConfirmation() =>
      state = state.copyWith(showConfirmation: !state.showConfirmation);
  void openingSignup(bool value) =>
      state = state.copyWith(openingSignup: value);
  void searchingAddress(bool value) =>
      state = state.copyWith(searchingAddress: value);

  /// Function: 폼 유효성 검사 안내를 표시할 가입 시도 상태를 기록한다.
  void attemptSubmit() => state = state.copyWith(attemptedSubmit: true);
  void selectGender(String value) => state = state.copyWith(gender: value);
}

/// 영화 예제처럼 실행 중·성공·실패를 별도 bool/error 필드 대신 AsyncValue로 표현한다.
class CustomerOperationHandler extends AsyncNotifier<void> {
  /// Function: Provider가 처음 구독될 때 초기 상태 또는 초기 조회 결과를 준비한다.
  @override
  FutureOr<void> build() {}
  void begin() {
    // AsyncLoading은 이전 오류를 보존할 수 있어 재시도 전에 오류 이력을 지운다.
    state = const AsyncData(null);
    state = const AsyncLoading();
  }

  /// 실패는 화면에 남겨 두고, 정상 실행 잠금만 해제한다. 재시도 begin에서 오류를 지운다.
  void finish() {
    if (!state.hasError) state = const AsyncData(null);
  }

  void fail(Object error) => state = AsyncError(error, StackTrace.current);
}

class CustomerReviewDraftHandler extends Notifier<CustomerReviewDraftState> {
  CustomerReviewDraftHandler(this.initial);
  final CustomerReviewDraftState initial;

  /// Function: Provider가 처음 구독될 때 초기 상태 또는 초기 조회 결과를 준비한다.
  @override
  CustomerReviewDraftState build() => initial;

  /// 별점은 1~5점만 허용한다. 미선택 초기 값은 0이다.
  void rate(int value) {
    if (value >= 1 && value <= 5) state = state.copyWith(rating: value);
  }

  void editContent(String value) => state = state.copyWith(content: value);
}

class CustomerOrderListHandler extends Notifier<CustomerOrderListState> {
  /// Function: Provider가 처음 구독될 때 초기 상태 또는 초기 조회 결과를 준비한다.
  @override
  CustomerOrderListState build() => const CustomerOrderListState();
  void search(String value) => state = state.copyWith(query: value);
  void filter(String value) => state = state.copyWith(status: value);
}

class CustomerReturnDraftHandler extends Notifier<CustomerReturnDraftState> {
  /// Function: Provider가 처음 구독될 때 초기 상태 또는 초기 조회 결과를 준비한다.
  @override
  CustomerReturnDraftState build() => const CustomerReturnDraftState();

  /// Function: 반품 대상 상품을 변경하고 기존 확인 동의를 해제한다.
  void selectItem(String? value) => state = state.copyWith(
    itemId: value,
    clearItem: value == null,
    confirmed: false,
  );

  /// Function: 반품 사유를 변경하고 기존 확인 동의를 해제한다.
  void selectReason(String? value) => state = state.copyWith(
    reason: value,
    clearReason: value == null,
    confirmed: false,
  );
  void confirm(bool value) => state = state.copyWith(confirmed: value);
}

class CustomerPostalSearchHandler extends Notifier<CustomerPostalSearchState> {
  CustomerPostalSearchHandler(this.supported);
  final bool supported;

  /// Function: Provider가 처음 구독될 때 초기 상태 또는 초기 조회 결과를 준비한다.
  @override
  CustomerPostalSearchState build() => supported
      ? const CustomerPostalSearchState()
      : const CustomerPostalSearchState(
          loading: false,
          error: '이 기기에서는 주소 검색을 지원하지 않습니다. 이전 화면에서 주소를 직접 입력해 주세요.',
        );
  void start() => state = state.copyWith(loading: true, clearError: true);
  void ready() => state = state.copyWith(loading: false, clearError: true);
  void fail(String message) =>
      state = state.copyWith(loading: false, error: message);

  /// JS 메시지가 여러 번 와도 주소 결과는 한 번만 반환한다.
  void returned() => state = state.copyWith(returned: true);
}

// 화면 인스턴스를 family 키로 써 두 화면의 입력이 섞이지 않게 하고, 닫으면 autoDispose로 정리한다.
final customerAuthFormProvider = NotifierProvider.autoDispose
    .family<CustomerAuthFormHandler, CustomerAuthFormState, Object>(
      (_) => CustomerAuthFormHandler(),
    );
final customerOperationProvider = AsyncNotifierProvider.autoDispose
    .family<CustomerOperationHandler, void, ({Object screen, String action})>(
      (_) => CustomerOperationHandler(),
    );
final customerGenderProvider = NotifierProvider.autoDispose
    .family<
      CustomerChoiceHandler<String>,
      CustomerChoiceState<String>,
      ({Object screen, String initial})
    >((key) => CustomerChoiceHandler(key.initial));
final deliveryListFilterProvider = NotifierProvider.autoDispose
    .family<CustomerChoiceHandler<String>, CustomerChoiceState<String>, Object>(
      (_) => CustomerChoiceHandler('전체'),
    );
final deliveryTrackingSelectionProvider = NotifierProvider.autoDispose
    .family<
      CustomerChoiceHandler<String?>,
      CustomerChoiceState<String?>,
      ({Object screen, String? initial})
    >((key) => CustomerChoiceHandler(key.initial));
final customerReviewTabProvider = NotifierProvider.autoDispose
    .family<CustomerChoiceHandler<bool>, CustomerChoiceState<bool>, Object>(
      (_) => CustomerChoiceHandler(false),
    );
final customerReviewVisibleProvider = NotifierProvider.autoDispose
    .family<CustomerChoiceHandler<int>, CustomerChoiceState<int>, Object>(
      (_) => CustomerChoiceHandler(5),
    );
final customerReviewDraftProvider = NotifierProvider.autoDispose
    .family<
      CustomerReviewDraftHandler,
      CustomerReviewDraftState,
      ({Object screen, int rating, String content})
    >(
      (key) => CustomerReviewDraftHandler(
        CustomerReviewDraftState(rating: key.rating, content: key.content),
      ),
    );
final customerOrderListUiProvider = NotifierProvider.autoDispose
    .family<CustomerOrderListHandler, CustomerOrderListState, Object>(
      (_) => CustomerOrderListHandler(),
    );
final customerReturnDraftProvider = NotifierProvider.autoDispose
    .family<CustomerReturnDraftHandler, CustomerReturnDraftState, Object>(
      (_) => CustomerReturnDraftHandler(),
    );
final customerPostalSearchProvider = NotifierProvider.autoDispose
    .family<
      CustomerPostalSearchHandler,
      CustomerPostalSearchState,
      ({Object screen, bool supported})
    >((key) => CustomerPostalSearchHandler(key.supported));
