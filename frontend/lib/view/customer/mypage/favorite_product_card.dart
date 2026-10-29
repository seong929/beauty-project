import 'package:flutter/material.dart';
import 'package:beauty_project/vm/customer/product_search_handler.dart';
import '../login/customer_auth_widgets.dart';
import '../product/product_detail.dart';
import '../product/product_widgets.dart';

class FavoriteProductCard extends StatelessWidget {
  const FavoriteProductCard({super.key, required this.entry});
  final FavoriteProductEntry entry;

  @override
  Widget build(BuildContext context) {
    final product = entry.product;
    final note = entry.soldOut
        ? '현재 품절입니다. 입고 후 구매할 수 있습니다.'
        : entry.listed == false
        ? '현재 판매 목록에서 확인되지 않는 상품입니다. 찜은 언제든 해제할 수 있습니다.'
        : entry.listed == null
        ? '판매 상태를 확인하지 못했습니다. 새로고침해 주세요.'
        : product?.hasKnownPrice != true
        ? '가격 정보를 확인한 후 구매할 수 있습니다.'
        : null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          key: Key('favorite-product-${entry.id}'),
          borderRadius: BorderRadius.circular(12),
          onTap: !entry.canPurchase || product == null
              ? null
              : () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        CustomerProductDetailScreen(product: product),
                  ),
                ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 4),
                margin: const EdgeInsets.only(bottom: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEFAFB),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  entry.soldOut
                      ? '품절'
                      : entry.listed == false
                      ? '판매 확인 불가'
                      : product?.category ?? '판매 정보 없음',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 9, color: SodamStyle.muted),
                ),
              ),
              if (product != null)
                ProductPhoto(product: product, height: 135)
              else
                Container(
                  height: 135,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6F7F8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.spa_outlined,
                    size: 36,
                    color: SodamStyle.muted,
                  ),
                ),
              const SizedBox(height: 9),
              if (product?.brand.isNotEmpty == true)
                Text(
                  product!.brand,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: SodamStyle.muted),
                ),
              Text(
                product?.name ?? '판매 정보를 확인할 수 없는 상품',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                product?.volume.isNotEmpty == true
                    ? product!.volume
                    : product?.options.first.label ?? entry.id,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, color: SodamStyle.muted),
              ),
            ],
          ),
        ),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (entry.listed != true && product?.hasKnownPrice == true)
                    const Text(
                      '최근 확인 가격',
                      style: TextStyle(fontSize: 9, color: SodamStyle.muted),
                    ),
                  Text(
                    product?.hasKnownPrice == true
                        ? productPrice(product!.price!)
                        : '가격 확인 불가',
                    maxLines: 2,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 40,
              height: 36,
              child: ProductFavoriteButton(
                productId: entry.id,
                product: product,
              ),
            ),
          ],
        ),
        if (note != null)
          Container(
            key: Key('favorite-note-${entry.id}'),
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: entry.listed == false
                  ? const Color(0xFFF8E9E5)
                  : const Color(0xFFFCF2E3),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              note,
              style: TextStyle(
                fontSize: 11,
                height: 1.6,
                color: entry.listed == false
                    ? const Color(0xFFAC6A61)
                    : const Color(0xFF9C7B4D),
              ),
            ),
          ),
      ],
    );
  }
}
