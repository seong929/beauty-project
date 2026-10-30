import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../vm/delivery/return_pickup_notifier.dart';

class ReturnPickupPage extends ConsumerWidget {
  const ReturnPickupPage({super.key});
  String _date(DateTime? date) =>
      date?.toIso8601String().split('T').first ?? '-';
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(returnPickupProvider);
    final notifier = ref.read(returnPickupProvider.notifier);
    final busy = state.isLoading || state.isProcessing;
    return Scaffold(
      appBar: AppBar(
        title: const Text('반품 수거'),
        actions: [
          IconButton(
            tooltip: '새로고침',
            onPressed: busy ? null : notifier.fetchPickups,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              children: [
                for (final entry in const {
                  'ALL': '전체',
                  'SCHEDULED': '회수 요청',
                  'COLLECTED': '수거 완료',
                }.entries)
                  ChoiceChip(
                    label: Text(entry.value),
                    selected: state.selectedFilter == entry.key,
                    onSelected: (_) => notifier.changeFilter(entry.key),
                  ),
              ],
            ),
          ),
          if (busy) const LinearProgressIndicator(),
          if (state.errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                state.errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (state.successMessage != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(state.successMessage!),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: notifier.fetchPickups,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  if (!state.isLoading && state.filteredPickups.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('조회된 반품 수거 내역이 없습니다.'),
                    ),
                  for (final pickup in state.filteredPickups)
                    Card(
                      child: ExpansionTile(
                        title: Text(pickup.returnId),
                        subtitle: Text(
                          '${pickup.statusText} · 주문 ${pickup.orderId}',
                        ),
                        childrenPadding: const EdgeInsets.all(16),
                        expandedCrossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('주문상품: ${pickup.orderItemId}'),
                          Text('수거지: ${pickup.shippingAddress}'),
                          Text('반품 사유: ${pickup.returnReason}'),
                          Text('수량: ${pickup.returnQuantity}'),
                          Text('반품 신청일: ${_date(pickup.requestedOn)}'),
                          Text('회수 요청일: ${_date(pickup.pickupRequestedOn)}'),
                          Text('수거 완료일: ${_date(pickup.pickupCompletedOn)}'),
                          const Text('수거 완료 후 본사 수령·검수 및 환불은 별도로 처리됩니다.'),
                          const SizedBox(height: 12),
                          if (pickup.canComplete)
                            FilledButton.icon(
                              onPressed: busy
                                  ? null
                                  : () async {
                                      final confirmed = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text('수거 완료'),
                                          content: const Text(
                                            '선택한 반품을 수거 완료 처리하시겠습니까?',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, false),
                                              child: const Text('취소'),
                                            ),
                                            FilledButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, true),
                                              child: const Text('확인'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirmed == true &&
                                          context.mounted) {
                                        await notifier.completePickup(
                                          pickup.returnId,
                                        );
                                      }
                                    },
                              icon: const Icon(Icons.check_circle_outline),
                              label: const Text('수거 완료'),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
