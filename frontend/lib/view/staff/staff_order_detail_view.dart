import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../model/staff/staff_order.dart';
import '../../vm/staff/staff_order_vm.dart';

/// 주문 상세 정보와 주문 상품 API 호출 시점을 분리한 계층형 상세 화면.
class StaffOrderDetailView extends ConsumerStatefulWidget {
  const StaffOrderDetailView({super.key, required this.orderId});
  final String orderId;

  @override
  ConsumerState<StaffOrderDetailView> createState() => _StaffOrderDetailViewState();
}

class _StaffOrderDetailViewState extends ConsumerState<StaffOrderDetailView> {
  bool _showItems = false;

  @override
  Widget build(BuildContext context) {
    final asyncDetail = ref.watch(staffOrderDetailProvider(widget.orderId));
    final tablet = MediaQuery.sizeOf(context).width >= 680;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('주문 상세'),
        actions: [
          IconButton(
            tooltip: '주문 상세 새로고침',
            onPressed: () {
              ref.invalidate(staffOrderDetailProvider(widget.orderId));
              if (_showItems) ref.invalidate(staffOrderItemsProvider(widget.orderId));
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: asyncDetail.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('주문 상세 조회 실패: $error', textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => ref.invalidate(staffOrderDetailProvider(widget.orderId)),
                  child: const Text('다시 조회'),
                ),
              ]),
            ),
            data: (order) => ListView(
              padding: EdgeInsets.all(tablet ? 28 : 14),
              children: [
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(tablet ? 24 : 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(order.orderId, style: theme.textTheme.headlineSmall),
                        const SizedBox(height: 10),
                        Chip(label: Text(order.status.label)),
                        const Divider(height: 30),
                        Wrap(
                          spacing: 28,
                          runSpacing: 16,
                          children: [
                            _OrderDetailField('고객 ID', order.customerId),
                            _OrderDetailField('주문 순번', '${order.orderSeq}'),
                            _OrderDetailField('주문 일시', formatOrderDate(order.orderedAt)),
                          ],
                        ),
                        const SizedBox(height: 18),
                        _OrderDetailField('배송지', order.shippingAddress),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.shopping_bag_outlined),
                        title: const Text('주문 상품 목록'),
                        subtitle: const Text('펼칠 때에만 주문 상품 API를 호출합니다.'),
                        trailing: Icon(_showItems
                            ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down),
                        onTap: () => setState(() => _showItems = !_showItems),
                      ),
                      if (_showItems) ...[
                        const Divider(height: 1),
                        _OrderItemsSection(orderId: widget.orderId, tablet: tablet),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OrderDetailField extends StatelessWidget {
  const _OrderDetailField(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant)),
      const SizedBox(height: 5),
      SelectableText(value, style: theme.textTheme.bodyLarge),
    ]);
  }
}

class _OrderItemsSection extends ConsumerWidget {
  const _OrderItemsSection({required this.orderId, required this.tablet});
  final String orderId;
  final bool tablet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncItems = ref.watch(staffOrderItemsProvider(orderId));
    return asyncItems.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(30),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          Text('구매 상품 조회 실패: $error'),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => ref.invalidate(staffOrderItemsProvider(orderId)),
            icon: const Icon(Icons.refresh),
            label: const Text('재시도'),
          ),
        ]),
      ),
      data: (items) => items.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('주문에 포함된 구매 상품이 없습니다.')),
            )
          : Column(children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('구매 상품 ${items.length}건'),
                ),
              ),
              for (final item in items) ...[
                const Divider(height: 1),
                _OrderItemRow(item: item, tablet: tablet),
              ],
            ]),
    );
  }
}

class _OrderItemRow extends StatelessWidget {
  const _OrderItemRow({required this.item, required this.tablet});
  final StaffOrderItem item;
  final bool tablet;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final expiration = item.expiresOn == null
        ? '미설정'
        : formatOrderDateOnly(item.expiresOn!);
    return Padding(
      padding: EdgeInsets.all(tablet ? 20 : 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(item.cosmeticName, style: theme.textTheme.titleMedium),
        const SizedBox(height: 5),
        Text('옵션 ID: ${item.cosmeticId} · 상품 항목: ${item.orderItemId}',
            style: theme.textTheme.bodySmall),
        const SizedBox(height: 12),
        Wrap(spacing: 24, runSpacing: 12, children: [
          _OrderDetailField('구매 수량', '${item.quantity}개'),
          _OrderDetailField('구매 당시 단가', formatOrderMoney(item.unitPrice)),
          _OrderDetailField('판매 옵션', item.saleOption),
          _OrderDetailField('재고 ID', item.inventoryId),
          _OrderDetailField('유통기한', expiration),
          _OrderDetailField('사용 포인트', '${item.usedPoints}P'),
          _OrderDetailField('적립 포인트', '${item.earnedPoints}P'),
        ]),
      ]),
    );
  }
}
