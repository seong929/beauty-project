import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'customer_handler.dart';
import 'order_handler.dart';
import 'delivery_handler.dart';
import 'point_handler.dart';
import 'product_handler.dart';

class CustomerOrderCancellationHandler extends AsyncNotifier<String?> {
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
