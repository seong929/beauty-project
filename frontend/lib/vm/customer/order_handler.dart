import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beauty_project/model/customer/order.dart';
import 'package:beauty_project/service/customer/customer_auth_service.dart';
import 'package:beauty_project/service/customer/customer_order_service.dart';
import 'cart_handler.dart';
import 'cart_persistence_handler.dart';
import 'checkout_handler.dart';
import 'customer_handler.dart';
import 'customer_providers.dart';
import 'delivery_handler.dart';
import 'product_handler.dart';

final customerOrderServiceProvider = Provider<CustomerOrderService>(
  (ref) => CustomerOrderService(
    client: ref.watch(customerHttpClientProvider),
    baseUrl: ref.watch(customerApiBaseUrlProvider),
  ),
);

final customerOrdersProvider = FutureProvider<List<CustomerOrder>>((ref) {
  final id = ref.watch(
    customerHandlerProvider.select((value) => value.value?.customerId),
  );
  if (id == null || id.isEmpty) {
    throw const CustomerAuthException('로그인 후 구매 내역을 확인해 주세요.');
  }
  return ref.watch(customerOrderServiceProvider).fetch(id);
});

class CustomerPaymentHandler extends AsyncNotifier<CustomerOrder?> {
  bool _reviewRequired = false;
  bool get reviewRequired => _reviewRequired;

  @override
  CustomerOrder? build() {
    ref.watch(
      customerHandlerProvider.select((value) => value.value?.customerId),
    );
    _reviewRequired = false;
    return null;
  }

  Future<CustomerOrder?> pay() async {
    if (state.isLoading ||
        _reviewRequired ||
        ref.read(cartPersistenceProvider).isLoading) {
      return null;
    }
    final customer = ref.read(customerHandlerProvider).value;
    final address = ref.read(checkoutAddressProvider);
    final items = List.of(ref.read(selectedCartItemsProvider));
    if (customer == null || address?.isComplete != true || items.isEmpty) {
      state = AsyncError(
        const CustomerAuthException('로그인 정보, 배송지와 상품을 확인해 주세요.'),
        StackTrace.current,
      );
      return null;
    }
    state = const AsyncLoading();
    try {
      final order = await ref
          .read(customerOrderServiceProvider)
          .pay(customer.customerId, address!.address, items);
      if (!ref.mounted ||
          ref.read(customerHandlerProvider).value?.customerId !=
              customer.customerId) {
        return null;
      }
      final purchasedIds = items.map((item) => item.product.id).toSet();
      ref
          .read(cartHandlerProvider.notifier)
          .replaceFromServer(
            ref
                .read(cartHandlerProvider)
                .where((item) => !purchasedIds.contains(item.product.id))
                .toList(),
          );
      ref.invalidate(customerOrdersProvider);
      ref.invalidate(deliveryOrdersProvider);
      ref.invalidate(deliveryRecordsProvider);
      ref.invalidate(productHandlerProvider);
      state = AsyncData(order);
      return order;
    } catch (error, stack) {
      if (!ref.mounted ||
          ref.read(customerHandlerProvider).value?.customerId !=
              customer.customerId) {
        return null;
      }
      _reviewRequired = error is OrderResultUncertain;
      state = AsyncError(error, stack);
      return null;
    }
  }
}

final customerPaymentProvider =
    AsyncNotifierProvider<CustomerPaymentHandler, CustomerOrder?>(
      CustomerPaymentHandler.new,
    );
