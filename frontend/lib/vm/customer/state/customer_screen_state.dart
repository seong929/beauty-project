// 기능: 화면 선택·입력에 쓰는 불변 State와 copyWith.
// 상태 계층: 변경은 Notifier/AsyncNotifier에서 발행하고 View는 watch, 동작은 read로 연결한다.

/// 카운터 예제처럼 화면의 선택 값도 불변 객체로 보관한다.
class CustomerChoiceState<T> {
  const CustomerChoiceState(this.value);
  final T value;

  /// null을 포함한 새 선택 값을 복사한다. 기존 객체는 변경하지 않는다.
  CustomerChoiceState<T> copyWith({required T value}) =>
      CustomerChoiceState(value);
}

/// 로그인·회원가입의 비밀번호 표시, 가입 시도와 성별 선택 상태.
/// 비밀번호 원문과 TextEditingController는 저장하지 않는다.
class CustomerAuthFormState {
  const CustomerAuthFormState({
    this.showPassword = false,
    this.showConfirmation = false,
    this.attemptedSubmit = false,
    this.openingSignup = false,
    this.searchingAddress = false,
    this.gender = 'UNDISCLOSED',
  });
  final bool showPassword;
  final bool showConfirmation;
  final bool attemptedSubmit;
  final bool openingSignup;
  final bool searchingAddress;
  final String gender;

  /// Function: 원본을 수정하지 않고 바뀐 값만 반영한 새 상태를 반환한다.
  CustomerAuthFormState copyWith({
    bool? showPassword,
    bool? showConfirmation,
    bool? attemptedSubmit,
    bool? openingSignup,
    bool? searchingAddress,
    String? gender,
  }) => CustomerAuthFormState(
    showPassword: showPassword ?? this.showPassword,
    showConfirmation: showConfirmation ?? this.showConfirmation,
    attemptedSubmit: attemptedSubmit ?? this.attemptedSubmit,
    openingSignup: openingSignup ?? this.openingSignup,
    searchingAddress: searchingAddress ?? this.searchingAddress,
    gender: gender ?? this.gender,
  );
}

/// 리뷰 편집의 별점과 내용. 저장 결과·실패는 reviewMutationProvider의 AsyncValue로 구분한다.
class CustomerReviewDraftState {
  const CustomerReviewDraftState({this.rating = 0, this.content = ''});
  final int rating;
  final String content;

  /// Function: 원본을 수정하지 않고 바뀐 값만 반영한 새 상태를 반환한다.
  CustomerReviewDraftState copyWith({int? rating, String? content}) =>
      CustomerReviewDraftState(
        rating: rating ?? this.rating,
        content: content ?? this.content,
      );
}

/// 구매 내역 검색어와 주문 상태 필터를 하나의 불변 상태로 관리한다.
class CustomerOrderListState {
  const CustomerOrderListState({this.query = '', this.status = 'ALL'});
  final String query;
  final String status;

  /// Function: 원본을 수정하지 않고 바뀐 값만 반영한 새 상태를 반환한다.
  CustomerOrderListState copyWith({String? query, String? status}) =>
      CustomerOrderListState(
        query: query ?? this.query,
        status: status ?? this.status,
      );
}

/// 반품의 상품·사유·확인 상태. 입력이 바뀌면 확인을 취소해 재확인을 받는다.
class CustomerReturnDraftState {
  const CustomerReturnDraftState({
    this.reason,
    this.itemId,
    this.confirmed = false,
  });
  final String? reason;
  final String? itemId;
  final bool confirmed;

  /// Function: 원본을 수정하지 않고 바뀐 값만 반영한 새 상태를 반환한다.
  CustomerReturnDraftState copyWith({
    String? reason,
    String? itemId,
    bool? confirmed,
    bool clearReason = false,
    bool clearItem = false,
  }) => CustomerReturnDraftState(
    reason: clearReason ? null : reason ?? this.reason,
    itemId: clearItem ? null : itemId ?? this.itemId,
    confirmed: confirmed ?? this.confirmed,
  );
}

/// 우편번호 WebView의 연결·실패·결과 반환 상태. 컨트롤러와 타이머는 View에서 해제한다.
class CustomerPostalSearchState {
  const CustomerPostalSearchState({
    this.loading = true,
    this.returned = false,
    this.error,
  });
  final bool loading;
  final bool returned;
  final String? error;

  /// Function: 원본을 수정하지 않고 바뀐 값만 반영한 새 상태를 반환한다.
  CustomerPostalSearchState copyWith({
    bool? loading,
    bool? returned,
    String? error,
    bool clearError = false,
  }) => CustomerPostalSearchState(
    loading: loading ?? this.loading,
    returned: returned ?? this.returned,
    error: clearError ? null : error ?? this.error,
  );
}
