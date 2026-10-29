import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:beauty_project/model/customer/home_product.dart';
import 'package:beauty_project/vm/customer/customer_handler.dart';
import 'package:beauty_project/vm/customer/product_handler.dart';
import 'package:beauty_project/vm/customer/product_search_handler.dart';
import 'package:beauty_project/vm/customer/cart_handler.dart';
import 'package:beauty_project/vm/customer/review_handler.dart';
import 'home/home_widgets.dart';
import 'home/home_product_gallery.dart';
import 'login/customer_auth_widgets.dart';
import 'product/product_list.dart';
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
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CustomerProductListScreen()),
    );
    if (mounted) _search.text = ref.read(productFilterProvider).query;
  }

  void _showProfile() {
    showCustomerProductProfile(context, ref);
  }

  Future<void> _showFilters() async {
    final current = ref.read(productFilterProvider);
    var stockOnly = current.inStockOnly;
    var sort = current.sort;
    final apply = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => SafeArea(
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
                  value: stockOnly,
                  onChanged: (value) => update(() => stockOnly = value),
                ),
                DropdownButtonFormField<ProductSort>(
                  initialValue: sort,
                  decoration: const InputDecoration(labelText: '정렬'),
                  items: const [
                    DropdownMenuItem(
                      value: ProductSort.recommended,
                      child: Text('기본순'),
                    ),
                    DropdownMenuItem(
                      value: ProductSort.priceLow,
                      child: Text('낮은 가격순'),
                    ),
                    DropdownMenuItem(
                      value: ProductSort.priceHigh,
                      child: Text('높은 가격순'),
                    ),
                    DropdownMenuItem(
                      value: ProductSort.ratingHigh,
                      child: Text('별점 높은 순'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) update(() => sort = value);
                  },
                ),
                const SizedBox(height: 20),
                FilledButton(
                  key: const Key('apply-product-filters'),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('적용하기'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (apply == true && mounted) {
      ref
          .read(productFilterProvider.notifier)
          .apply(inStockOnly: stockOnly, sort: sort);
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
      appBar: AppBar(
        toolbarHeight: 64,
        automaticallyImplyLeading: false,
        title: const Text(
          '소담',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
          ),
        ),
        actions: [
          TextButton(
            key: const Key('home-cart'),
            onPressed: _showCart,
            child: const Text('장바구니', style: TextStyle(fontSize: 10)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: session.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('로그인 상태를 확인해 주세요.')),
        data: (customer) => customer == null
            ? const Center(child: Text('로그인이 필요합니다.'))
            : _buildHome(),
      ),
      bottomNavigationBar: session.value == null ? null : _bottomNavigation(),
    );
  }

  Widget _buildHome() {
    final filters = ref.watch(productFilterProvider);
    final products = ref.watch(homeProductVariantsProvider);
    final catalog = ref.watch(homeCatalogProductsProvider);
    final categories = ref.watch(homeProductCategoriesProvider);
    final ratings = filters.sort == ProductSort.ratingHigh
        ? ref.watch(catalogProductRatingsProvider)
        : null;
    final ratingsReady =
        ratings == null ||
        (!ratings.isLoading && !ratings.hasError && ratings.hasValue);
    return Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: 480,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(catalogProductRatingsProvider);
            await ref.read(productHandlerProvider.notifier).refreshProducts();
          },
          child: SingleChildScrollView(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  color: SodamStyle.field,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: const Text(
                    '오늘의 뷰티를 소담에서 만나보세요',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: SodamStyle.muted),
                  ),
                ),
                Padding(
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
                            onChanged: (value) => ref
                                .read(productFilterProvider.notifier)
                                .search(value),
                            textInputAction: TextInputAction.search,
                            onSubmitted: (_) => _openSearch(),
                            style: const TextStyle(fontSize: 12),
                            decoration: InputDecoration(
                              hintText: '오늘, 어떤 뷰티 고민이 있나요?',
                              hintStyle: const TextStyle(
                                fontSize: 12,
                                color: homeMuted,
                              ),
                              prefixIcon: const Icon(Icons.search, size: 18),
                              prefixIconConstraints: const BoxConstraints(
                                minWidth: 30,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              fillColor: const Color(0xFFF6F7F8),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(7),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(7),
                                borderSide: BorderSide.none,
                              ),
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
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: HomeHero(),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    width: 16,
                    height: 3,
                    decoration: BoxDecoration(
                      color: SodamStyle.green,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                Padding(
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
                ),
                const SizedBox(height: 28),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(
                        width: 158,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '오늘의 소담한 발견',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              '조용한 변화, 나에게 맞는 아름다움',
                              style: TextStyle(fontSize: 10, color: homeMuted),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        key: const Key('home-view-all-images'),
                        onPressed: () => showAllCustomerProductImages(context),
                        child: const Row(
                          children: [
                            Text('전체 보기', style: TextStyle(fontSize: 10)),
                            SizedBox(width: 4),
                            Icon(Icons.chevron_right, size: 16),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const HomeProductGallery(),
                const SizedBox(height: 32),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '지금 만나는 뷰티',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 5),
                            Text(
                              '등록된 상품의 가격과 용량입니다.',
                              style: TextStyle(fontSize: 10, color: homeMuted),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        key: const Key('home-view-all'),
                        onPressed: () {
                          _reset();
                          _openSearch();
                        },
                        child: const Text('전체 보기'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: ProductRatingSortStatus(),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: catalog.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : catalog.hasError
                      ? Column(
                          children: [
                            Text(catalog.error.toString()),
                            TextButton(
                              onPressed: () =>
                                  ref.invalidate(productHandlerProvider),
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
                                (constraints.maxWidth - (columns - 1) * 12) /
                                columns;
                            return GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: products.length,
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: columns,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 20,
                                    mainAxisExtent: customerProductCardExtent(
                                      context,
                                      height,
                                    ),
                                  ),
                              itemBuilder: (_, index) => KeyedSubtree(
                                key: ValueKey('product-${products[index].id}'),
                                child: ProductTile(
                                  product: products[index],
                                  photoHeight: height,
                                  onTap: () => _showProduct(products[index]),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _bottomNavigation() {
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
          height: 66,
          child: Row(
            children: [
              for (final (index, label, icon) in const [
                (0, '홈', Icons.home_outlined),
                (1, '검색', Icons.grid_view_outlined),
                (2, '장바구니', Icons.shopping_bag_outlined),
                (3, '내 정보', Icons.person_outline),
              ])
                Expanded(
                  child: Semantics(
                    selected: index == 0,
                    child: InkWell(
                      key: ValueKey('home-nav-$index'),
                      onTap: () => _navigate(index),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Badge(
                            isLabelVisible: index == 2 && count > 0,
                            label: Text('$count'),
                            child: Icon(
                              icon,
                              size: 21,
                              color: index == 0 ? SodamStyle.ink : homeMuted,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 9,
                              color: index == 0 ? SodamStyle.ink : homeMuted,
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
