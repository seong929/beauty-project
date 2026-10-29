import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../model/admin/purchase_order.dart';
import '../../vm/admin/staff_purchase_order_notifier.dart';
import 'inbound_page.dart';

class StaffPurchaseOrderPage extends ConsumerStatefulWidget {
  const StaffPurchaseOrderPage({super.key});

  @override
  ConsumerState<StaffPurchaseOrderPage> createState() =>
      _StaffPurchaseOrderPageState();
}

class _StaffPurchaseOrderPageState
    extends ConsumerState<StaffPurchaseOrderPage> {
  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      if (!mounted) return;

      ref.read(staffPurchaseOrderProvider.notifier).getPurchaseOrderList();
    });
  }

  String _statusText(String status) {
    switch (status) {
      case 'ORDERED':
        return '발주 완료';
      case 'PARTIALLY_RECEIVED':
        return '부분 입고';
      case 'RECEIVED':
        return '입고 완료';
      default:
        return status;
    }
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  void _selectOrder(PurchaseOrder order) {
    ref.read(staffPurchaseOrderProvider.notifier).selectPurchaseOrder(order);

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const InboundPage()),
    );
  }

  Widget _buildOrderCard(PurchaseOrder order) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              order.cosmeticName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text('발주 ID: ${order.purchaseOrderId}'),
            const SizedBox(height: 6),
            Text('제조사: ${order.manufacturerName}'),
            const SizedBox(height: 6),
            Text('발주 수량: ${order.orderQuantity}개'),
            const SizedBox(height: 6),
            Text('발주일: ${_formatDate(order.orderedOn)}'),
            const SizedBox(height: 6),
            Text('발주 상태: ${_statusText(order.purchaseStatus)}'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: order.canInbound ? () => _selectOrder(order) : null,
                icon: const Icon(Icons.inventory_2_outlined),
                label: const Text('입고 등록'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(staffPurchaseOrderProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('입고 대상 발주'),
        backgroundColor: Colors.blueGrey.shade50,
        actions: [
          IconButton(
            tooltip: '새로고침',
            onPressed: state.isLoading
                ? null
                : () {
                    ref
                        .read(staffPurchaseOrderProvider.notifier)
                        .getPurchaseOrderList();
                  },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Builder(
            builder: (context) {
              if (state.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              if (state.errorMessage != null) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(state.errorMessage!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            ref
                                .read(staffPurchaseOrderProvider.notifier)
                                .getPurchaseOrderList();
                          },
                          child: const Text('다시 조회'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final orders = state.inboundAvailableOrders;

              if (orders.isEmpty) {
                return const Center(child: Text('입고 가능한 발주가 없습니다.'));
              }

              return RefreshIndicator(
                onRefresh: () => ref
                    .read(staffPurchaseOrderProvider.notifier)
                    .getPurchaseOrderList(),
                child: ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    return _buildOrderCard(orders[index]);
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
