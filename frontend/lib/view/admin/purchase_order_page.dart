
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../model/admin/purchase_order.dart';
import '../../vm/admin/purchase_order_notifier.dart';

class PurchaseOrderPage extends ConsumerStatefulWidget {
  const PurchaseOrderPage({super.key});

  @override
  ConsumerState<PurchaseOrderPage> createState() =>
      _PurchaseOrderPageState();
}

class _PurchaseOrderPageState
    extends ConsumerState<PurchaseOrderPage> {
  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      if (!mounted) return;

      ref
          .read(purchaseOrderProvider.notifier)
          .getPurchaseOrderList();
    });
  }

  // 발주 등록 입력창
  Future<void> _showCreateDialog() async {
    final approvalController = TextEditingController();
    final manufacturerController = TextEditingController();
    final priceController = TextEditingController();

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return Consumer(
            builder: (context, ref, child) {
              final orderState = ref.watch(purchaseOrderProvider);

              return AlertDialog(
                title: const Text('발주 등록'),
                content: SizedBox(
                  width: 420,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: approvalController,
                          enabled: !orderState.isProcessing,
                          decoration: const InputDecoration(
                            labelText: '품의 ID',
                            hintText: '승인된 품의 ID 입력',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: manufacturerController,
                          enabled: !orderState.isProcessing,
                          decoration: const InputDecoration(
                            labelText: '제조사 ID',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: priceController,
                          enabled: !orderState.isProcessing,
                          keyboardType:
                              const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                          decoration: const InputDecoration(
                            labelText: '개당 공급 단가',
                            suffixText: '원',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: orderState.isProcessing
                        ? null
                        : () => Navigator.pop(dialogContext),
                    child: const Text('취소'),
                  ),
                  ElevatedButton(
                    onPressed: orderState.isProcessing
                        ? null
                        : () async {
                            final success = await ref
                                .read(
                                  purchaseOrderProvider.notifier,
                                )
                                .createPurchaseOrder(
                                  approvalId:
                                      approvalController.text,
                                  manufacturerId:
                                      manufacturerController.text,
                                  unitSupplyPrice:
                                      priceController.text,
                                );

                            if (!dialogContext.mounted) return;

                            if (success) {
                              Navigator.pop(dialogContext);

                              if (!mounted) return;

                              ScaffoldMessenger.of(context)
                                  .showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    '발주 등록이 완료되었습니다.',
                                  ),
                                ),
                              );
                            } else {
                              final error = ref
                                  .read(purchaseOrderProvider)
                                  .errorMessage;

                              ScaffoldMessenger.of(dialogContext)
                                  .showSnackBar(
                                SnackBar(
                                  content: Text(
                                    error ?? '발주 등록에 실패했습니다.',
                                  ),
                                ),
                              );
                            }
                          },
                    child: orderState.isProcessing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('등록'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      // 다이얼로그 종료 후 입력 컨트롤러 정리
      // 종료 애니메이션이 끝난 다음 dispose하도록
      // 컨트롤러는 다이얼로그 내부 위젯에서 관리하는 것이
      // 더 안전하므로 이 단계에서는 별도 dispose를 하지 않음.
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderState = ref.watch(purchaseOrderProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('본사 관리자 - 발주 관리'),
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
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              onPressed: orderState.isProcessing
                  ? null
                  : _showCreateDialog,
              icon: const Icon(Icons.add),
              label: const Text('발주 등록'),
            ),
          ),
        ],
      ),
      body: Row(
        children: [
          // 왼쪽: 발주 목록
          Expanded(
            flex: 4,
            child: _buildPurchaseOrderList(orderState),
          ),

          const VerticalDivider(width: 1),

          // 오른쪽: 발주 상세
          Expanded(
            flex: 6,
            child: _buildPurchaseOrderDetail(
              orderState.selectedPurchaseOrder,
            ),
          ),
        ],
      ),
    );
  }

  // 발주 목록 영역
  Widget _buildPurchaseOrderList(dynamic orderState) {
    if (orderState.isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (orderState.errorMessage != null &&
        orderState.purchaseOrders.isEmpty) {
      return Center(
        child: Text(orderState.errorMessage!),
      );
    }

    if (orderState.purchaseOrders.isEmpty) {
      return const Center(
        child: Text('등록된 발주가 없습니다.'),
      );
    }

    return ListView.builder(
      itemCount: orderState.purchaseOrders.length,
      itemBuilder: (context, index) {
        final PurchaseOrder order =
            orderState.purchaseOrders[index];

        final selected =
            orderState.selectedPurchaseOrder?.purchaseOrderId ==
            order.purchaseOrderId;

        return ListTile(
          selected: selected,
          title: Text(order.cosmeticName),
          subtitle: Text(
            '${order.manufacturerName}\n'
            '발주 ID: ${order.purchaseOrderId}',
          ),
          isThreeLine: true,
          trailing: Text(order.purchaseStatus),
          onTap: () {
            ref
                .read(purchaseOrderProvider.notifier)
                .selectPurchaseOrder(order);
          },
        );
      },
    );
  }

  // 발주 상세 영역
  Widget _buildPurchaseOrderDetail(PurchaseOrder? order) {
    if (order == null) {
      return const Center(
        child: Text('발주 내역을 선택해 주세요.'),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '발주 상세 정보',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 24),

          _detailRow('발주 ID', order.purchaseOrderId),
          _detailRow('품의 ID', order.approvalId),
          _detailRow(
            '발주 차수',
            '${order.purchaseOrderSeq}차',
          ),
          _detailRow('상품명', order.cosmeticName),
          _detailRow('상품 ID', order.cosmeticId),
          _detailRow('제조사', order.manufacturerName),
          _detailRow('제조사 ID', order.manufacturerId),
          _detailRow(
            '발주일',
            '${order.orderedOn.year}-'
            '${order.orderedOn.month.toString().padLeft(2, '0')}-'
            '${order.orderedOn.day.toString().padLeft(2, '0')}',
          ),
          _detailRow(
            '발주 수량',
            '${order.orderQuantity}개',
          ),
          _detailRow(
            '공급 단가',
            '${order.unitSupplyPrice.toStringAsFixed(2)}원',
          ),
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
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}
