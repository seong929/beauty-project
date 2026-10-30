import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beauty_project/model/customer/order.dart';
import 'package:beauty_project/model/customer/return_request.dart';
import 'package:beauty_project/service/customer/customer_auth_service.dart';
import 'package:beauty_project/service/customer/customer_return_service.dart';
import 'customer_handler.dart';
import 'customer_providers.dart';

/// 반려된 신청만 수량을 반환한다. 환불·수거 상태는 반품 가능 수량에 영향을 주지 않는다.
int remainingReturnQuantity({
  required CustomerOrderLine item,
  required Iterable<CustomerReturnRequest> requests,
}) {
  final used = requests
      .where(
        (request) => request.itemId == item.id && request.status != 'REJECTED',
      )
      .fold<int>(0, (sum, request) => sum + request.quantity);
  return (item.quantity - used).clamp(0, item.quantity);
}

final customerReturnServiceProvider = Provider<CustomerReturnService>(
  (ref) => CustomerReturnService(
    client: ref.watch(customerHttpClientProvider),
    baseUrl: ref.watch(customerApiBaseUrlProvider),
  ),
);

final customerReturnsProvider = FutureProvider.autoDispose
    .family<List<CustomerReturnRequest>, String?>((ref, itemId) {
      final id = ref.watch(
        customerHandlerProvider.select((session) => session.value?.customerId),
      );
      if (id == null || id.isEmpty) {
        throw const CustomerAuthException('로그인 후 반품 내역을 확인해 주세요.');
      }
      return ref.watch(customerReturnServiceProvider).fetch(id, itemId: itemId);
    });

class CustomerReturnHandler extends AsyncNotifier<CustomerReturnRequest?> {
  final _uncertainItems = <String>{};
  String? activeItemId;
  bool reviewRequired(String itemId) => _uncertainItems.contains(itemId);

  @override
  CustomerReturnRequest? build() {
    ref.watch(
      customerHandlerProvider.select((session) => session.value?.customerId),
    );
    _uncertainItems.clear();
    activeItemId = null;
    return null;
  }

  Future<CustomerReturnRequest?> submit({
    required CustomerOrder order,
    required CustomerOrderLine item,
    required String reason,
    required int quantity,
  }) async {
    if (state.isLoading || reviewRequired(item.id)) return null;
    activeItemId = item.id;
    final id = ref.read(customerHandlerProvider).value?.customerId;
    if (id == null ||
        id != order.customerId ||
        !order.items.any((line) => line.id == item.id) ||
        !const {'SHIPPED', 'DELIVERED', 'RETURNED'}.contains(order.status) ||
        quantity < 1 ||
        quantity > item.quantity) {
      state = AsyncError(
        const CustomerAuthException('반품할 구매항목과 수량, 배송 상태를 확인해 주세요.'),
        StackTrace.current,
      );
      return null;
    }
    state = const AsyncLoading();
    try {
      final result = await ref
          .read(customerReturnServiceProvider)
          .create(
            customerId: id,
            itemId: item.id,
            reason: reason,
            quantity: quantity,
          );
      if (!ref.mounted ||
          ref.read(customerHandlerProvider).value?.customerId != id) {
        return null;
      }
      ref.invalidate(customerReturnsProvider);
      state = AsyncData(result);
      return result;
    } catch (error, stack) {
      if (!ref.mounted ||
          ref.read(customerHandlerProvider).value?.customerId != id) {
        return null;
      }
      if (error is ReturnResultUncertain) _uncertainItems.add(item.id);
      ref.invalidate(customerReturnsProvider);
      state = AsyncError(error, stack);
      return null;
    }
  }
}

final customerReturnHandlerProvider =
    AsyncNotifierProvider<CustomerReturnHandler, CustomerReturnRequest?>(
      CustomerReturnHandler.new,
    );
