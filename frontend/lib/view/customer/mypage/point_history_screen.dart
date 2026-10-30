import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beauty_project/vm/customer/point_handler.dart';
import '../login/customer_auth_widgets.dart';

class CustomerPointHistoryScreen extends ConsumerWidget {
  const CustomerPointHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('포인트 내역')),
    body: RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(customerPointsProvider);
        await ref.read(customerPointsProvider.future);
      },
      child: ref
          .watch(customerPointsProvider)
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => ListView(
              children: [
                const SizedBox(height: 80),
                Center(child: Text(error.toString())),
                TextButton(
                  onPressed: () => ref.invalidate(customerPointsProvider),
                  child: const Text('다시 조회'),
                ),
              ],
            ),
            data: (account) => ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: SodamStyle.soft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('보유 포인트'),
                      const SizedBox(height: 8),
                      Text(
                        '${account.balance}P',
                        key: const Key('point-balance'),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        '1P는 1원으로 사용할 수 있습니다.\n포인트 차감 후 결제 금액의 10%가 적립됩니다.\n소수점 이하는 버리며 주문 취소 시 사용 포인트는 복원하고 적립 포인트는 회수합니다.',
                        style: TextStyle(fontSize: 12, height: 1.6),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                if (account.history.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: Text('포인트 내역이 없습니다.')),
                  ),
                for (final entry in account.history)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(switch (entry.type) {
                      'EARN' => '구매 적립 (10%)',
                      'USE' => '주문 결제 · 포인트 사용',
                      'RESTORE' => '주문 취소 · 사용 포인트 복원',
                      _ => '주문 취소 · 적립 회수',
                    }),
                    subtitle: Text(
                      '${entry.createdAt.toString().substring(0, 16)}\n${entry.orderId} · 잔액 ${entry.balanceAfter}P',
                    ),
                    isThreeLine: true,
                    trailing: Text(
                      '${entry.delta > 0 ? '+' : ''}${entry.delta}P',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: entry.delta > 0 ? SodamStyle.green : Colors.red,
                      ),
                    ),
                  ),
              ],
            ),
          ),
    ),
  );
}
