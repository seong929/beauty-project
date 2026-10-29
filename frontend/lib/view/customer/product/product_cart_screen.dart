import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:beauty_project/vm/customer/cart_handler.dart';
import 'package:beauty_project/vm/customer/cart_persistence_handler.dart';
import '../login/customer_auth_widgets.dart';
import '../order/check_screen.dart';
import 'cart_item_card.dart';
import 'product_list.dart';
import 'product_widgets.dart';

class CustomerCartScreen extends ConsumerStatefulWidget {
  const CustomerCartScreen({super.key});

  @override
  ConsumerState<CustomerCartScreen> createState() => _CustomerCartScreenState();
}

class _CustomerCartScreenState extends ConsumerState<CustomerCartScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) ref.read(cartPersistenceProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(cartHandlerProvider);
    final selected = ref.watch(selectedCartItemsProvider);
    final total = ref.watch(selectedCartTotalProvider);
    final sync = ref.watch(cartPersistenceProvider);
    return Scaffold(
      key: const Key('customer-cart-screen'),
      appBar: AppBar(title: const Text('장바구니')),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('cart-go-checkout'),
                onPressed: selected.isEmpty || sync.isLoading
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CustomerCheckoutScreen(),
                          ),
                        );
                      },
                child: const Text('함께 결제 페이지로 이동'),
              ),
            ),
          ),
          ProductNavigation(
            selectedIndex: 2,
            onCart: () {},
            onSearch: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const CustomerProductListScreen(),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (sync.isLoading) const LinearProgressIndicator(),
          if (sync.hasError)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Text(
                    sync.error.toString(),
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                  TextButton(
                    key: const Key('retry-cart-sync'),
                    onPressed: () =>
                        ref.read(cartPersistenceProvider.notifier).refresh(),
                    child: const Text('다시 조회'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: items.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.shopping_bag_outlined,
                              size: 42,
                              color: SodamStyle.muted,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              sync.isLoading
                                  ? '장바구니를 불러오는 중입니다.'
                                  : sync.hasError
                                  ? '저장된 장바구니를 다시 조회해 주세요.'
                                  : '장바구니가 비어 있어요.',
                            ),
                            TextButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const CustomerProductListScreen(),
                                ),
                              ),
                              child: const Text('상품 둘러보기'),
                            ),
                          ],
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '장바구니 ${items.length}',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              TextButton(
                                key: const Key('clear-cart'),
                                onPressed: sync.isLoading
                                    ? null
                                    : () => ref
                                          .read(
                                            cartPersistenceProvider.notifier,
                                          )
                                          .clearStoredCart(),
                                child: const Text('전체 비움'),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEFAFB),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              '상품 담기·삭제는 서버에 저장됩니다. 기존 API에는 수량 저장 항목이 없어, 수량은 현재 앱에서만 유지되고 다시 로그인하면 1개로 표시됩니다.',
                              style: TextStyle(
                                fontSize: 11,
                                height: 1.8,
                                color: SodamStyle.muted,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Checkbox(
                                key: const Key('select-all-cart'),
                                value: selected.length == items.length,
                                onChanged: (value) => ref
                                    .read(cartHandlerProvider.notifier)
                                    .selectAll(value ?? false),
                              ),
                              Text(
                                '전체 선택 (${selected.length}/${items.length})',
                                style: const TextStyle(fontSize: 12),
                              ),
                              const Spacer(),
                              const Text(
                                '저장된 상품',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: SodamStyle.muted,
                                ),
                              ),
                            ],
                          ),
                          for (final item in items) CartItemCard(item: item),
                          const SizedBox(height: 20),
                          Text(
                            '합계 ${productPrice(total)}',
                            key: const Key('preview-cart-total'),
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            '선택한 상품 금액 기준 · 배송비 0원 (예시)',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 10,
                              color: SodamStyle.muted,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
