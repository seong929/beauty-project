// Admin-only presentation. Shared STAFF/CUSTOMER views and business providers stay unchanged.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../vm/admin/management_vm.dart';
import '../../../vm/auth/auth_notifier.dart';
import '../../../vm/operations/return_filters_notifier.dart';
import '../../operations/operations_widgets.dart';

class OperationsReturnsPage extends ConsumerWidget {
  const OperationsReturnsPage({super.key});
  static const _statuses = {
    'ALL': '전체 상태',
    'REQUESTED': '신청',
    'APPROVED': '승인',
    'REJECTED': '반려',
    'COLLECTING': '회수 중',
    'INSPECTING': '검수 중',
    'COMPLETED': '검수 완료',
  };

  Future<void> _act(
    BuildContext context,
    WidgetRef ref,
    String id,
    String label,
    String action,
    String method, [
    Map<String, dynamic> extra = const {},
  ]) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(label),
        content: Text('반품 $id을(를) $label 처리하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('확인'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref
          .read(managementActionsProvider.notifier)
          .returnAction(id, action, method, extra);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$label 처리가 완료되었습니다.')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    }
  }

  Future<void> _inspect(BuildContext context, WidgetRef ref, String id) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('검수 완료'),
        content: TextField(
          controller: controller,
          maxLength: 500,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: '검수 결과',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.pop(context, value);
            },
            child: const Text('다음'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null && context.mounted) {
      await _act(context, ref, id, '검수 완료', 'inspection', 'PATCH', {
        'inspection_result': result,
      });
    }
  }

  Future<void> _refund(
    BuildContext context,
    WidgetRef ref,
    String id,
    String current,
    String target,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(switch (target) {
          'COMPLETED' => '환불 완료 기록',
          'FAILED' => '내부 환불 처리 실패 기록',
          _ => '내부 환불 처리 접수',
        }),
        content: Text(
          target == 'COMPLETED'
              ? '환불 업무를 완료했는지 확인해 주세요. 확인하면 환불 완료 상태로 저장되며 다시 변경할 수 없습니다. 외부 결제 취소·실제 금액 반환은 수행되지 않습니다.'
              : '내부 환불 업무 상태만 변경합니다. 외부 결제 취소·실제 금액 반환은 수행되지 않습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('확인'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await ref
        .read(returnManagementProvider.notifier)
        .updateRefundStatus(
          returnId: id,
          expectedStatus: current,
          refundStatus: target,
        );
  }

  String _refundLabel(Object? status) => switch (status) {
    'PENDING' => '환불 대기',
    'PROCESSING' => '환불 처리 중 (내부 접수)',
    'COMPLETED' => '환불 완료',
    'FAILED' => '환불 처리 실패',
    _ => status?.toString() ?? '-',
  };

  String _pickupLabel(Object? status) => switch (status) {
    'WAITING' => '수거 대기',
    'SCHEDULED' => '회수 요청',
    'COLLECTED' => '수거 완료',
    'FAILED' => '수거 실패',
    _ => status?.toString() ?? '-',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final returns = ref.watch(returnListProvider);
    final state = ref.watch(returnManagementProvider);
    final busy = ref.watch(managementActionsProvider) || state.isProcessing;
    final isAdmin = ref.watch(authProvider.select((auth) => auth.isAdmin));
    final statusFilter = state.selectedStatus;
    final filters = ref.watch(operationsReturnFiltersProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('반품·환불 관리'),
        actions: [
          IconButton(
            tooltip: '새로고침',
            onPressed: busy ? null : () => ref.invalidate(returnListProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(
              '환불 처리는 내부 업무 상태 관리입니다. 외부 결제 취소·실제 금액 반환은 연동되어 있지 않습니다.',
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              decoration: const InputDecoration(
                labelText: '조회된 반품 내 검색',
                hintText: '반품·주문·구매 항목·고객 ID',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: ref
                  .read(operationsReturnFiltersProvider.notifier)
                  .setQuery,
            ),
          ),
          ExpansionTile(
            title: const Text('상태 필터'),
            subtitle: const Text('반품 · 수거 · 환불 상태를 각각 선택합니다.'),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            children: [
              LayoutBuilder(
                builder: (context, bounds) {
                  final width = bounds.maxWidth < 650
                      ? bounds.maxWidth
                      : (bounds.maxWidth - 24) / 3;
                  Widget filter(
                    String label,
                    String selected,
                    Map<String, String> values,
                    ValueChanged<String> changed,
                  ) => SizedBox(
                    width: width,
                    child: DropdownButtonFormField<String>(
                      initialValue: selected,
                      isExpanded: true,
                      decoration: InputDecoration(labelText: label),
                      items: [
                        for (final entry in values.entries)
                          DropdownMenuItem(
                            value: entry.key,
                            child: Text(entry.value),
                          ),
                      ],
                      onChanged: busy
                          ? null
                          : (value) {
                              if (value != null) changed(value);
                            },
                    ),
                  );
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      filter(
                        '반품 상태',
                        statusFilter,
                        _statuses,
                        ref
                            .read(returnManagementProvider.notifier)
                            .changeStatus,
                      ),
                      filter(
                        '수거 상태',
                        filters.pickup,
                        const {
                          'ALL': '전체 수거',
                          'WAITING': '수거 대기',
                          'SCHEDULED': '회수 요청',
                          'COLLECTED': '수거 완료',
                          'FAILED': '수거 실패',
                        },
                        ref
                            .read(operationsReturnFiltersProvider.notifier)
                            .setPickup,
                      ),
                      filter(
                        '환불 상태',
                        filters.refund,
                        const {
                          'ALL': '전체 환불',
                          'PENDING': '환불 대기',
                          'PROCESSING': '환불 처리 중',
                          'COMPLETED': '환불 완료',
                          'FAILED': '환불 실패',
                        },
                        ref
                            .read(operationsReturnFiltersProvider.notifier)
                            .setRefund,
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
          Expanded(
            child: returns.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Text(
                  '반품 조회 실패: ${error.toString().replaceFirst('Exception: ', '')}',
                ),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return const OperationsEmpty(
                    title: '반품 요청이 없습니다.',
                    message: '접수된 반품은 이곳에서 승인부터 환불 기록까지 관리할 수 있습니다.',
                  );
                }
                final visible = items
                    .where(
                      (item) =>
                          (statusFilter == 'ALL' ||
                              item['return_status'] == statusFilter) &&
                          filters.matches(item),
                    )
                    .toList();
                if (visible.isEmpty) {
                  return const OperationsEmpty(
                    title: '조건에 맞는 반품이 없습니다.',
                    message: '검색어나 상태 필터를 확인해 주세요.',
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: visible.length,
                  itemBuilder: (context, index) {
                    final item = visible[index];
                    final id = item['return_id'].toString();
                    final status = item['return_status'];
                    final pickup = item['pickup_status'];
                    final refund = item['refund_status'] as String?;
                    final canRefund =
                        isAdmin &&
                        status == 'COMPLETED' &&
                        pickup == 'COLLECTED' &&
                        item['headquarters_received_on'] != null &&
                        (item['inspection_result'] as String? ?? '')
                            .trim()
                            .isNotEmpty;
                    return Card(
                      key: ValueKey('$id:$statusFilter'),
                      child: ExpansionTile(
                        onExpansionChanged: (_) =>
                            FocusScope.of(context).unfocus(),
                        title: Text(id),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  OperationsStatus(
                                    _statuses[status] ?? status.toString(),
                                  ),
                                  OperationsStatus(
                                    _pickupLabel(pickup),
                                    color: Colors.blueGrey,
                                  ),
                                  OperationsStatus(
                                    _refundLabel(refund),
                                    color: refund == 'FAILED'
                                        ? Colors.red
                                        : Colors.indigo,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '주문 ${item['order_id']} · 수량 ${item['return_quantity']}개',
                              ),
                            ],
                          ),
                        ),
                        childrenPadding: const EdgeInsets.all(16),
                        children: [
                          OperationsDetails(
                            fields: {
                              '반품 번호': id,
                              '고객': '${item['customer_id']}',
                              '구매 항목': '${item['order_item_id']}',
                              '신청일': '${item['requested_on']}',
                              '승인일': '${item['approved_on'] ?? '처리일 미제공'}',
                              '수거 완료일':
                                  '${item['pickup_completed_on'] ?? '처리일 미제공'}',
                              '본사 수령일':
                                  '${item['headquarters_received_on'] ?? '처리일 미제공'}',
                              '검수 완료일':
                                  '${item['inspection_completed_on'] ?? '처리일 미제공'}',
                              '반품 사유': '${item['return_reason']}',
                              '검수 결과': '${item['inspection_result'] ?? '-'}',
                            },
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (canRefund &&
                                  (refund == 'PENDING' || refund == 'FAILED'))
                                FilledButton(
                                  onPressed: busy
                                      ? null
                                      : () => _refund(
                                          context,
                                          ref,
                                          id,
                                          refund!,
                                          'PROCESSING',
                                        ),
                                  child: Text(
                                    refund == 'FAILED'
                                        ? '내부 환불 재접수'
                                        : '내부 환불 처리 접수',
                                  ),
                                ),
                              if (canRefund && refund == 'PROCESSING')
                                FilledButton(
                                  onPressed: busy
                                      ? null
                                      : () => _refund(
                                          context,
                                          ref,
                                          id,
                                          refund!,
                                          'COMPLETED',
                                        ),
                                  child: const Text('환불 완료 기록'),
                                ),
                              if (canRefund && refund == 'PROCESSING')
                                OutlinedButton(
                                  onPressed: busy
                                      ? null
                                      : () => _refund(
                                          context,
                                          ref,
                                          id,
                                          refund!,
                                          'FAILED',
                                        ),
                                  child: const Text('내부 환불 처리 실패 기록'),
                                ),
                              if (status == 'REQUESTED') ...[
                                FilledButton(
                                  onPressed: busy
                                      ? null
                                      : () => _act(
                                          context,
                                          ref,
                                          id,
                                          '승인',
                                          'decision',
                                          'PATCH',
                                          {'return_status': 'APPROVED'},
                                        ),
                                  child: const Text('승인'),
                                ),
                                OutlinedButton(
                                  onPressed: busy
                                      ? null
                                      : () => _act(
                                          context,
                                          ref,
                                          id,
                                          '반려',
                                          'decision',
                                          'PATCH',
                                          {'return_status': 'REJECTED'},
                                        ),
                                  child: const Text('반려'),
                                ),
                              ],
                              if (status == 'APPROVED' && pickup == 'WAITING')
                                FilledButton(
                                  onPressed: busy
                                      ? null
                                      : () => _act(
                                          context,
                                          ref,
                                          id,
                                          '회수 요청',
                                          'pickup',
                                          'POST',
                                        ),
                                  child: const Text('회수 요청'),
                                ),
                              if (status == 'COLLECTING' &&
                                  pickup == 'SCHEDULED') ...[
                                FilledButton(
                                  onPressed: busy
                                      ? null
                                      : () => _act(
                                          context,
                                          ref,
                                          id,
                                          '회수 완료',
                                          'pickup-status',
                                          'PATCH',
                                          {'pickup_status': 'COLLECTED'},
                                        ),
                                  child: const Text('회수 완료'),
                                ),
                                OutlinedButton(
                                  onPressed: busy
                                      ? null
                                      : () => _act(
                                          context,
                                          ref,
                                          id,
                                          '회수 실패',
                                          'pickup-status',
                                          'PATCH',
                                          {'pickup_status': 'FAILED'},
                                        ),
                                  child: const Text('회수 실패'),
                                ),
                              ],
                              if (status == 'COLLECTING' &&
                                  pickup == 'COLLECTED')
                                FilledButton(
                                  onPressed: busy
                                      ? null
                                      : () => _act(
                                          context,
                                          ref,
                                          id,
                                          '본사 수령',
                                          'receive',
                                          'PATCH',
                                        ),
                                  child: const Text('본사 수령'),
                                ),
                              if (status == 'INSPECTING' &&
                                  pickup == 'COLLECTED' &&
                                  item['headquarters_received_on'] != null)
                                FilledButton(
                                  onPressed: busy
                                      ? null
                                      : () => _inspect(context, ref, id),
                                  child: const Text('검수 완료'),
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
