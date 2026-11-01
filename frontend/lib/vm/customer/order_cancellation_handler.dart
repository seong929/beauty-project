// 기능: 주문 취소와 구매·배송·포인트·재고 캐시 갱신.
// 상태 계층: 변경은 Notifier/AsyncNotifier에서 발행하고 View는 watch, 동작은 read로 연결한다.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'customer_handler.dart';
import 'order_handler.dart';
import 'delivery_handler.dart';
import 'point_handler.dart';
import 'product_handler.dart';

class CustomerOrderCancellationHandler extends AsyncNotifier<String?> {
  /// Function: Provider가 처음 구독될 때 초기 상태 또는 초기 조회 결과를 준비한다.
  @override
  String? build() {
    ref.watch(
      customerHandlerProvider.select((value) => value.value?.customerId),
    );
    return null;
  }

  // Function: 중복 요청을 막고 취소 결과에 따라 구매·배송·포인트·재고 조회를 갱신한다.
  Future<bool> cancel(String customerId, String orderId) async {
    if (state.isLoading ||
        ref.read(customerHandlerProvider).value?.customerId != customerId) {
      return false;
    }
    state = const AsyncLoading();
    try {
      await ref.read(customerOrderServiceProvider).cancel(customerId, orderId);
      if (!_sameCustomer(customerId)) return false;
      _refresh(orderId);
      state = AsyncData(orderId);
      return true;
    } catch (error, stack) {
      if (!_sameCustomer(customerId)) return false;
      _refresh(orderId);
      state = AsyncError(error, stack);
      rethrow;
    }
  }

  bool _sameCustomer(String id) =>
      ref.mounted && ref.read(customerHandlerProvider).value?.customerId == id;

  /// Function: 관련 Provider를 무효화해 최신 서버 상태를 다시 조회한다.
  void _refresh(String orderId) {
    ref.invalidate(customerOrdersProvider);
    ref.invalidate(deliveryOrdersProvider);
    ref.invalidate(deliveryRecordsProvider(orderId));
    ref.invalidate(customerPointsProvider);
    ref.invalidate(productHandlerProvider);
  }
}

final customerCancellationProvider =
    AsyncNotifierProvider<CustomerOrderCancellationHandler, String?>(
      CustomerOrderCancellationHandler.new,
    );
