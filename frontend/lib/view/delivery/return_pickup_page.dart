import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../vm/delivery/return_pickup_notifier.dart';
import '../../vm/operations/pickup_query_notifier.dart';
import '../operations/operations_widgets.dart';

class ReturnPickupPage extends ConsumerWidget {
  const ReturnPickupPage({super.key});
  String _date(DateTime? date) =>
      date?.toIso8601String().split('T').first ?? '-';
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(returnPickupProvider);
    final notifier = ref.read(returnPickupProvider.notifier);
    final busy = state.isLoading || state.isProcessing;
    final query = ref.watch(pickupQueryProvider);
    final pickups = state.filteredPickups
        .where(
          (pickup) => [
            pickup.returnId,
            pickup.orderId,
            pickup.orderItemId,
            pickup.shippingAddress,
          ].any((value) => value.toLowerCase().contains(query)),
        )
        .toList();
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
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: TextField(
              decoration: const InputDecoration(
                labelText: '조회된 수거 내 검색',
                hintText: '반품·주문 번호 또는 수거지',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: ref.read(pickupQueryProvider.notifier).change,
            ),
          ),
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
                    label: Text(
                      '${entry.value} ${entry.key == 'ALL' ? state.pickups.length : state.pickups.where((pickup) => pickup.pickupStatus == entry.key).length}',
                    ),
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
                  if (!state.isLoading && pickups.isEmpty)
                    OperationsEmpty(
                      title: state.errorMessage != null
                          ? '수거 목록을 불러오지 못했습니다.'
                          : '조건에 맞는 수거가 없습니다.',
                      message: state.errorMessage != null
                          ? '새로고침하여 배정된 수거 업무를 확인해 주세요.'
                          : '다른 상태나 검색어로 다시 확인해 주세요.',
                      onRetry: busy ? null : notifier.fetchPickups,
                    ),
                  for (final pickup in pickups)
                    Card(
                      child: ExpansionTile(
                        onExpansionChanged: (_) =>
                            FocusScope.of(context).unfocus(),
                        title: Text(pickup.returnId),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              OperationsStatus(
                                pickup.statusText,
                                color: pickup.pickupStatus == 'COLLECTED'
                                    ? Colors.green
                                    : Colors.blueGrey,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '주문 ${pickup.orderId} · ${pickup.returnQuantity}개',
                              ),
                              Text(
                                pickup.shippingAddress,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        childrenPadding: const EdgeInsets.all(16),
                        expandedCrossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          OperationsDetails(
                            fields: {
                              '주문상품': pickup.orderItemId,
                              '수거지': pickup.shippingAddress,
                              '반품 사유': pickup.returnReason,
                              '수량': '${pickup.returnQuantity}개',
                              '반품 신청일': _date(pickup.requestedOn),
                              '회수 요청일': _date(pickup.pickupRequestedOn),
                              '수거 완료일': _date(pickup.pickupCompletedOn),
                            },
                          ),
                          const SizedBox(height: 16),
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
