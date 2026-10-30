import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beauty_project/model/customer/order.dart';
import 'package:beauty_project/vm/customer/customer_handler.dart';
import 'package:beauty_project/vm/customer/delivery_handler.dart';
import 'package:beauty_project/vm/customer/order_handler.dart';
import 'package:beauty_project/vm/customer/return_handler.dart';
import '../delivery/delivery_address_screen.dart';
import '../delivery/tracking_screen.dart';
import '../login/customer_auth_widgets.dart';
import '../product/product_list.dart';
import '../product/product_widgets.dart';
import '../review/product_reviews_section.dart';
import '../return/return_request_screen.dart';
import '../return/return_status_screen.dart';
import 'order_history_widgets.dart';
import 'order_summary.dart';
import 'order_cancel_button.dart';

class CustomerOrderDetailScreen extends ConsumerWidget {
  const CustomerOrderDetailScreen({super.key, required this.order, this.item});
  final CustomerOrder order;
  final CustomerOrderLine? item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionId = ref.watch(customerHandlerProvider).value?.customerId;
    if (sessionId != order.customerId) {
      return Scaffold(
        appBar: AppBar(title: const Text('구매 상세')),
        body: const Center(child: Text('로그인한 고객의 구매 내역을 확인해 주세요.')),
      );
    }
    final response = ref.watch(customerOrdersProvider);
    final current =
        response.value?.where((entry) => entry.id == order.id).firstOrNull ??
        order;
    final selected =
        current.displayItems
            .where((entry) => entry.id == item?.id)
            .firstOrNull ??
        (item == null
            ? current.displayItems.firstOrNull
            : current.displayItems
                  .where(
                    (entry) =>
                        entry.productId == item!.productId &&
                        entry.saleOption == item!.saleOption &&
                        entry.unitPrice == item!.unitPrice &&
                        entry.deliveryId == item!.deliveryId,
                  )
                  .firstOrNull);
    final purchaseItems = selected == null
        ? <CustomerOrderLine>[]
        : current.items
              .where(
                (entry) =>
                    entry.productId == selected.productId &&
                    entry.saleOption == selected.saleOption &&
                    entry.unitPrice == selected.unitPrice &&
                    entry.deliveryId == selected.deliveryId,
              )
              .toList();
    final purchaseIds = purchaseItems.map((entry) => entry.id).toList();
    final shipments = ref.watch(deliveryRecordsProvider(current.id));
    final canCancel =
        current.status == 'PAID' &&
        response.hasValue &&
        !response.isLoading &&
        !response.hasError &&
        shipments.hasValue &&
        !shipments.isLoading &&
        !shipments.hasError &&
        !shipments.value!.any((entry) => entry.id != null) &&
        current.items.every((entry) => entry.deliveryId == null);
    final returns = ref.watch(customerReturnsProvider(null));
    final eligible =
        selected != null &&
        const {'SHIPPED', 'DELIVERED', 'RETURNED'}.contains(current.status);
    final quantitiesReady =
        returns.hasValue &&
        !returns.isLoading &&
        !returns.hasError &&
        !response.isLoading &&
        !response.hasError;
    final available = purchaseItems.fold<int>(
      0,
      (sum, entry) =>
          sum +
          remainingReturnQuantity(item: entry, requests: returns.value ?? []),
    );
    final returnableItems = purchaseItems
        .where(
          (entry) =>
              remainingReturnQuantity(
                item: entry,
                requests: returns.value ?? [],
              ) >
              0,
        )
        .toList();
    final canReturn = eligible && quantitiesReady && available > 0;
    final buttonLabel = !eligible
        ? '배송 후 반품 신청 가능'
        : returns.isLoading || response.isLoading
        ? '반품 가능 수량 확인 중'
        : !quantitiesReady
        ? '반품 내역 확인 필요'
        : available == 0
        ? '반품 가능 수량 없음'
        : '반품 신청';
    final times =
        shipments.value
            ?.map((entry) => entry.updatedAt)
            .whereType<DateTime>()
            .toList() ??
        <DateTime>[];
    if (current.orderedAt != null) times.add(current.orderedAt!);
    times.sort();
    final changedAt = times.isEmpty ? null : times.last;
    return Scaffold(
      key: const Key('customer-order-detail'),
      appBar: AppBar(
        title: const Text('구매 상세'),
        actions: [
          IconButton(
            tooltip: '구매 상세 새로고침',
            onPressed: () {
              ref.invalidate(customerOrdersProvider);
              ref.invalidate(customerReturnsProvider(null));
            },
            icon: const Icon(Icons.refresh),
          ),
          TextButton(
            onPressed: () => showCustomerPreviewCart(context),
            child: const Text('장바구니'),
          ),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (eligible && quantitiesReady)
            Text(
              '반품 가능 수량 $available개',
              key: const Key('order-detail-return-quantity'),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('order-detail-return'),
                onPressed: canReturn
                    ? () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CustomerReturnRequestScreen(
                            order: current,
                            item: returnableItems.first,
                          ),
                        ),
                      )
                    : null,
                child: Text(buttonLabel),
              ),
            ),
          ),
          ProductNavigation(
            selectedIndex: 3,
            onSearch: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const CustomerProductListScreen(),
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 26),
            children: [
              if (response.isLoading) const LinearProgressIndicator(),
              if (response.hasError)
                OrderLoadError(
                  error: response.error!,
                  onRetry: () => ref.invalidate(customerOrdersProvider),
                ),
              Row(
                children: [
                  OrderStatusBadge(status: current.status),
                  const Spacer(),
                  Text(
                    orderDateText(current.orderedAt),
                    style: const TextStyle(
                      fontSize: 11,
                      color: SodamStyle.muted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (selected != null)
                OrderProductInformation(item: selected)
              else
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('구매 상품 정보가 없습니다.'),
                ),
              if (selected != null)
                OrderReviewAction(
                  productId: selected.productId,
                  productName: selected.name,
                ),
              const Divider(height: 28),
              OrderInformationRow(
                '구매번호',
                purchaseIds.isEmpty ? '확인 중' : purchaseIds.join('\n'),
              ),
              OrderInformationRow('주문번호', current.id),
              if (selected != null) ...[
                OrderInformationRow('구매 당시 옵션', selected.saleLabel),
                OrderInformationRow('구매가격', productPrice(selected.total)),
              ],
              OrderInformationRow(
                '총 주문 금액',
                productPrice(current.total),
                bold: true,
              ),
              const OrderInformationRow('배송비', '무료'),
              if (current.usedPoints > 0) ...[
                OrderInformationRow('사용 포인트', '${current.usedPoints}P'),
                OrderInformationRow(
                  '총 결제 금액',
                  productPrice(current.paymentAmount),
                  bold: true,
                ),
              ],
              OrderInformationRow('배송 주소', current.address),
              if (changedAt != null)
                OrderInformationRow(
                  '최근 처리 일시',
                  '${orderDateText(changedAt)} ${changedAt.hour.toString().padLeft(2, '0')}:${changedAt.minute.toString().padLeft(2, '0')}',
                ),
              if (shipments.hasError)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    '배송 정보를 불러오지 못했습니다. 배송 현황에서 다시 조회해 주세요.',
                    style: TextStyle(fontSize: 11, color: SodamStyle.muted),
                  ),
                ),
              const SizedBox(height: 16),
              OutlinedButton(
                key: const Key('order-detail-delivery'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CustomerDeliveryTrackingScreen(
                      orderId: current.id,
                      initialOrder: current,
                      selectedDeliveryId: selected?.deliveryId,
                    ),
                  ),
                ),
                child: const Text('배송 현황 보기'),
              ),
              OutlinedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const CustomerDeliveryAddressScreen(),
                  ),
                ),
                child: const Text('배송 주소 변경'),
              ),
              const SizedBox(height: 8),
              OrderCancelButton(order: current, canCancel: canCancel),
              if (returns.hasError)
                TextButton(
                  onPressed: () =>
                      ref.invalidate(customerReturnsProvider(null)),
                  child: const Text('반품 내역 조회 실패 · 다시 조회'),
                ),
              for (final request in returns.value ?? [])
                if (purchaseIds.contains(request.itemId))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '반품 ${request.statusLabel}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    subtitle: Text(
                      request.id,
                      style: const TextStyle(fontSize: 10),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CustomerReturnStatusScreen(
                          order: current,
                          item: current.items.firstWhere(
                            (entry) => entry.id == request.itemId,
                          ),
                          initial: request,
                        ),
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
