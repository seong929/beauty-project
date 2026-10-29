import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beauty_project/model/customer/delivery_order.dart';
import 'package:beauty_project/model/customer/delivery.dart';
import 'package:beauty_project/service/customer/customer_auth_service.dart';
import 'package:beauty_project/service/customer/customer_delivery_service.dart';
import 'customer_handler.dart';
import 'customer_providers.dart';
import 'order_handler.dart';

final customerDeliveryServiceProvider = Provider<CustomerDeliveryService>(
  (ref) => CustomerDeliveryService(
    client: ref.watch(customerHttpClientProvider),
    baseUrl: ref.watch(customerApiBaseUrlProvider),
  ),
);

final deliveryOrdersProvider = FutureProvider<List<DeliveryOrder>>((ref) {
  final id = ref.watch(customerHandlerProvider).value?.customerId;
  if (id == null || id.isEmpty) {
    throw const CustomerAuthException('로그인 후 주문을 확인해 주세요.');
  }
  return ref.watch(customerDeliveryServiceProvider).fetch(id);
});

final deliveryRecordsProvider = FutureProvider.autoDispose
    .family<List<CustomerDelivery>, String?>((ref, orderId) {
      final id = ref.watch(
        customerHandlerProvider.select((session) => session.value?.customerId),
      );
      if (id == null || id.isEmpty) {
        throw const CustomerAuthException('로그인 후 배송 현황을 확인해 주세요.');
      }
      return ref
          .watch(customerDeliveryServiceProvider)
          .fetchShipments(id, orderId: orderId);
    });

final deliveryAddressHandlerProvider = Provider<DeliveryAddressHandler>(
  (ref) => DeliveryAddressHandler(ref),
);

class DeliveryAddressHandler {
  const DeliveryAddressHandler(this.ref);
  final Ref ref;

  Future<void> save(String customerId, String orderId, String address) async {
    if (ref.read(customerHandlerProvider).value?.customerId != customerId) {
      throw const CustomerAuthException('다시 로그인한 뒤 배송지를 변경해 주세요.');
    }
    await ref
        .read(customerDeliveryServiceProvider)
        .updateAddress(customerId, orderId, address);
    if (!ref.mounted ||
        ref.read(customerHandlerProvider).value?.customerId != customerId) {
      return;
    }
    ref.invalidate(deliveryOrdersProvider);
    ref.invalidate(deliveryRecordsProvider);
    ref.invalidate(customerOrdersProvider);
  }
}
