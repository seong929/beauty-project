import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:beauty_project/model/customer/cart_item.dart';
import 'package:beauty_project/model/customer/home_product.dart';
import 'package:beauty_project/vm/customer/cart_handler.dart';
import 'package:beauty_project/vm/customer/cart_persistence_handler.dart';
import '../login/customer_auth_widgets.dart';
import 'product_widgets.dart';

class CartItemCard extends ConsumerWidget {
  const CartItemCard({
    super.key,
    required this.item,
    this.showSelection = true,
  });
  final CustomerCartItem item;
  final bool showSelection;

  Future<void> _changeSize(BuildContext context, WidgetRef ref) async {
    final selected = await showModalBottomSheet<HomeProductOption>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '사이즈 변경',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              for (final option in item.product.options)
                ListTile(
                  key: ValueKey('cart-size-${option.label}'),
                  title: Text(option.label),
                  subtitle: Text(productPrice(option.price)),
                  trailing: item.option.label == option.label
                      ? const Icon(Icons.check, color: SodamStyle.green)
                      : null,
                  onTap: () => Navigator.pop(context, option),
                ),
            ],
          ),
        ),
      ),
    );
    if (selected == null || !context.mounted) return;
    if (!ref
        .read(cartHandlerProvider.notifier)
        .changeOption(item.key, selected)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('같은 사이즈는 최대 99개까지 담을 수 있어요.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => Container(
    key: ValueKey('cart-item-${item.key}'),
    padding: const EdgeInsets.symmetric(vertical: 14),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: SodamStyle.border)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showSelection)
          Row(
            children: [
              Checkbox(
                key: ValueKey('select-${item.key}'),
                value: item.selected,
                onChanged: (selected) => ref
                    .read(cartHandlerProvider.notifier)
                    .select(item.key, selected ?? false),
              ),
              Expanded(
                child: Text(
                  item.product.brand,
                  style: const TextStyle(fontSize: 10, color: SodamStyle.muted),
                ),
              ),
              IconButton(
                key: ValueKey('remove-${item.key}'),
                tooltip: '상품 삭제',
                icon: const Icon(Icons.close, size: 18),
                onPressed: ref.watch(cartPersistenceProvider).isLoading
                    ? null
                    : () => ref
                          .read(cartPersistenceProvider.notifier)
                          .remove(item.key),
              ),
            ],
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 78,
              child: ProductPhoto(product: item.product, height: 100),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    item.product.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${item.option.label} · ${item.quantity}개',
                    style: const TextStyle(
                      fontSize: 11,
                      color: SodamStyle.muted,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.product.hasKnownPrice
                              ? productPrice(item.option.price)
                              : '가격 확인 불가',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        key: ValueKey('decrease-${item.key}'),
                        tooltip: '수량 줄이기',
                        visualDensity: VisualDensity.compact,
                        onPressed: item.quantity <= 1
                            ? null
                            : () => ref
                                  .read(cartHandlerProvider.notifier)
                                  .setQuantity(item.key, item.quantity - 1),
                        icon: const Icon(Icons.remove, size: 16),
                      ),
                      Text(
                        '${item.quantity}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      IconButton(
                        key: ValueKey('increase-${item.key}'),
                        tooltip: '수량 늘리기',
                        visualDensity: VisualDensity.compact,
                        onPressed: item.quantity >= 99
                            ? null
                            : () => ref
                                  .read(cartHandlerProvider.notifier)
                                  .setQuantity(item.key, item.quantity + 1),
                        icon: const Icon(Icons.add, size: 16),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (item.product.options.length > 1)
          OutlinedButton(
            key: ValueKey('change-size-${item.key}'),
            onPressed: () => _changeSize(context, ref),
            child: const Text('사이즈 변경'),
          ),
        const SizedBox(height: 4),
        Text(
          item.product.hasKnownPrice
              ? '상품 금액 ${productPrice(item.totalPrice)}'
              : '현재 판매 정보를 확인할 수 없습니다.',
          textAlign: TextAlign.right,
          style: const TextStyle(fontSize: 12, color: SodamStyle.muted),
        ),
      ],
    ),
  );
}
