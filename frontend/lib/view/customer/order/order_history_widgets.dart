import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beauty_project/model/customer/order.dart';
import 'package:beauty_project/vm/customer/product_handler.dart';
import '../login/customer_auth_widgets.dart';
import '../product/product_widgets.dart';

String historyStatusLabel(String status) => switch (status) {
  'PENDING' => '결제 대기',
  'PAID' => '결제 완료',
  'PREPARING' => '배송 준비',
  'SHIPPED' => '배송 중',
  'DELIVERED' => '수령 완료',
  'CANCELLED' => '주문 취소',
  'RETURNED' => '반품 완료',
  _ => status,
};

class OrderStatusBadge extends StatelessWidget {
  const OrderStatusBadge({super.key, required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final completed = status == 'DELIVERED';
    final stopped = const {'CANCELLED', 'RETURNED'}.contains(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: stopped
            ? const Color(0xFFF5E7E4)
            : completed
            ? const Color(0xFFE4EFE2)
            : const Color(0xFFF9EFDE),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        historyStatusLabel(status),
        style: TextStyle(
          fontSize: 11,
          color: stopped
              ? const Color(0xFFAA655F)
              : completed
              ? SodamStyle.green
              : const Color(0xFF9A7841),
        ),
      ),
    );
  }
}

class OrderProductInformation extends ConsumerWidget {
  const OrderProductInformation({super.key, required this.item, this.trailing});
  final CustomerOrderLine item;
  final Widget? trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final product = ref
        .watch(homeCatalogProductsProvider)
        .value
        ?.where((product) => product.id == item.productId)
        .firstOrNull;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 82,
            child: product == null
                ? Container(
                    height: 100,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF6F7F8),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.spa_outlined,
                      color: SodamStyle.muted,
                      size: 30,
                    ),
                  )
                : ProductPhoto(product: product, height: 100),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (product != null && product.brand.isNotEmpty)
                  Text(
                    product.brand,
                    style: const TextStyle(
                      fontSize: 11,
                      color: SodamStyle.muted,
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: item.saleOption == 'NEAR_EXPIRY'
                            ? const Color(0xFFF7E3DF)
                            : const Color(0xFFE4EFE2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item.saleLabel,
                        style: TextStyle(
                          fontSize: 10,
                          color: item.saleOption == 'NEAR_EXPIRY'
                              ? const Color(0xFFAF6D62)
                              : SodamStyle.green,
                        ),
                      ),
                    ),
                    Text(
                      '${product?.volume.isNotEmpty == true ? '${product!.volume} · ' : ''}${item.quantity}개',
                      style: const TextStyle(
                        fontSize: 11,
                        color: SodamStyle.muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  productPrice(item.total),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (trailing != null) ...[const SizedBox(height: 8), trailing!],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class OrderInformationRow extends StatelessWidget {
  const OrderInformationRow(
    this.label,
    this.value, {
    super.key,
    this.bold = false,
  });
  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 98,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: SodamStyle.muted),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 12,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
              height: 1.6,
            ),
          ),
        ),
      ],
    ),
  );
}

class OrderLoadError extends StatelessWidget {
  const OrderLoadError({super.key, required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(error.toString()),
        TextButton(onPressed: onRetry, child: const Text('다시 조회')),
      ],
    ),
  );
}
