import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beauty_project/model/customer/order.dart';
import 'package:beauty_project/vm/customer/customer_handler.dart';
import 'package:beauty_project/vm/customer/delivery_handler.dart';
import 'package:beauty_project/vm/customer/order_handler.dart';
import 'package:beauty_project/vm/customer/review_handler.dart';
import '../login/customer_auth_widgets.dart';
import '../order/order_history_widgets.dart';
import '../order/order_summary.dart';
import '../product/product_list.dart';
import '../product/product_widgets.dart';

String deliveryDateText(DateTime? date) {
  if (date == null) return '시간 정보 없음';
  final local = date.toLocal();
  return '${orderDateText(local)} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

class CustomerDeliveryTrackingScreen extends ConsumerStatefulWidget {
  const CustomerDeliveryTrackingScreen({
    super.key,
    required this.orderId,
    this.initialOrder,
    this.selectedDeliveryId,
  });
  final String orderId;
  final CustomerOrder? initialOrder;
  final String? selectedDeliveryId;

  @override
  ConsumerState<CustomerDeliveryTrackingScreen> createState() =>
      _CustomerDeliveryTrackingScreenState();
}

class _CustomerDeliveryTrackingScreenState
    extends ConsumerState<CustomerDeliveryTrackingScreen> {
  late String? _selectedId = widget.selectedDeliveryId;

  void _refresh() {
    ref.invalidate(deliveryRecordsProvider(widget.orderId));
    ref.invalidate(customerOrdersProvider);
    ref.invalidate(eligibleReviewProductsProvider);
  }

  Widget _milestone(
    String title,
    String description,
    bool done, {
    bool last = false,
  }) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 32,
          child: Column(
            children: [
              Container(
                width: 13,
                height: 13,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done ? SodamStyle.green : const Color(0xFFEBEDF0),
                  border: Border.all(color: const Color(0xFFD9F1F3), width: 3),
                ),
              ),
              if (!last)
                Expanded(
                  child: Container(width: 1, color: const Color(0xFFEBEDF0)),
                ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 0, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: done ? SodamStyle.ink : SodamStyle.muted,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  description,
                  style: const TextStyle(fontSize: 11, color: SodamStyle.muted),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final customerId = ref.watch(customerHandlerProvider).value?.customerId;
    final response = ref.watch(deliveryRecordsProvider(widget.orderId));
    final orders = ref.watch(customerOrdersProvider);
    final order =
        orders.value
            ?.where((entry) => entry.id == widget.orderId)
            .firstOrNull ??
        (widget.initialOrder?.customerId == customerId
            ? widget.initialOrder
            : null);
    return Scaffold(
      key: const Key('customer-delivery-tracking'),
      appBar: AppBar(
        title: const Text('배송 현황 · 수령 확인'),
        actions: [
          TextButton(
            onPressed: () => showCustomerPreviewCart(context),
            child: const Text('장바구니'),
          ),
        ],
      ),
      bottomNavigationBar: ProductNavigation(
        selectedIndex: 3,
        onSearch: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CustomerProductListScreen()),
        ),
      ),
      body: response.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: OrderLoadError(error: error, onRetry: _refresh),
        ),
        data: (records) {
          if (records.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('등록된 배송 정보가 없습니다.'),
                  TextButton(onPressed: _refresh, child: const Text('다시 조회')),
                ],
              ),
            );
          }
          final delivery =
              records.where((entry) => entry.id == _selectedId).firstOrNull ??
              records.first;
          final matching =
              order?.displayItems
                  .where((item) => item.deliveryId == delivery.id)
                  .toList() ??
              [];
          final products = matching.isNotEmpty
              ? matching
              : order?.displayItems ?? <CustomerOrderLine>[];
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
                children: [
                  if (records.length > 1)
                    Wrap(
                      spacing: 8,
                      children: [
                        for (var i = 0; i < records.length; i++)
                          ChoiceChip(
                            label: Text('배송 ${i + 1}'),
                            selected: identical(records[i], delivery),
                            onSelected: (_) =>
                                setState(() => _selectedId = records[i].id),
                          ),
                      ],
                    ),
                  Text(
                    '주문 ${widget.orderId}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: SodamStyle.muted,
                    ),
                  ),
                  for (final product in products)
                    OrderProductInformation(item: product),
                  const Divider(height: 26),
                  const Text(
                    '배송 현황',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    delivery.statusLabel,
                    key: const Key('delivery-current-status'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: SodamStyle.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 28),
                  _milestone(
                    '주문 접수',
                    deliveryDateText(delivery.orderedAt ?? order?.orderedAt),
                    true,
                  ),
                  _milestone(
                    '배송 중',
                    delivery.departed
                        ? deliveryDateText(delivery.shippedAt)
                        : '출발 정보가 아직 등록되지 않았습니다.',
                    delivery.departed,
                  ),
                  _milestone(
                    '수령 완료',
                    delivery.received
                        ? deliveryDateText(delivery.arrivedAt)
                        : '도착 정보가 아직 등록되지 않았습니다.',
                    delivery.received,
                    last: true,
                  ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEFAFB),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      '등록된 최신 배송 상태를 표시합니다. 배송사의 실시간 위치와 운송장 이동 기록은 제공되지 않습니다.',
                      style: TextStyle(
                        fontSize: 12,
                        color: SodamStyle.muted,
                        height: 1.8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  OrderInformationRow('배송 주소', delivery.address),
                  if (delivery.id != null)
                    OrderInformationRow('배송번호', delivery.id!),
                  OrderInformationRow(
                    '배송업체',
                    delivery.carrierName?.isNotEmpty == true
                        ? delivery.carrierName!
                        : '배정 전',
                  ),
                  if (delivery.carrierPhone?.isNotEmpty == true)
                    OrderInformationRow('배송업체 연락처', delivery.carrierPhone!),
                  OrderInformationRow(
                    '최근 처리 일시',
                    deliveryDateText(delivery.updatedAt),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    key: const Key('delivery-refresh'),
                    onPressed: _refresh,
                    child: const Text('배송 현황 새로고침'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
