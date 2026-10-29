import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:beauty_project/model/customer/shipping_address.dart';
import 'customer_handler.dart';

// 배송지 변경은 결제 화면의 메모리 상태에만 반영한다.
class CheckoutAddressHandler extends Notifier<ShippingAddress?> {
  @override
  ShippingAddress? build() {
    final customer = ref.watch(customerHandlerProvider).value;
    return customer == null
        ? null
        : ShippingAddress(
            recipient: customer.name,
            phone: customer.phone,
            address: customer.address,
          );
  }

  void update(ShippingAddress address) {
    if (address.isComplete) state = address;
  }
}

final checkoutAddressProvider =
    NotifierProvider<CheckoutAddressHandler, ShippingAddress?>(
      CheckoutAddressHandler.new,
    );
