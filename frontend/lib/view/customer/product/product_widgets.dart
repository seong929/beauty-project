import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:beauty_project/model/customer/home_product.dart';
import 'package:beauty_project/vm/customer/cart_handler.dart';
import 'package:beauty_project/vm/customer/product_handler.dart';
import 'package:beauty_project/vm/customer/review_handler.dart';
import 'package:beauty_project/vm/customer/storage_image_handler.dart';
import '../home/storage_product_image.dart';
import '../login/customer_auth_widgets.dart';
import '../mypage/mypage_screen.dart';
import 'product_cart_screen.dart';
import 'product_list.dart';
import '../customer_navigation.dart';

String productPrice(double price) =>
    '${price.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (match) => '${match[1]},')}원';

class ProductPhoto extends ConsumerWidget {
  const ProductPhoto({super.key, required this.product, this.height = 180});
  final HomeProduct product;
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remote = product.storageImage == null && product.isDatabaseProduct
        ? ref
              .watch(
                customerProductImageProvider((
                  id: product.id,
                  name: product.name,
                )),
              )
              .value
        : null;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomerProductImageFrame(
        child: product.storageImage != null
            ? CustomerStoragePhoto(
                image: product.storageImage!,
                label: product.name,
              )
            : remote != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  CustomerStoragePhoto(
                    image: remote.image,
                    label: remote.isRepresentative
                        ? '${product.name} 대표 이미지'
                        : product.name,
                  ),
                  if (remote.isRepresentative)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        color: const Color(0xE6FFFFFF),
                        child: const Text(
                          '대표 이미지',
                          style: TextStyle(
                            fontSize: 8,
                            color: SodamStyle.muted,
                          ),
                        ),
                      ),
                    ),
                ],
              )
            : product.imageAsset.isEmpty
            ? const Icon(Icons.spa_outlined, size: 40, color: SodamStyle.muted)
            : Image.asset(
                product.imageAsset,
                fit: BoxFit.contain,
                semanticLabel: product.name,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.broken_image_outlined,
                  color: SodamStyle.muted,
                ),
              ),
      ),
    );
  }
}

// 좁은 화면과 큰 글자에서는 두 열로 전환해 가격과 상품명을 읽을 수 있게 한다.
int customerProductColumns(BuildContext context, double width) =>
    width >= 330 && MediaQuery.textScalerOf(context).scale(12) <= 14 ? 3 : 2;

double customerProductCardExtent(BuildContext context, double photoHeight) =>
    photoHeight + 20 + MediaQuery.textScalerOf(context).scale(12) * 8;

class ProductRatingSortStatus extends ConsumerWidget {
  const ProductRatingSortStatus({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(productFilterProvider).sort != ProductSort.ratingHigh) {
      return const SizedBox.shrink();
    }
    final ratings = ref.watch(catalogProductRatingsProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: ratings.when(
        skipLoadingOnRefresh: false,
        loading: () => const Column(
          children: [
            LinearProgressIndicator(),
            SizedBox(height: 8),
            Text(
              '상품 별점을 불러오고 있어요.',
              style: TextStyle(fontSize: 11, color: SodamStyle.muted),
            ),
          ],
        ),
        error: (_, _) => Column(
          children: [
            const Text('별점을 불러오지 못했어요.', style: TextStyle(fontSize: 12)),
            TextButton(
              onPressed: () => ref.invalidate(catalogProductRatingsProvider),
              child: const Text('별점 다시 조회'),
            ),
          ],
        ),
        data: (_) => const Text(
          '평균 별점순 · 동점이면 리뷰 많은 순 · 리뷰 없는 상품은 마지막',
          style: TextStyle(fontSize: 10, color: SodamStyle.muted),
        ),
      ),
    );
  }
}

