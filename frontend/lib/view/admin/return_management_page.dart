import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../vm/admin/management_vm.dart';

class ReturnManagementPage extends ConsumerWidget {
  const ReturnManagementPage({super.key});

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final returns = ref.watch(returnListProvider);
    final busy = ref.watch(managementActionsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('반품 관리'),
        actions: [
          IconButton(
            tooltip: '새로고침',
            onPressed: () => ref.invalidate(returnListProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: returns.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text(
            '반품 조회 실패: ${error.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
        data: (items) {
          if (items.isEmpty) return const Center(child: Text('반품 요청이 없습니다.'));
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final id = item['return_id'].toString();
              final status = item['return_status'];
              final pickup = item['pickup_status'];
              return Card(
                child: ExpansionTile(
                  title: Text('반품 $id · ${item['return_status']}'),
                  subtitle: Text(
                    '주문 ${item['order_id']} · 수량 ${item['return_quantity']} · 회수 ${pickup ?? '-'}',
                  ),
                  childrenPadding: const EdgeInsets.all(16),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '고객: ${item['customer_id']}\n주문 상품: ${item['order_item_id']}\n신청일: ${item['requested_on']}\n사유: ${item['return_reason']}\n환불: ${item['refund_status']}\n검수 결과: ${item['inspection_result'] ?? '-'}',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
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
                        if (status == 'COLLECTING' && pickup == 'COLLECTED')
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
    );
  }
}
