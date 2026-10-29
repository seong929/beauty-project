
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../model/admin/outbound.dart';
import '../../vm/admin/outbound_notifier.dart';

class OutboundPage extends ConsumerWidget {
  const OutboundPage({super.key});

  // 출고 대상 주문 목록
  Widget _buildOrderList(
    BuildContext context,
    WidgetRef ref,
    List<OutboundOrder> orders,
    String? selectedOrderId,
    bool isProcessing,
  ) {
    if (orders.isEmpty) {
      return const Center(
        child: Text('출고 대기 중인 주문이 없습니다.'),
      );
    }

    return ListView.builder(
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        final isSelected = selectedOrderId == order.orderId;

        return Card(
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer
              : null,
          child: ListTile(
            selected: isSelected,
            title: Text('주문번호: ${order.orderId}'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('고객 ID: ${order.customerId}'),
                Text('주문 상태: ${order.orderStatus}'),
                Text('배송지: ${order.shippingAddress}'),
              ],
            ),
            trailing: isSelected
                ? const Icon(Icons.check_circle)
                : const Icon(Icons.chevron_right),
            onTap: isProcessing
                ? null
                : () {
                    ref
                        .read(outboundProvider.notifier)
                        .selectOrder(order.orderId);
                  },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outboundState = ref.watch(outboundProvider);
    final outboundNotifier = ref.read(outboundProvider.notifier);

    // 첫 화면 진입 시 주문 목록 조회
    // build()에서 직접 API를 호출하지 않도록 별도 처리
    // 실제 초기 조회는 화면 진입 시 호출해야 함

    return Scaffold(
      appBar: AppBar(
        title: const Text('출고 관리'),
        actions: [
          IconButton(
            tooltip: '새로고침',
            onPressed: outboundState.isLoading ||
                    outboundState.isProcessing
                ? null
                : () {
                    outboundNotifier.fetchPreparingOrders();
                  },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          if (outboundState.isLoading)
            const LinearProgressIndicator(),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text(
                  '출고 대상 주문',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Chip(
                  label: Text(
                    '${outboundState.preparingCount}건',
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: _buildOrderList(
              context,
              ref,
              outboundState.orders,
              outboundState.selectedOrderId,
              outboundState.isProcessing,
            ),
          ),

          // 배송업체 및 출고 처리 영역
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (outboundState.selectedOrder != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      '선택한 주문: '
                      '${outboundState.selectedOrderId}',
                    ),
                  ),

                DropdownButtonFormField<String>(
                  initialValue: outboundState.selectedCarrierId,
                  decoration: const InputDecoration(
                    labelText: '배송업체 선택',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'car_seed_fast',
                      child: Text('샘플 빠른택배'),
                    ),
                    DropdownMenuItem(
                      value: 'car_seed_safe',
                      child: Text('샘플 안심택배'),
                    ),
                    DropdownMenuItem(
                      value: 'car_seed_post',
                      child: Text('샘플 우편배송'),
                    ),
                  ],
                  onChanged: outboundState.isProcessing
                      ? null
                      : (value) {
                          if (value != null) {
                            outboundNotifier.selectCarrier(value);
                          }
                        },
                ),

                const SizedBox(height: 12),

                ElevatedButton.icon(
                  onPressed: outboundState.canProcessOutbound
                      ? () async {
                          final confirmed =
                              await showDialog<bool>(
                            context: context,
                            builder: (dialogContext) {
                              return AlertDialog(
                                title: const Text('출고 확인'),
                                content: Text(
                                  '${outboundState.selectedOrderId}'
                                  ' 주문을 출고 처리하시겠습니까?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(
                                        dialogContext,
                                        false,
                                      );
                                    },
                                    child: const Text('취소'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(
                                        dialogContext,
                                        true,
                                      );
                                    },
                                    child: const Text('출고'),
                                  ),
                                ],
                              );
                            },
                          );

                          if (confirmed != true) return;

                          final success = await outboundNotifier
                              .createOutbound();

                          if (!context.mounted) return;

                          final message = success
                              ? ref
                                  .read(outboundProvider)
                                  .successMessage
                              : ref
                                  .read(outboundProvider)
                                  .errorMessage;

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                message ?? '처리 결과를 확인해 주세요.',
                              ),
                            ),
                          );
                        }
                      : null,
                  icon: const Icon(Icons.local_shipping),
                  label: Text(
                    outboundState.isProcessing
                        ? '출고 처리 중...'
                        : '선택한 주문 출고 처리',
                  ),
                ),

                if (outboundState.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      outboundState.errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
