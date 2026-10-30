import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beauty_project/model/customer/storage_product.dart';
import 'package:beauty_project/vm/customer/product_handler.dart';
import 'package:beauty_project/vm/customer/review_handler.dart';
import '../login/customer_auth_widgets.dart';
import '../product/product_widgets.dart';
import 'storage_product_image.dart';

class StorageProductTile extends ConsumerWidget {
  const StorageProductTile({
    super.key,
    required this.product,
    required this.photoHeight,
    required this.onTap,
  });
  final StorageProduct product;
  final double photoHeight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rating =
        ref.watch(productFilterProvider).sort == ProductSort.ratingHigh
        ? (ref.watch(catalogProductRatingsProvider).value ?? {})[product.id]
        : null;
    return InkWell(
      key: ValueKey('search-product-${product.id}:${product.volume}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: photoHeight,
            width: double.infinity,
            child: CustomerStoragePhoto(
              image: product.image,
              label: product.name,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            customerBrandText(product.brand),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, color: SodamStyle.muted),
          ),
          Text(
            product.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (product.volume.isNotEmpty)
            Text(
              product.volume,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: SodamStyle.muted),
            ),
          const SizedBox(height: 4),
          Text(
            product.price == null ? '상품 이미지 보기' : productPrice(product.price!),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: product.price == null ? 10 : 13,
              color: product.price == null ? SodamStyle.muted : SodamStyle.ink,
              fontWeight: product.price == null
                  ? FontWeight.normal
                  : FontWeight.w700,
            ),
          ),
          if (product.isTemporary)
            const Text(
              '임시 가격·용량',
              style: TextStyle(fontSize: 9, color: SodamStyle.muted),
            ),
          if (rating != null)
            Text(
              '★ ${rating.averageLabel} (${rating.count})',
              key: ValueKey('card-rating-${product.id}:${product.volume}'),
              style: const TextStyle(fontSize: 10, color: SodamStyle.muted),
            ),
        ],
      ),
    );
  }
}

// 변경 내용(2026-10-30): 홈·검색에서 같은 Firebase 카드와 용량·가격을 사용하고 임시 값을 구분한다.
