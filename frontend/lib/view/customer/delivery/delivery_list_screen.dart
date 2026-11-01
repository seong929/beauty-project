// 기능: 고객 배송 현황 목록과 상태별 필터.
// 표시 계층: ref.watch로 상태를 구독하고 사용자 동작은 Notifier·서비스에 전달한다.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beauty_project/vm/customer/state/customer_screen_handler.dart';
import 'package:beauty_project/model/customer/order.dart';
import 'package:beauty_project/vm/customer/delivery_handler.dart';
import 'package:beauty_project/vm/customer/order_handler.dart';
import '../login/customer_auth_widgets.dart';
import '../order/order_history_widgets.dart';
import '../product/product_list.dart';
import '../product/product_widgets.dart';
import 'tracking_screen.dart';

class CustomerDeliveryListScreen extends ConsumerStatefulWidget {
  const CustomerDeliveryListScreen({super.key});

  @override
  ConsumerState<CustomerDeliveryListScreen> createState() =>
      _CustomerDeliveryListScreenState();
}

class _CustomerDeliveryListScreenState
    extends ConsumerState<CustomerDeliveryListScreen> {
  late final _filterProvider = deliveryListFilterProvider(this);
  String get _filter => ref.read(_filterProvider).value;

  /// Function: 관련 Provider를 무효화해 최신 서버 상태를 다시 조회한다.
  void _refresh() {
    ref.invalidate(deliveryRecordsProvider(null));
    ref.invalidate(customerOrdersProvider);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(_filterProvider);
    final records = ref.watch(deliveryRecordsProvider(null));
    final orders = ref.watch(customerOrdersProvider);
    return Scaffold(
      key: const Key('customer-delivery-list'),
      appBar: AppBar(
        title: const Text('배송 현황'),
        actions: [
          IconButton(
            onPressed: _refresh,
            tooltip: '다시 조회',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      bottomNavigationBar: ProductNavigation(
        selectedIndex: 3,
        onSearch: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CustomerProductListScreen()),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
                child: Row(
                  children: [
                    for (final label in ['전체', '배송 준비', '배송 중', '수령 완료'])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          key: Key('delivery-filter-$label'),
                          label: Text(label),
                          selected: _filter == label,
                          onSelected: (_) =>
                              ref.read(_filterProvider.notifier).select(label),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: records.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Center(
                    child: OrderLoadError(error: error, onRetry: _refresh),
                  ),
                  data: (items) {
                    final visible = items
                        .where(
                          (delivery) =>
                              _filter == '전체' ||
                              delivery.statusLabel == _filter,
                        )
                        .toList();
                    if (visible.isEmpty) {
                      return const Center(child: Text('해당 배송 내역이 없습니다.'));
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      itemCount: visible.length,
                      itemBuilder: (_, index) {
                        final delivery = visible[index];
                        final order = orders.value
                            ?.where((order) => order.id == delivery.orderId)
                            .firstOrNull;
                        final products =
                            order?.displayItems ?? <CustomerOrderLine>[];
                        final matched = products
                            .where((item) => item.deliveryId == delivery.id)
                            .firstOrNull;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 14),
                          color: const Color(0xFFF6F7F8),
                          child: InkWell(
                            key: Key(
                              'delivery-${delivery.id ?? delivery.orderId}',
                            ),
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => CustomerDeliveryTrackingScreen(
                                  orderId: delivery.orderId,
                                  initialOrder: order,
                                  selectedDeliveryId: delivery.id,
                                ),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          delivery.statusLabel,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: SodamStyle.green,
                                          ),
                                        ),
                                      ),
                                      const Text(
                                        '배송 확인',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                      const Icon(Icons.chevron_right, size: 18),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    delivery.orderId,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: SodamStyle.muted,
                                    ),
                                  ),
                                  if (matched != null ||
                                      products.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    const Text(
                                      '주문 상품',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: SodamStyle.muted,
                                      ),
                                    ),
                                    OrderProductInformation(
                                      item: matched ?? products.first,
                                    ),
                                    if (matched == null && products.length > 1)
                                      Text(
                                        '외 ${products.length - 1}개 상품',
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                  ],
                                  if (delivery.carrierName?.isNotEmpty == true)
                                    Text(
                                      delivery.carrierName!,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  Text(
                                    delivery.address,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: SodamStyle.muted,
                                      height: 1.7,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