class ProductTile extends ConsumerWidget {
  const ProductTile({
    super.key,
    required this.product,
    required this.onTap,
    this.photoHeight = 140,
  });
  final HomeProductVariant product;
  final VoidCallback onTap;
  final double photoHeight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rating =
        ref.watch(productFilterProvider).sort == ProductSort.ratingHigh
        ? (ref.watch(catalogProductRatingsProvider).value ??
              {})[product.product.id]
        : null;
    return InkWell(
      key: ValueKey('search-product-${product.id}'),
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProductPhoto(product: product.product, height: photoHeight),
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
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
          Text(
            product.volume,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, color: SodamStyle.muted),
          ),
          const SizedBox(height: 4),
          Text(
            product.product.hasKnownPrice
                ? productPrice(product.price!)
                : '가격 확인 불가',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          if (rating != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '★ ${rating.averageLabel} (${rating.count})',
                key: ValueKey('card-rating-${product.id}'),
                style: const TextStyle(fontSize: 10, color: SodamStyle.muted),
              ),
            ),
          if (product.availableQuantity <= 0)
            const Text(
              '품절',
              style: TextStyle(fontSize: 10, color: SodamStyle.pink),
            )
          else if (!product.product.isDatabaseProduct)
            const Text(
              '예시 상품',
              style: TextStyle(fontSize: 9, color: SodamStyle.muted),
            ),
        ],
      ),
    );
  }
}

void showCustomerPreviewCart(BuildContext context) {
  if (!context.mounted) return;
  if (ModalRoute.of(context)?.settings.name == 'customer-cart') return;
  ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
  openCustomerTab(
    context,
    name: 'customer-cart',
    screen: const CustomerCartScreen(),
  );
}

void showCustomerProductProfile(BuildContext context, WidgetRef ref) {
  if (!context.mounted ||
      ModalRoute.of(context)?.settings.name == 'customer-mypage') {
    return;
  }
  openCustomerTab(
    context,
    name: 'customer-mypage',
    screen: const CustomerMyPageScreen(),
  );
}

Future<void> showCustomerProductSearch(BuildContext context) => openCustomerTab(
  context,
  name: 'customer-search',
  screen: const CustomerProductListScreen(),
);

class ProductNavigation extends ConsumerWidget {
  const ProductNavigation({
    super.key,
    required this.onSearch,
    this.selectedIndex = 1,
    this.onCart,
  });
  final VoidCallback onSearch;
  final int selectedIndex;
  final VoidCallback? onCart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref
        .watch(cartHandlerProvider)
        .fold<int>(0, (total, item) => total + item.quantity);
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: SodamStyle.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              for (final (index, label, icon) in const [
                (0, '홈', Icons.home_outlined),
                (1, '검색', Icons.grid_view_outlined),
                (2, '장바구니', Icons.shopping_bag_outlined),
                (3, '내 정보', Icons.person_outline),
              ])
                Expanded(
                  child: InkWell(
                    key: ValueKey('product-nav-$index'),
                    onTap: () {
                      switch (index) {
                        case 0:
                          returnToCustomerHome(context);
                        case 1:
                          if (selectedIndex == 1) {
                            onSearch();
                          } else {
                            showCustomerProductSearch(context);
                          }
                        case 2:
                          if (onCart != null) {
                            onCart!();
                          } else {
                            showCustomerPreviewCart(context);
                          }
                        case 3:
                          showCustomerProductProfile(context, ref);
                      }
                    },
                    child: Semantics(
                      selected: index == selectedIndex,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Badge(
                            isLabelVisible: index == 2 && count > 0,
                            label: Text('$count'),
                            child: Icon(
                              icon,
                              size: 20,
                              color: index == selectedIndex
                                  ? SodamStyle.ink
                                  : SodamStyle.muted,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 9,
                              color: index == selectedIndex
                                  ? SodamStyle.green
                                  : SodamStyle.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// 변경 내용(2026-10-30): 상품 사진의 찜 버튼과 찜 위젯을 제거했다.
