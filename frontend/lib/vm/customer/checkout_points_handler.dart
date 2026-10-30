import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'cart_handler.dart';
import 'customer_handler.dart';
import 'point_handler.dart';

class CheckoutPointSelection {
  const CheckoutPointSelection({this.amount = 0, this.useAll = false});
  final int amount;
  final bool useAll;
}

class CheckoutPointSummary {
  const CheckoutPointSummary({
    required this.balance,
    required this.maximum,
    required this.used,
    required this.payable,
    required this.ready,
    required this.canContinue,
  });
  final int balance;
  final int maximum;
  final int used;
  final double payable;
  final bool ready;
  final bool canContinue;
}

class CheckoutPointsHandler extends Notifier<CheckoutPointSelection> {
  @override
  CheckoutPointSelection build() {
    ref.watch(
      customerHandlerProvider.select((value) => value.value?.customerId),
    );
    return const CheckoutPointSelection();
  }

  // Function: 이번 주문에서만 사용할 정수 포인트를 잔액·상품 금액 이내로 제한한다.
  void edit(int amount) {
    final balance = ref.read(customerPointsProvider).value?.balance ?? 0;
    final maximum = math.min(
      balance,
      math.max(0, ref.read(selectedCartTotalProvider).floor()),
    );
    state = CheckoutPointSelection(amount: amount.clamp(0, maximum));
  }

  void useAll(bool value) => state = CheckoutPointSelection(useAll: value);
}

final checkoutPointsProvider =
    NotifierProvider.autoDispose<CheckoutPointsHandler, CheckoutPointSelection>(
      CheckoutPointsHandler.new,
    );

final checkoutPointSummaryProvider = Provider.autoDispose<CheckoutPointSummary>(
  (ref) {
    final selection = ref.watch(checkoutPointsProvider);
    final account = ref.watch(customerPointsProvider);
    final customer = ref.watch(customerHandlerProvider).value;
    final total = ref.watch(selectedCartTotalProvider);
    final balance = account.value?.balance ?? customer?.pointsBalance ?? 0;
    final maximum = math.min(balance, math.max(0, total.floor()));
    final used = selection.useAll
        ? maximum
        : selection.amount.clamp(0, maximum);
    final ready = account.hasValue && !account.isLoading && !account.hasError;
    return CheckoutPointSummary(
      balance: balance,
      maximum: maximum,
      used: used,
      payable: math.max(0.0, total - used),
      ready: ready,
      canContinue: ready || (!selection.useAll && selection.amount == 0),
    );
  },
);
