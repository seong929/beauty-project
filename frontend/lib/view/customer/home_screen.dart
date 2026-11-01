// 기능: 홈 검색·필터·추천 이미지·판매 상품과 탭 이동.
// 표시 계층: ref.watch로 상태를 구독하고 사용자 동작은 Notifier·서비스에 전달한다.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beauty_project/vm/customer/state/product_filter_draft_handler.dart';

import 'package:beauty_project/model/customer/home_product.dart';
import 'package:beauty_project/vm/customer/customer_handler.dart';
import 'package:beauty_project/vm/customer/product_handler.dart';
import 'package:beauty_project/vm/customer/product_search_handler.dart';
import 'package:beauty_project/vm/customer/cart_handler.dart';
import 'package:beauty_project/vm/customer/review_handler.dart';
import 'package:beauty_project/vm/customer/storage_image_handler.dart';
import 'package:beauty_project/vm/customer/storage_product_handler.dart';
import 'home/storage_product_tile.dart';
import 'home/home_widgets.dart';
import 'home/home_product_gallery.dart';
import 'login/customer_auth_widgets.dart';
import 'product/product_detail.dart';
import 'product/product_widgets.dart';

class CustomerHomeScreen extends ConsumerStatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  ConsumerState<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends ConsumerState<CustomerHomeScreen> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  final _scroll = ScrollController();

  /// Function: 입력·포커스·스크롤 등 화면이 소유한 자원을 해제한다. Provider는 autoDispose 규칙을 따른다.
  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _showCart() {
    showCustomerPreviewCart(context);
  }

  Future<void> _openSearch() async {
    _searchFocus.unfocus();
    ref.read(recentProductSearchesProvider.notifier).add(_search.text);
    await showCustomerProductSearch(context);
    if (mounted) _search.text = ref.read(productFilterProvider).query;
  }

  void _showProfile() {
    showCustomerProductProfile(context, ref);
  }

  /// Function: 홈 필터의 임시 선택을 열고 적용한 정렬·재고 조건을 반영한다.
  Future<void> _showFilters() async {
    final current = ref.read(productFilterProvider);
    final draftProvider = productFilterDraftProvider((
      screen: Object(),
      initial: current,
    ));
    final apply = await showModalBottomSheet<ProductFilter>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => Consumer(
        builder: (context, sheetRef, _) {
          final draft = sheetRef.watch(draftProvider);
          final actions = sheetRef.read(draftProvider.notifier);
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '상품 필터',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('구매 가능한 상품만'),
                    value: draft.inStockOnly,
                    onChanged: actions.stockOnly,
                  ),
                  DropdownButtonFormField<ProductSort>(
                    initialValue: draft.sort,
                    decoration: const InputDecoration(labelText: '정렬'),
                    items: [
                      for (final (value, label) in const [
                        (ProductSort.recommended, '기본순'),
                        (ProductSort.priceLow, '낮은 가격순'),
                        (ProductSort.priceHigh, '높은 가격순'),
                        (ProductSort.ratingHigh, '별점 높은 순'),
                      ])
                        DropdownMenuItem(value: value, child: Text(label)),
                    ],
                    onChanged: (value) {
                      if (value != null) actions.sort(value);
                    },
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    key: const Key('apply-product-filters'),
                    onPressed: () =>
                        Navigator.pop(context, sheetRef.read(draftProvider)),
                    child: const Text('적용하기'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (apply != null && mounted) {
      ref
          .read(productFilterProvider.notifier)
          .apply(inStockOnly: apply.inStockOnly, sort: apply.sort);
    }
  }

  void _showProduct(HomeProductVariant product) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CustomerProductDetailScreen(
          product: product.product,
          option: product.option,
        ),
      ),
    );
  }

  void _reset() {
    _search.clear();
    _searchFocus.unfocus();
    ref.read(productFilterProvider.notifier).reset();
  }

  void _navigate(int index) {
    switch (index) {
      case 0:
        _reset();
        if (_scroll.hasClients) {
          _scroll.animateTo(
            0,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      case 1:
        _openSearch();
      case 2:
        _showCart();
      case 3:
        _showProfile();
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(customerHandlerProvider);
    return Scaffold(
      key: const Key('customer-home'),
      // 기능: 앱바 대신 검색·필터·장바구니를 한 줄에 배치하고 상태 표시줄 영역을 피한다.
      body: SafeArea(
        bottom: false,
        child: session.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const Center(child: Text('로그인 상태를 확인해 주세요.')),
          data: (customer) => customer == null
              ? const Center(child: Text('로그인이 필요합니다.'))
              : _buildHome(),
        ),
      ),
      bottomNavigationBar: session.value == null ? null : _bottomNavigation(),
    );
  }

  Widget _buildHome() {
    return Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: 480,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(catalogProductRatingsProvider);
            ref.invalidate(customerStorageImagesProvider);
            await ref.read(productHandlerProvider.notifier).refreshProducts();
          },
          child: SingleChildScrollView(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSearchBar(),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: HomeHero(),
                ),
                const SizedBox(height: 12),
                _buildBannerIndicator(),
                _buildCategories(),
                const SizedBox(height: 28),
                _buildSectionHeader(
                  '오늘의 추천 항목',
                  '조용한 변화, 나에게 맞는 아름다움',
                  actionKey: const Key('home-view-all-images'),
                  onViewAll: () => showAllCustomerProductImages(context),
                  featured: true,
                ),
                const SizedBox(height: 24),
                const HomeProductGallery(),
                const SizedBox(height: 32),
                _buildSectionHeader(
                  '지금 만나요',
                  '스킨 · 로션 · 크림을 만나보세요.',
                  actionKey: const Key('home-view-all'),
                  onViewAll: () {
                    _reset();
                    _openSearch();
                  },
                  featured: false,
                ),
                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: ProductRatingSortStatus(),
                ),
                _buildProductCatalog(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(7),
      borderSide: BorderSide.none,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 44,
              child: TextField(
                key: const Key('home-search'),
                controller: _search,
                focusNode: _searchFocus,
                onChanged: (value) =>
                    ref.read(productFilterProvider.notifier).search(value),
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _openSearch(),
                style: const TextStyle(fontSize: 12),
                decoration: InputDecoration(
                  hintText: '오늘, 어떤 피부 고민이 있나요?',
                  hintStyle: const TextStyle(fontSize: 12, color: homeMuted),
                  prefixIcon: const Icon(Icons.search, size: 18),
                  prefixIconConstraints: const BoxConstraints(minWidth: 30),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  fillColor: const Color(0xFFF6F7F8),
                  border: border,
                  enabledBorder: border,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 44,
            child: OutlinedButton.icon(
              key: const Key('home-filter'),
              onPressed: _showFilters,
              icon: const Icon(Icons.tune, size: 13),
              label: const Text('필터'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: Size.zero,
                textStyle: const TextStyle(
                  fontSize: 10,
                  fontFamily: 'NotoSansKR',
                ),
                side: const BorderSide(color: SodamStyle.border),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // 기능: 기존 장바구니 버튼·Key·이동 동작을 필터 오른쪽에서 사용한다.
          IconButton.outlined(
            key: const Key('home-cart'),
            tooltip: '장바구니',
            onPressed: _showCart,
            icon: const Icon(Icons.shopping_bag_outlined, size: 20),
            style: IconButton.styleFrom(
              fixedSize: const Size(44, 44),
              foregroundColor: SodamStyle.ink,
              side: const BorderSide(color: SodamStyle.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(7),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBannerIndicator() {
    return Center(
      child: Container(
        width: 16,
        height: 3,
        decoration: BoxDecoration(
          color: SodamStyle.green,
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Widget _buildCategories() {
    final categories = ref.watch(homeProductCategoriesProvider);
    final filters = ref.watch(productFilterProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 1, 14, 0),
      child: Row(
        children: [
          for (final label in categories.take(5))
            HomeCategoryButton(
              key: ValueKey('category-$label'),
              label: label,
              icon: switch (label) {
                '전체' => Icons.grid_view_outlined,
                '스킨' => Icons.water_drop_outlined,
                '로션' => Icons.opacity_outlined,
                '크림' => Icons.spa_outlined,
                _ => Icons.eco_outlined,
              },
              selected: filters.category == label,
              onTap: () => ref
                  .read(productFilterProvider.notifier)
                  .selectCategory(label),
            ),
        ],
      ),
    );
  }

  Widget _buildProductCatalog() {
    final filters = ref.watch(productFilterProvider);
    final products = ref.watch(filteredStorageProductsProvider);
    final catalog = ref.watch(storageProductsProvider);
    final ratings = filters.sort == ProductSort.ratingHigh
        ? ref.watch(catalogProductRatingsProvider)
        : null;
    final ratingsReady =
        ratings == null ||
        (!ratings.isLoading && !ratings.hasError && ratings.hasValue);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: catalog.isLoading
          ? const Center(child: CircularProgressIndicator())
          : catalog.hasError
          ? Column(
              children: [
                Text(catalog.error.toString()),
                TextButton(
                  onPressed: () =>
                      ref.invalidate(customerStorageImagesProvider),
                  child: const Text('다시 시도'),
                ),
              ],
            )
          : !ratingsReady
          ? const SizedBox.shrink()
          : products.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('조건에 맞는 상품이 없어요.')),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final columns = customerProductColumns(
                  context,
                  constraints.maxWidth,
                );
                final height =
                    (constraints.maxWidth - (columns - 1) * 12) / columns;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: products.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 20,
                    mainAxisExtent: customerProductCardExtent(context, height),
                  ),
                  itemBuilder: (_, index) => KeyedSubtree(
                    key: ValueKey(products[index].cardKey),
                    child: StorageProductTile(
                      product: products[index],
                      photoHeight: height,
                      onTap: () {
                        final product = products[index];
                        final detail = product.detailProduct;
                        _showProduct(
                          HomeProductVariant(
                            product: detail,
                            option: detail.options.first,
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildSectionHeader(
    String title,
    String subtitle, {
    required Key actionKey,
    required VoidCallback onViewAll,
    bool featured = false,
  }) {
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
        ),
        SizedBox(height: featured ? 6 : 5),
        Text(subtitle, style: const TextStyle(fontSize: 10, color: homeMuted)),
      ],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: featured
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          featured
              ? SizedBox(width: 158, child: heading)
              : Expanded(child: heading),
          TextButton(
            key: actionKey,
            onPressed: onViewAll,
            child: featured
                ? const Row(
                    children: [
                      Text('전체 보기', style: TextStyle(fontSize: 10)),
                      SizedBox(width: 4),
                      Icon(Icons.chevron_right, size: 16),
                    ],
                  )
                : const Text('전체 보기'),
          ),
        ],
      ),
    );
  }

  Widget _bottomNavigation() {
    final count = ref
        .watch(cartHandlerProvider)
        .fold<int>(0, (total, item) => total + item.quantity);
    return buildCustomerNavigationBar(
      selectedIndex: 0,
      cartCount: count,
      keyPrefix: 'home-nav',
      onTap: _navigate,
    );
  }
}
