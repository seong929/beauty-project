import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beauty_project/model/customer/delivery_order.dart';
import 'package:beauty_project/model/customer/shipping_address.dart';
import 'package:beauty_project/vm/customer/customer_handler.dart';
import 'package:beauty_project/vm/customer/delivery_handler.dart';
import 'shipping_address_sheet.dart';

class CustomerDeliveryAddressScreen extends ConsumerStatefulWidget {
  const CustomerDeliveryAddressScreen({super.key});

  @override
  ConsumerState<CustomerDeliveryAddressScreen> createState() =>
      _CustomerDeliveryAddressScreenState();
}

class _CustomerDeliveryAddressScreenState
    extends ConsumerState<CustomerDeliveryAddressScreen> {
  bool _busy = false;

  Future<void> _change(DeliveryOrder order) async {
    if (_busy) return;
    final customer = ref.read(customerHandlerProvider).value;
    if (customer == null) return;
    setState(() => _busy = true);
    try {
      final address = await showShippingAddressSheet(
        context,
        ShippingAddress(
          recipient: order.recipient.isEmpty ? customer.name : order.recipient,
          phone: order.phone.isEmpty ? customer.phone : order.phone,
          address: order.address,
          deliveryRequest: order.deliveryRequest,
        ),
        includeRequest: true,
      );
      if (address == null || !mounted) return;
      await ref
          .read(deliveryAddressHandlerProvider)
          .save(
            customer.customerId,
            order.orderId,
            address.address,
            recipient: address.recipient,
            phone: address.phone,
            deliveryRequest: address.deliveryRequest,
          );
      if (!mounted ||
          ref.read(customerHandlerProvider).value?.customerId !=
              customer.customerId) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('주문 배송지를 저장했습니다.')));
    } catch (error) {
      if (!mounted) return;
      ref.invalidate(deliveryOrdersProvider);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(deliveryOrdersProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('주문 배송 정보 변경'),
        actions: [
          IconButton(
            onPressed: _busy
                ? null
                : () => ref.invalidate(deliveryOrdersProvider),
            tooltip: '다시 조회',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: orders.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(error.toString()),
                TextButton(
                  onPressed: () => ref.invalidate(deliveryOrdersProvider),
                  child: const Text('다시 조회'),
                ),
              ],
            ),
          ),
        ),
        data: (items) => items.isEmpty
            ? const Center(child: Text('주문 내역이 없습니다.'))
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Text('출고 전 주문의 수령인·연락처·주소·배송 요청사항을 변경할 수 있습니다.'),
                  const SizedBox(height: 12),
                  for (final order in items)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              order.orderId,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(order.statusLabel),
                            if (order.recipient.isNotEmpty ||
                                order.phone.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Text('${order.recipient} ${order.phone}'),
                            ],
                            const SizedBox(height: 10),
                            Text(
                              order.address,
                              key: Key('order-address-${order.orderId}'),
                            ),
                            if (order.deliveryRequest.isNotEmpty)
                              Text(order.deliveryRequest),
                            const SizedBox(height: 10),
                            OutlinedButton(
                              key: Key('change-order-address-${order.orderId}'),
                              onPressed: !_busy && order.canChangeAddress
                                  ? () => _change(order)
                                  : null,
                              child: Text(
                                order.canChangeAddress ? '배송지 변경' : '배송지 변경 불가',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
