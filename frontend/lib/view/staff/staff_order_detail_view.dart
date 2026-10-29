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
                _OrderStatusEditor(order: order, tablet: tablet),
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

/// 결제·배송·환불 상태를 임의 수정하지 않고, 상품 준비 시작만 허용합니다.
/// 서버에서도 PAID -> PREPARING을 다시 검사하므로 UI 우회를 방지합니다.
class _OrderStatusEditor extends ConsumerWidget {
  const _OrderStatusEditor({required this.order, required this.tablet});

  final StaffOrder order;
  final bool tablet;

  Future<void> _startPreparing(BuildContext context, WidgetRef ref) async {
    if (order.status != StaffOrderStatus.PAID) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('상품 준비 시작 확인'),
        content: Text(
          '주문번호: ${order.orderId}\n'
          '결제 완료(PAID) → 상품 준비 중(PREPARING)\n\n'
          '실제 결제 완료가 확인된 주문만 준비를 시작하세요. '
          '이 작업은 주문 상태만 변경하며 재고 출고나 배송 처리는 수행하지 않습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('상품 준비 시작'),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;

    try {
      final updated = await ref.read(staffOrderStatusUpdateVmProvider.notifier)
          .updateStatus(
            orderId: order.orderId,
            newStatus: StaffOrderStatus.PREPARING,
          );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('주문 상태가 ${updated.status.label}(으)로 변경되었습니다.')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('상품 준비 시작 실패: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final busy = ref.watch(staffOrderStatusUpdateVmProvider) != null;
    final canPrepare = order.status == StaffOrderStatus.PAID;
    final message = switch (order.status) {
      StaffOrderStatus.PENDING =>
        '결제 전 주문입니다. 결제 결과는 결제 기능에서 확정해야 합니다.',
      StaffOrderStatus.PAID =>
        '결제 완료된 주문입니다. 직원이 실제 상품 준비를 시작할 수 있습니다.',
      StaffOrderStatus.PREPARING =>
        '준비 중인 주문입니다. 출고는 전용 출고 API에서 처리해야 합니다.',
      StaffOrderStatus.SHIPPED =>
        '출고된 주문입니다. 배송 완료 여부는 배송 이력을 통해 확인해야 합니다.',
      StaffOrderStatus.DELIVERED =>
        '배송 완료 주문입니다. 이 화면에서는 상태를 변경할 수 없습니다.',
      StaffOrderStatus.CANCELLED =>
        '취소된 주문입니다. 이 화면에서는 상태를 변경할 수 없습니다.',
      StaffOrderStatus.RETURNED =>
        '반품 완료 주문입니다. 이 화면에서는 상태를 변경할 수 없습니다.',
    };

    return Card(
      child: Padding(
        padding: EdgeInsets.all(tablet ? 24 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('주문 처리', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('현재 상태: ${order.status.label} (${order.status.name})'),
            const SizedBox(height: 12),
            Text(message, style: theme.textTheme.bodyMedium),
            if (canPrepare) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: busy ? null : () => _startPreparing(context, ref),
                icon: busy
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.inventory_2_outlined),
                label: Text(busy ? '처리 중...' : '상품 준비 시작'),
              ),
            ],
            const SizedBox(height: 10),
            Text(
              '결제·출고·배송 완료·취소·반품은 관련 데이터와 함께 처리해야 하므로 '
              '이 화면에서 임의로 주문 상태를 변경할 수 없습니다.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
