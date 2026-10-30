import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'cart_handler.dart';
import 'checkout_handler.dart';
import 'customer_handler.dart';
import 'checkout_stock_handler.dart';
import 'checkout_points_handler.dart';
import 'point_handler.dart';

enum CheckoutStep { information, amount, method, agreement }

enum CheckoutDeliveryRequest {
  none('요청사항 없음'),
  door('문 앞에 놓아주세요.'),
  guard('경비실에 맡겨주세요.'),
  parcelBox('택배함에 넣어주세요.'),
  call('배송 전에 연락해 주세요.'),
  custom('직접 입력');

  const CheckoutDeliveryRequest(this.label);
  final String label;
}

enum CheckoutPaymentMethod {
  naver('N pay', false),
  toss('toss pay', false),
  payco('PAYCO', false),
  kakao('kakao pay', false),
  card('신용카드', true),
  transfer('실시간 계좌이체', true);

  const CheckoutPaymentMethod(this.label, this.selectable);
  final String label;
  // 선택 가능한 항목도 현재는 화면 선택이며 결제 승인 API와 연동되지 않았다.
  final bool selectable;
}

class CheckoutFlowState {
  const CheckoutFlowState({
    this.step = CheckoutStep.information,
    this.method,
    this.purchaseAgreed = false,
    this.privacyAgreed = false,
    this.deliveryRequest = CheckoutDeliveryRequest.none,
    this.customDeliveryRequest = '',
  });

  final CheckoutStep step;
  final CheckoutPaymentMethod? method;
  final bool purchaseAgreed;
  final bool privacyAgreed;
  final CheckoutDeliveryRequest deliveryRequest;
  final String customDeliveryRequest;
  String get deliveryRequestText =>
      deliveryRequest == CheckoutDeliveryRequest.custom
      ? customDeliveryRequest.trim()
      : deliveryRequest.label;
  bool get deliveryRequestValid =>
      deliveryRequest != CheckoutDeliveryRequest.custom ||
      (customDeliveryRequest.trim().isNotEmpty &&
          customDeliveryRequest.length <= 200);
  bool get allAgreed => purchaseAgreed && privacyAgreed;
  bool get canSubmit =>
      step == CheckoutStep.agreement &&
      method?.selectable == true &&
      allAgreed &&
      deliveryRequestValid;

  CheckoutFlowState copyWith({
    CheckoutStep? step,
    CheckoutPaymentMethod? method,
    bool? purchaseAgreed,
    bool? privacyAgreed,
    CheckoutDeliveryRequest? deliveryRequest,
    String? customDeliveryRequest,
  }) => CheckoutFlowState(
    step: step ?? this.step,
    method: method ?? this.method,
    purchaseAgreed: purchaseAgreed ?? this.purchaseAgreed,
    privacyAgreed: privacyAgreed ?? this.privacyAgreed,
    deliveryRequest: deliveryRequest ?? this.deliveryRequest,
    customDeliveryRequest: customDeliveryRequest ?? this.customDeliveryRequest,
  );
}

class CheckoutFlowHandler extends Notifier<CheckoutFlowState> {
  @override
  CheckoutFlowState build() {
    ref.watch(
      customerHandlerProvider.select((session) => session.value?.customerId),
    );
    // 상품·수량·주소가 바뀌면 최종 확인을 다시 받는다.
    ref.listen(selectedCartItemsProvider, (_, _) => _clearAgreements());
    ref.listen(checkoutAddressProvider, (_, _) => _clearAgreements());
    ref.listen(checkoutPointsProvider, (_, _) => _clearAgreements());
    ref.listen(customerPointsProvider, (_, _) => _clearAgreements());
    ref.listen(checkoutStockProvider, (_, next) {
      if (!next.canPurchase) _clearAgreements();
    });
    return const CheckoutFlowState();
  }

  void next() {
    final address = ref.read(checkoutAddressProvider);
    if (address?.isComplete != true ||
        ref.read(selectedCartItemsProvider).isEmpty ||
        ref.read(customerHandlerProvider).value == null ||
        !state.deliveryRequestValid ||
        !ref.read(checkoutPointSummaryProvider).canContinue) {
      return;
    }
    if (!ref.read(checkoutStockProvider).canPurchase) return;
    if (state.step == CheckoutStep.method && state.method == null) return;
    if (state.step.index < CheckoutStep.agreement.index) {
      state = state.copyWith(step: CheckoutStep.values[state.step.index + 1]);
    }
  }

  void previous() {
    if (state.step.index > 0) {
      state = state.copyWith(step: CheckoutStep.values[state.step.index - 1]);
    }
  }

  void reviewItems() => state = state.copyWith(
    step: CheckoutStep.information,
    purchaseAgreed: false,
    privacyAgreed: false,
  );

  void selectMethod(CheckoutPaymentMethod method) {
    if (!method.selectable) return;
    if (method != state.method) {
      state = state.copyWith(
        method: method,
        purchaseAgreed: false,
        privacyAgreed: false,
      );
    }
  }

  void agreeAll(bool value) =>
      state = state.copyWith(purchaseAgreed: value, privacyAgreed: value);
  void agreePurchase(bool value) =>
      state = state.copyWith(purchaseAgreed: value);
  void agreePrivacy(bool value) => state = state.copyWith(privacyAgreed: value);

  void selectDeliveryRequest(CheckoutDeliveryRequest value) {
    if (value == state.deliveryRequest) return;
    state = state.copyWith(
      deliveryRequest: value,
      purchaseAgreed: false,
      privacyAgreed: false,
    );
  }

  void editDeliveryRequest(String value) {
    if (value.length > 200 || value == state.customDeliveryRequest) return;
    state = state.copyWith(
      customDeliveryRequest: value,
      purchaseAgreed: false,
      privacyAgreed: false,
    );
  }

  void _clearAgreements() {
    if (state.purchaseAgreed || state.privacyAgreed) {
      state = state.copyWith(purchaseAgreed: false, privacyAgreed: false);
    }
  }
}

final checkoutFlowProvider =
    NotifierProvider.autoDispose<CheckoutFlowHandler, CheckoutFlowState>(
      CheckoutFlowHandler.new,
    );

// 변경 내용(2026-10-30): 재고 확인 실패·부족 시 다음 단계 진행을 막고 수량 변경 시 최종 동의를 갱신한다.
