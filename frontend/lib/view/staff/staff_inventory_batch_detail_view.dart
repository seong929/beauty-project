import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../model/staff/staff_inventory_history.dart';
import '../../model/staff/staff_product_inventory.dart';
import '../../vm/staff/staff_inventory_vm.dart';
import 'staff_inventory_discard_view.dart';

/// product_inventory -> inbound_history / stock_outbounds 관계 조회 화면.
/// 개별 재고 선택 후 상세 API 1건만 호출하며,
/// 입고/출고 데이터는 각 섹션을 펼친 시점에 독립적으로 요청합니다.
class StaffInventoryBatchDetailView extends ConsumerStatefulWidget {
  const StaffInventoryBatchDetailView({super.key, required this.inventoryId});

  final String inventoryId;

  @override
  ConsumerState<StaffInventoryBatchDetailView> createState() =>
      _StaffInventoryBatchDetailViewState();
}

class _StaffInventoryBatchDetailViewState
    extends ConsumerState<StaffInventoryBatchDetailView> {
  bool _inboundExpanded = false;
  bool _outboundExpanded = false;
  int _outboundPage = 1;

  void _refresh() {
    ref.invalidate(inventoryBatchDetailProvider(widget.inventoryId));
    if (_inboundExpanded) {
      ref.invalidate(inventoryInboundHistoryProvider(widget.inventoryId));
    }
    if (_outboundExpanded) {
      ref.invalidate(inventoryOutboundHistoryProvider((widget.inventoryId, _outboundPage)));
    }
  }

  Future<void> _openDiscard(StaffInventoryBatchDetail detail) async {
    final batch = StaffProductInventory(
      inventoryId: detail.inventoryId,
      cosmeticId: detail.cosmeticId,
      stockQuantity: detail.stockQuantity,
      receivedOn: DateTime.parse(detail.receivedOn),
      expiresOn: detail.expiresOn == null ? null : DateTime.parse(detail.expiresOn!),
      inventoryStatus: InventoryStatus.values.byName(detail.inventoryStatus),
      saleOption: SaleOption.values.byName(detail.saleOption),
    );
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => StaffInventoryDiscardView(
          batch: batch,
          cosmeticName: detail.cosmeticName,
        ),
      ),
    );
    if (!mounted || changed != true) return;
    ref.invalidate(inventoryBatchDetailProvider(widget.inventoryId));
    ref.invalidate(inventoryInboundHistoryProvider(widget.inventoryId));
    ref.invalidate(inventoryOutboundHistoryProvider((widget.inventoryId, _outboundPage)));
    // 현재 상세 화면을 닫고 호출한 목록도 갱신합니다.
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(inventoryBatchDetailProvider(widget.inventoryId));
    final isTablet = MediaQuery.sizeOf(context).width >= 680;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('재고 상세 · 입출고 이력'),
        actions: [
          IconButton(
            tooltip: '상세 및 펼친 이력 새로고침',
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: result.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _HistoryError(
          message: '재고 상세를 조회하지 못했습니다.\n$error',
          onRetry: () => ref.invalidate(inventoryBatchDetailProvider(widget.inventoryId)),
        ),
        data: (detail) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: ListView(
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 30 : 14,
                vertical: isTablet ? 24 : 12,
              ),
              children: [
                Card(
                  elevation: 0,
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: EdgeInsets.all(isTablet ? 24 : 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          detail.cosmeticName,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: isTablet ? 28 : 14,
                          runSpacing: 14,
                          children: [
                            _HistoryField(label: '옵션 ID', value: detail.cosmeticId),
                            _HistoryField(label: '재고 ID', value: detail.inventoryId),
                            _HistoryField(label: '현재 재고', value: '${detail.stockQuantity}개'),
                            _HistoryField(label: '재고 상태', value: detail.inventoryStatus),
                            _HistoryField(label: '판매 옵션', value: detail.saleOption),
                            _HistoryField(label: '입고일', value: detail.receivedOn),
                            _HistoryField(label: '사용기한', value: detail.expiresOn ?? '미설정'),
                          ],
                        ),
                        if (detail.inventoryStatus == 'DISCARD' && detail.stockQuantity > 0) ...[
                          const SizedBox(height: 20),
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton.icon(
                              onPressed: () => _openDiscard(detail),
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('이 재고 폐기하기'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _HistorySection(
                  title: '입고 이력',
                  subtitle: '입고 번호와 발주 내역',
                  icon: Icons.move_to_inbox_outlined,
                  expanded: _inboundExpanded,
                  onToggle: () => setState(() => _inboundExpanded = !_inboundExpanded),
                  child: _inboundExpanded
                      ? _InboundHistoryContent(inventoryId: widget.inventoryId)
                      : null,
                ),
                const SizedBox(height: 14),
                _HistorySection(
                  title: '출고 이력',
                  subtitle: '출고 예약 및 확정 내역',
                  icon: Icons.local_shipping_outlined,
                  expanded: _outboundExpanded,
                  onToggle: () => setState(() => _outboundExpanded = !_outboundExpanded),
                  child: _outboundExpanded
                      ? _OutboundHistoryContent(
                          inventoryId: widget.inventoryId,
                          page: _outboundPage,
                          onPageChange: (page) => setState(() => _outboundPage = page),
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryField extends StatelessWidget {
  const _HistoryField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 130, maxWidth: 500),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          )),
          const SizedBox(height: 3),
          SelectableText(value, style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          )),
        ],
      ),
    );
  }
}

class _HistorySection extends StatelessWidget {
  const _HistorySection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.expanded,
    required this.onToggle,
    this.child,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool expanded;
  final VoidCallback onToggle;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Row(
                children: [
                  Icon(icon, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        )),
                        Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        )),
                      ],
                    ),
                  ),
                  Icon(expanded ? Icons.expand_less : Icons.expand_more),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: child,
            ),
          ],
        ],
      ),
    );
  }
}

