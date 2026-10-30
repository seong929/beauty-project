import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beauty_project/model/customer/cart_item.dart';
import 'package:beauty_project/vm/customer/cart_handler.dart';
import 'package:beauty_project/vm/customer/checkout_flow_handler.dart';
import 'package:beauty_project/vm/customer/checkout_stock_handler.dart';
import 'package:beauty_project/vm/customer/product_handler.dart';
import 'checkout_widgets.dart';

class CheckoutStockNotice extends ConsumerWidget {
  const CheckoutStockNotice({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stock = ref.watch(checkoutStockProvider);
    if (stock.canPurchase) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        key: const Key('checkout-stock-notice'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!stock.ready && stock.error == null) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            const Text('최신 상품 재고를 확인하고 있어요.', style: TextStyle(fontSize: 12)),
          ] else if (stock.error != null)
            Text(
              stock.error!,
              style: const TextStyle(fontSize: 12, color: Colors.red),
            )
          else ...[
            const Text(
              '재고 부족 또는 판매 불가 상품이 있어 결제할 수 없습니다.',
              style: TextStyle(fontSize: 12, color: Colors.red),
            ),
            for (final issue in stock.issues)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '${issue.name} · ${issue.message}',
                  style: const TextStyle(fontSize: 11, color: Colors.red),
                ),
              ),
            if (ref.watch(checkoutFlowProvider).step !=
                CheckoutStep.information)
              TextButton(
                onPressed: () =>
                    ref.read(checkoutFlowProvider.notifier).reviewItems(),
                child: const Text('상품 수량 확인'),
              ),
          ],
          if (stock.ready || stock.error != null)
            TextButton(
              key: const Key('refresh-checkout-stock'),
              onPressed: () => ref.invalidate(productHandlerProvider),
              child: const Text('재고 다시 확인'),
            ),
        ],
      ),
    );
  }
}

class CheckoutQuantityControl extends ConsumerWidget {
  const CheckoutQuantityControl({super.key, required this.item});
  final CustomerCartItem item;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stock = ref.watch(checkoutStockProvider);
    final available = stock.available(item.product.id);
    final requested = stock.requested[item.product.id] ?? item.quantity;
    final issue = stock.byItem[item.key];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              key: ValueKey('checkout-decrease-${item.key}'),
              tooltip: '결제 수량 줄이기',
              onPressed: item.quantity <= 1
                  ? null
                  : () => ref
                        .read(cartHandlerProvider.notifier)
                        .setQuantity(item.key, item.quantity - 1),
              icon: const Icon(Icons.remove, size: 18),
            ),
            Text(
              '${item.quantity}',
              key: ValueKey('checkout-quantity-${item.key}'),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            IconButton(
              key: ValueKey('checkout-increase-${item.key}'),
              tooltip: '결제 수량 늘리기',
              onPressed:
                  available == null ||
                      requested >= available ||
                      item.quantity >= 99
                  ? null
                  : () => ref
                        .read(cartHandlerProvider.notifier)
                        .setQuantity(item.key, item.quantity + 1),
              icon: const Icon(Icons.add, size: 18),
            ),
          ],
        ),
        if (available != null)
          Text(
            '구매 가능 $available개',
            style: const TextStyle(fontSize: 10, color: CheckoutStyle.muted),
          ),
        if (issue != null)
          Text(
            issue.message,
            key: ValueKey('checkout-stock-${item.key}'),
            style: const TextStyle(fontSize: 11, color: Colors.red),
          ),
      ],
    );
  }
}

// 변경 내용(2026-10-30): 결제의 주문 상품 정보에서 수량을 조절하고 재고 부족 사유를 표시한다.
