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
import 'checkout_stock_handler.dart';
import 'point_handler.dart';
import 'checkout_flow_handler.dart';
import 'checkout_points_handler.dart';

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
    final points = ref.read(checkoutPointSummaryProvider);
    if (customer == null || address?.isComplete != true || items.isEmpty) {
      state = AsyncError(
        const CustomerAuthException('로그인 정보, 배송지와 상품을 확인해 주세요.'),
        StackTrace.current,
      );
      return null;
    }
    state = const AsyncLoading();
    try {
      if (!points.canContinue) {
        throw const CustomerAuthException('포인트 잔액을 확인한 뒤 다시 결제해 주세요.');
      }
      // 최종 결제 직전에 재고를 다시 조회한다. 마지막 동시 구매 경쟁은 서버의 재고 잠금으로 검증한다.
      final signature = items
          .map((item) => '${item.key}:${item.quantity}')
          .join('|');
      await ref.read(productHandlerProvider.notifier).refreshProducts();
      if (!ref.mounted ||
          ref.read(customerHandlerProvider).value?.customerId !=
              customer.customerId) {
        return null;
      }
      if (ref
              .read(selectedCartItemsProvider)
              .map((item) => '${item.key}:${item.quantity}')
              .join('|') !=
          signature) {
        throw const CustomerAuthException('주문 상품이 변경되었습니다. 수량을 다시 확인해 주세요.');
      }
      final stock = ref.read(checkoutStockProvider);
      final currentPoints = ref.read(checkoutPointSummaryProvider);
      if (!currentPoints.canContinue || currentPoints.used != points.used) {
        throw const CustomerAuthException(
          '사용 포인트가 변경되었습니다. 결제 금액을 다시 확인해 주세요.',
        );
      }
      if (!stock.canPurchase) {
        throw CustomerAuthException(
          stock.error ??
              (stock.issues.isEmpty
                  ? '최신 재고를 확인한 뒤 다시 결제해 주세요.'
                  : '재고 부족 또는 판매 불가 상품이 있습니다. 주문 수량을 확인해 주세요.'),
        );
      }
      final order = await ref
          .read(customerOrderServiceProvider)
          .pay(
            customer.customerId,
            address!.address,
            items,
            recipient: address.recipient,
            phone: address.phone,
            deliveryRequest: ref.read(checkoutFlowProvider).deliveryRequestText,
            pointsToUse: points.used,
          );
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
      if (order.pointsBalance != null) {
        ref
            .read(customerHandlerProvider.notifier)
            .updatePointsBalance(order.pointsBalance!);
      }
      ref.invalidate(customerPointsProvider);
      state = AsyncData(order);
      return order;
    } catch (error, stack) {
      if (!ref.mounted ||
          ref.read(customerHandlerProvider).value?.customerId !=
              customer.customerId) {
        return null;
      }
      _reviewRequired = error is OrderResultUncertain;
      if (!_reviewRequired && points.used > 0) {
        ref.invalidate(customerPointsProvider);
      }
      if (!_reviewRequired) ref.invalidate(productHandlerProvider);
      state = AsyncError(error, stack);
      return null;
    }
  }
}

final customerPaymentProvider =
    AsyncNotifierProvider<CustomerPaymentHandler, CustomerOrder?>(
      CustomerPaymentHandler.new,
    );

// 변경 내용(2026-10-30): 재고 재조회 실패·부족·수량 변경 시 결제 요청을 전송하지 않는다.