class _InboundHistoryContent extends ConsumerWidget {
  const _InboundHistoryContent({required this.inventoryId});
  final String inventoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(inventoryInboundHistoryProvider(inventoryId)).when(
      loading: () => const Center(child: Padding(
        padding: EdgeInsets.all(18), child: CircularProgressIndicator(),
      )),
      error: (error, stack) => _HistoryError(
        message: '입고 이력 조회 실패: $error',
        onRetry: () => ref.invalidate(inventoryInboundHistoryProvider(inventoryId)),
      ),
      data: (items) => items.isEmpty
          ? const Text('입고 이력이 없습니다.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('입고 기록 ${items.length}건'),
                const SizedBox(height: 12),
                for (final item in items) ...[
                  Wrap(
                    spacing: 22,
                    runSpacing: 12,
                    children: [
                      _HistoryField(label: '입고 ID', value: item.inboundId),
                      _HistoryField(label: '발주 ID', value: item.purchaseOrderId),
                      _HistoryField(label: '발주별 입고 순번', value: '${item.inboundSeq}회차'),
                      _HistoryField(label: '입고 수량', value: '${item.inboundQuantity}개'),
                      _HistoryField(label: '입고 날짜', value: item.inboundOn),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
    );
  }
}

class _OutboundHistoryContent extends ConsumerWidget {
  const _OutboundHistoryContent({
    required this.inventoryId,
    required this.page,
    required this.onPageChange,
  });

  final String inventoryId;
  final int page;
  final ValueChanged<int> onPageChange;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (inventoryId, page);
    return ref.watch(inventoryOutboundHistoryProvider(key)).when(
      loading: () => const Center(child: Padding(
        padding: EdgeInsets.all(18), child: CircularProgressIndicator(),
      )),
      error: (error, stack) => _HistoryError(
        message: '출고 이력 조회 실패: $error',
        onRetry: () => ref.invalidate(inventoryOutboundHistoryProvider(key)),
      ),
      data: (data) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              Chip(label: Text('전체 ${data.total}건')),
              Chip(label: Text('출고 예약 ${data.reservedQuantity}개')),
              Chip(label: Text('출고 확정 ${data.confirmedQuantity}개')),
            ],
          ),
          const SizedBox(height: 10),
          if (data.outbounds.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('이 재고 배치의 출고 내역이 없습니다.'),
            ),
          for (final item in data.outbounds) ...[
            Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(item.isReserved
                            ? Icons.pending_actions_outlined
                            : Icons.local_shipping_outlined),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item.isReserved ? '출고 예약' : '출고 확정',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        Text('${item.outboundQuantity}개'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 20,
                      runSpacing: 12,
                      children: [
                        _HistoryField(label: '주문 ID', value: item.orderId),
                        _HistoryField(label: '주문상품 ID', value: item.orderItemId),
                        _HistoryField(label: '주문 상태', value: item.orderStatus),
                        _HistoryField(label: '배송 ID', value: item.deliveryId ?? '미확정'),
                        _HistoryField(label: '출고 확정일', value: item.outboundOn ?? '미확정'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
          ],
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 14,
            children: [
              OutlinedButton.icon(
                onPressed: page > 1 ? () => onPageChange(page - 1) : null,
                icon: const Icon(Icons.chevron_left),
                label: const Text('이전'),
              ),
              Text('${data.page} / ${data.totalPages} 페이지'),
              OutlinedButton.icon(
                onPressed: page < data.totalPages ? () => onPageChange(page + 1) : null,
                icon: const Icon(Icons.chevron_right),
                label: const Text('다음'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HistoryError extends StatelessWidget {
  const _HistoryError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(18),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('다시 시도'),
        ),
      ],
    ),
  );
}
