import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beauty_project/model/customer/order.dart';
import 'package:beauty_project/vm/customer/order_handler.dart';
import '../login/customer_auth_widgets.dart';
import '../product/product_list.dart';
import '../product/product_widgets.dart';
import 'list_screen.dart';
import 'order_summary.dart';

class CustomerOrderCompleteScreen extends ConsumerWidget {
  const CustomerOrderCompleteScreen({super.key, required this.order});
  final CustomerOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved =
        ref
            .watch(customerOrdersProvider)
            .value
            ?.where((item) => item.id == order.id)
            .firstOrNull ??
        order;
    return Scaffold(
      key: const Key('customer-order-complete'),
      appBar: AppBar(
        title: const Text('결제 결과 · 주문 완료'),
        actions: [
          TextButton(
            onPressed: () => showCustomerPreviewCart(context),
            child: const Text('장바구니'),
          ),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('complete-view-orders'),
                onPressed: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => const CustomerOrderListScreen(),
                  ),
                ),
                child: const Text('구매 내역 보기'),
              ),
            ),
          ),
          ProductNavigation(
            selectedIndex: -1,
            onSearch: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const CustomerProductListScreen(),
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
            children: [
              const CircleAvatar(
                radius: 30,
                backgroundColor: Color(0xFFEEFAFB),
                child: Icon(Icons.check, color: SodamStyle.green, size: 30),
              ),
              const SizedBox(height: 20),
              const Text(
                '주문이 완료되었어요',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                '하나를 찾아주셔서 고마워요.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: SodamStyle.muted),
              ),
              const SizedBox(height: 8),
              const Text(
                '주문이 결제 완료 상태로 저장되었습니다.\n카드·계좌 결제 승인은 연동되어 있지 않습니다.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: SodamStyle.muted,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 26),
              CustomerOrderSummary(order: saved),
            ],
          ),
        ),
      ),
    );
  }
}
