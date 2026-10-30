// Admin-only presentation. Shared STAFF/CUSTOMER views and business providers stay unchanged.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../model/admin/purchase_order.dart';
import '../../../vm/admin/purchase_order_notifier.dart';
import '../../../vm/admin/purchase_order_state.dart';
import 'list_controls.dart';
import '../../operations/operations_widgets.dart';

class OperationsPurchaseOrderPage extends ConsumerStatefulWidget {
  const OperationsPurchaseOrderPage({super.key});

  @override
  ConsumerState<OperationsPurchaseOrderPage> createState() =>
      _OperationsPurchaseOrderPageState();
}

class _OperationsPurchaseOrderPageState
    extends ConsumerState<OperationsPurchaseOrderPage> {
  ManagementListMode _mode = ManagementListMode.grouped;
  String _status = 'ALL';
  bool _showDetail = false;
  static const _statuses = {
    'ALL': '전체 상태',
    'REQUESTED': '요청',
    'ORDERED': '발주 완료',
    'PARTIALLY_RECEIVED': '부분 입고',
    'RECEIVED': '입고 완료',
    'CANCELLED': '취소',
  };

  bool _matches(PurchaseOrder order) =>
      _status == 'ALL' || order.purchaseStatus == _status;

  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      if (!mounted) return;

      ref.read(purchaseOrderProvider.notifier).getPurchaseOrderList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final orderState = ref.watch(purchaseOrderProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('발주 관리'),
        actions: [
          IconButton(
            tooltip: '새로고침',
            onPressed: orderState.isLoading
                ? null
                : () {
                    ref
                        .read(purchaseOrderProvider.notifier)
                        .getPurchaseOrderList();
                  },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: OperationsMasterDetail(
          hasSelection: _showDetail && orderState.selectedPurchaseOrder != null,
          onBack: () => setState(() => _showDetail = false),
          list: Card(
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('발주 목록 · 연결된 품의와 입고 상태를 확인하세요.'),
                ),
                OperationsListControls(
                  mode: _mode,
                  status: _status,
                  statuses: _statuses,
                  onModeChanged: (value) => setState(() {
                    _mode = value;
                    _showDetail = false;
                  }),
                  onStatusChanged: (value) => setState(() {
                    _status = value;
                    _showDetail = false;
                  }),
                ),
                Expanded(child: _buildPurchaseOrderList(orderState)),
              ],
            ),
          ),
          detail: Card(
            child: _buildPurchaseOrderDetail(orderState.selectedPurchaseOrder),
          ),
        ),
      ),
    );
  }

  Widget _buildPurchaseOrderList(PurchaseOrderState orderState) {
    if (orderState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (orderState.errorMessage != null && orderState.purchaseOrders.isEmpty) {
      return Center(child: Text(orderState.errorMessage!));
    }

    if (orderState.purchaseOrders.isEmpty) {
      return const Center(child: Text('등록된 발주가 없습니다.'));
    }

    final visible = orderState.purchaseOrders.where(_matches).toList();
    if (visible.isEmpty) return const Center(child: Text('선택한 상태의 발주가 없습니다.'));
    if (_mode == ManagementListMode.individual) {
      return ListView.builder(
        itemCount: visible.length,
        itemBuilder: (context, index) =>
            _orderTile(visible[index], individual: true),
      );
    }
    final groups = <String, List<PurchaseOrder>>{};
    for (final order in visible) {
      final key =
          '${order.manufacturerId}:${order.categoryId}:${order.cosmeticNameSeq ?? order.cosmeticId}';
      groups.putIfAbsent(key, () => []).add(order);
    }
    final grouped = groups.values.toList();
    return ListView.builder(
      itemCount: grouped.length,
      itemBuilder: (context, index) {
        final orders = grouped[index];
        return ExpansionTile(
          title: Text(orders.first.cosmeticName),
          subtitle: Text(orders.first.manufacturerName),
          children: [for (final order in orders) _orderTile(order)],
        );
      },
    );
  }

  Widget _orderTile(PurchaseOrder order, {bool individual = false}) => ListTile(
    key: ValueKey(order.purchaseOrderId),
    selected:
        ref
            .watch(purchaseOrderProvider)
            .selectedPurchaseOrder
            ?.purchaseOrderId ==
        order.purchaseOrderId,
    title: Text(
      individual
          ? '${order.cosmeticName} · ${order.volumeText ?? order.cosmeticId}'
          : order.volumeText ?? order.cosmeticId,
    ),
    subtitle: Text('품의: ${order.approvalId}\n발주: ${order.purchaseOrderId}'),
    isThreeLine: true,
    trailing: Text(_statuses[order.purchaseStatus] ?? order.purchaseStatus),
    onTap: () {
      ref.read(purchaseOrderProvider.notifier).selectPurchaseOrder(order);
      setState(() => _showDetail = true);
    },
  );

  // 발주 상세 영역
  Widget _buildPurchaseOrderDetail(PurchaseOrder? order) {
    if (order == null || !_matches(order)) {
      return const Center(child: Text('발주 내역을 선택해 주세요.'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('발주 상세 정보', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 24),

          _detailRow('발주 ID', order.purchaseOrderId),
          _detailRow('품의 ID', order.approvalId),
          _detailRow('발주 차수', '${order.purchaseOrderSeq}차'),
          _detailRow('상품명', order.cosmeticName),
          _detailRow('옵션', order.volumeText ?? '-'),
          _detailRow('상품 ID', order.cosmeticId),
          _detailRow('제조사', order.manufacturerName),
          _detailRow('제조사 ID', order.manufacturerId),
          _detailRow(
            '발주일',
            '${order.orderedOn.year}-'
                '${order.orderedOn.month.toString().padLeft(2, '0')}-'
                '${order.orderedOn.day.toString().padLeft(2, '0')}',
          ),
          _detailRow('발주 수량', '${order.orderQuantity}개'),
          _detailRow('공급 단가', '${order.unitSupplyPrice.toStringAsFixed(2)}원'),
          _detailRow(
            '총 발주 금액',
            '${order.orderTotalAmount.toStringAsFixed(2)}원',
          ),
          _detailRow('발주 상태', order.purchaseStatus),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
