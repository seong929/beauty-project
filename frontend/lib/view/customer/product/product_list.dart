// 기능: 상품 검색·필터 임시 선택·정렬·상세 이동.
// 표시 계층: ref.watch로 상태를 구독하고 사용자 동작은 Notifier·서비스에 전달한다.

import 'package:flutter/material.dart';
import 'package:beauty_project/model/customer/storage_product.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beauty_project/vm/customer/state/product_filter_draft_handler.dart';

import 'package:beauty_project/vm/customer/product_handler.dart';
import 'package:beauty_project/vm/customer/product_search_handler.dart';
import 'package:beauty_project/vm/customer/review_handler.dart';
import 'package:beauty_project/vm/customer/storage_product_handler.dart';
import 'package:beauty_project/vm/customer/storage_image_handler.dart';
import '../home/storage_product_tile.dart';
import '../login/customer_auth_widgets.dart';
import 'product_detail.dart';
import 'product_widgets.dart';

class CustomerProductListScreen extends ConsumerStatefulWidget {
  const CustomerProductListScreen({super.key, this.autofocus = false});
  final bool autofocus;

  @override
  ConsumerState<CustomerProductListScreen> createState() =>
      _CustomerProductListScreenState();
}

class _CustomerProductListScreenState
    extends ConsumerState<CustomerProductListScreen> {
  final _query = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _query.text = ref.read(productFilterProvider).query;
  }

  /// Function: 입력·포커스·스크롤 등 화면이 소유한 자원을 해제한다. Provider는 autoDispose 규칙을 따른다.
  @override
  void dispose() {
    _query.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _search(String query) {
    _query.value = TextEditingValue(
      text: query,
      selection: TextSelection.collapsed(offset: query.length),
    );
    ref.read(productFilterProvider.notifier).search(query);
    ref.read(recentProductSearchesProvider.notifier).add(query);
    _focus.unfocus();
  }

  /// Function: 필터 창에서 임시 선택을 받고 적용한 경우에만 실제 목록 조건을 바꾼다.
  Future<void> _filter() async {
    final current = ref.read(productFilterProvider);
    final formKey = GlobalKey<FormState>();
    final min = TextEditingController(
      text: current.minPrice?.toStringAsFixed(0) ?? '',
    );
    final max = TextEditingController(
      text: current.maxPrice?.toStringAsFixed(0) ?? '',
    );
    final draftProvider = productFilterDraftProvider((
      screen: Object(),
      initial: current,
    ));
    const categories = customerProductFilterCategories;
    ModalRoute<ProductFilter>? sheetRoute;
    Widget buildFilterContent(
      BuildContext context,
      WidgetRef sheetRef,
      Widget? child,
    ) {
      final draft = sheetRef.watch(draftProvider);
      final actions = sheetRef.read(draftProvider.notifier);
      return SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            4,
            20,
            MediaQuery.viewInsetsOf(context).bottom + 24,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '상품 필터',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 18),
                const Text('카테고리'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final label in categories)
                      ChoiceChip(
                        key: ValueKey('search-category-$label'),
                        label: Text(label),
                        selected: draft.category == label,
                        onSelected: (_) => actions.selectCategory(label),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                const Text('가격 범위'),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPriceField(
                      const Key('search-min-price'),
                      min,
                      '최소 금액',
                    ),
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('~'),
                    ),
                    _buildPriceField(
                      const Key('search-max-price'),
                      max,
                      '최대 금액',
                      validator: (value) {
                        final minimum = double.tryParse(min.text);
                        final maximum = double.tryParse(value ?? '');
                        return minimum != null &&
                                maximum != null &&
                                minimum > maximum
                            ? '최소 금액 이상으로 입력해 주세요.'
                            : null;
                      },
                    ),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('구매 가능한 상품만'),
                  value: draft.inStockOnly,
                  onChanged: actions.stockOnly,
                ),
                Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        actions.reset();
                        min.clear();
                        max.clear();
                      },
                      child: const Text('초기화'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        key: const Key('search-apply-filters'),
                        onPressed: () {
                          if (formKey.currentState!.validate()) {
                            Navigator.pop(
                              context,
                              sheetRef
                                  .read(draftProvider)
                                  .copyWith(
                                    minPrice: double.tryParse(min.text),
                                    maxPrice: double.tryParse(max.text),
                                    clearPrices: true,
                                  ),
                            );
                          }
                        },
                        child: const Text('적용하기'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    try {
      final applied = await showModalBottomSheet<ProductFilter>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) {
          sheetRoute = ModalRoute.of<ProductFilter>(context);
          return Consumer(builder: buildFilterContent);
        },
      );
      if (applied != null && mounted) {
        final filters = ref.read(productFilterProvider.notifier);
        filters.selectCategory(applied.category);
        filters.apply(
          inStockOnly: applied.inStockOnly,
          sort: applied.sort,
          minPrice: applied.minPrice,
          maxPrice: applied.maxPrice,
        );
      }
    } finally {
      // 닫힘 애니메이션 동안 입력 위젯이 컨트롤러를 계속 사용한다.
      void disposeFields() {
        min.dispose();
        max.dispose();
      }

      if (sheetRoute == null) {
        disposeFields();
      } else {
        sheetRoute!.completed.then((_) => disposeFields());
      }
    }
  }

  Widget _buildPriceField(
    Key fieldKey,
    TextEditingController controller,
    String hint, {
    FormFieldValidator<String>? validator,
  }) => Expanded(
    child: TextFormField(
      key: fieldKey,
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(hintText: hint, suffixText: '원'),
      validator: validator,
    ),
  );

  Widget _buildSearchHeader(
    ProductFilter filter,
    List<String> recent,
    int count,
  ) => SliverPadding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
    sliver: SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSearchInput(),
          if (recent.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildRecentSearches(recent),
          ],
          const SizedBox(height: 14),
          _buildSortSelector(filter),
          const ProductRatingSortStatus(),
          const SizedBox(height: 12),
          Center(
            child: Text(
              '$count개의 상품',
              key: const Key('product-result-count'),
              style: const TextStyle(fontSize: 11, color: SodamStyle.muted),
            ),
          ),
          const SizedBox(height: 4),
          const Center(
            child: Text(
              '스킨 · 로션 · 크림 · 임시 가격·용량 포함',
              style: TextStyle(fontSize: 9, color: SodamStyle.muted),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    ),
  );

  Widget _buildSearchInput() => Row(
    children: [
      Expanded(
        child: TextField(
          key: const Key('product-search-input'),
          controller: _query,
          focusNode: _focus,
          autofocus: widget.autofocus,
          onChanged: (value) =>
              ref.read(productFilterProvider.notifier).search(value),
          onSubmitted: _search,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: '상품 이름 검색',
            prefixIcon: const Icon(Icons.search, size: 19),
            suffixIcon: _query.text.isEmpty
                ? null
                : IconButton(
                    tooltip: '검색어 지우기',
                    onPressed: () => _search(''),
                    icon: const Icon(Icons.close, size: 18),
                  ),
          ),
        ),
      ),
      const SizedBox(width: 8),
      OutlinedButton(
        key: const Key('product-search-filter'),
        onPressed: _filter,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        child: const Text('필터'),
      ),
    ],
  );

  Widget _buildRecentSearches(List<String> recent) => Row(
    children: [
      Text(
        '최근 검색',
        style: const TextStyle(fontSize: 10, color: SodamStyle.muted),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Wrap(
          spacing: 6,
          children: [
            for (final query in recent)
              ActionChip(
                label: Text(query, style: const TextStyle(fontSize: 10)),
                visualDensity: VisualDensity.compact,
                onPressed: () => _search(query),
              ),
          ],
        ),
      ),
      if (recent.isNotEmpty)
        IconButton(
          tooltip: '검색 기록 지우기',
          icon: const Icon(Icons.close, size: 16),
          onPressed: () =>
              ref.read(recentProductSearchesProvider.notifier).clear(),
        ),
    ],
  );

  Widget _buildSortSelector(ProductFilter filter) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14),
    decoration: BoxDecoration(
      border: Border.all(color: SodamStyle.border),
      borderRadius: BorderRadius.circular(8),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<ProductSort>(
        key: const Key('product-search-sort'),
        value: filter.sort,
        isExpanded: true,
        style: const TextStyle(
          fontFamily: 'NotoSansKR',
          fontSize: 12,
          color: SodamStyle.ink,
        ),
        items: [
          for (final (value, label) in const [
            (ProductSort.recommended, '정렬 : 기본순'),
            (ProductSort.priceLow, '정렬 : 낮은 가격순'),
            (ProductSort.priceHigh, '정렬 : 높은 가격순'),
            (ProductSort.ratingHigh, '정렬 : 별점 높은 순'),
          ])
            DropdownMenuItem(value: value, child: Text(label)),
        ],
        onChanged: (value) {
          if (value != null) {
            ref
                .read(productFilterProvider.notifier)
                .apply(
                  inStockOnly: filter.inStockOnly,
                  sort: value,
                  minPrice: filter.minPrice,
                  maxPrice: filter.maxPrice,
                );
          }
        },
      ),
    ),
  );

  Widget _buildResultMessage(
    String message,
    String actionLabel,
    VoidCallback onAction, {
    bool empty = false,
  }) => SliverFillRemaining(
    hasScrollBody: !empty,
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (empty) ...[
            const Icon(Icons.search_off, size: 36, color: SodamStyle.muted),
            const SizedBox(height: 12),
          ],
          Text(message),
          TextButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    ),
  );

  void _openProduct(StorageProduct product) {
    final detail = product.detailProduct;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerProductDetailScreen(
          product: detail,
          option: detail.options.first,
          fromSearch: true,
        ),
      ),
    );
  }

  Widget _buildResults(
    List<StorageProduct> products,
    AsyncValue<List<StorageProduct>> catalog,
    bool ratingsReady,
  ) {
    if (catalog.isLoading) {
      return const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (catalog.hasError) {
      return _buildResultMessage(
        catalog.error.toString(),
        '다시 시도',
        () => ref.invalidate(customerStorageImagesProvider),
      );
    }
    if (!ratingsReady) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    if (products.isEmpty) {
      return _buildResultMessage('조건에 맞는 상품이 없어요.', '검색 조건 초기화', () {
        _query.clear();
        ref.read(productFilterProvider.notifier).reset();
      }, empty: true);
    }
    return _buildProductGrid(products);
  }

  Widget _buildProductGrid(List<StorageProduct> products) => SliverPadding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
    sliver: SliverLayoutBuilder(
      builder: (context, constraints) {
        final columns = customerProductColumns(
          context,
          constraints.crossAxisExtent,
        );
        final height =
            (constraints.crossAxisExtent - (columns - 1) * 12) / columns;
        return SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 20,
            mainAxisExtent: customerProductCardExtent(context, height),
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) => StorageProductTile(
              product: products[index],
              photoHeight: height,
              onTap: () => _openProduct(products[index]),
            ),
            childCount: products.length,
          ),
        );
      },
    ),
  );

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(productFilterProvider);
    final products = ref.watch(filteredStorageProductsProvider);
    final catalog = ref.watch(storageProductsProvider);
    final recent = ref.watch(recentProductSearchesProvider);
    final ratings = filter.sort == ProductSort.ratingHigh
        ? ref.watch(catalogProductRatingsProvider)
        : null;
    final ratingsReady =
        ratings == null ||
        (!ratings.isLoading && !ratings.hasError && ratings.hasValue);
    return Scaffold(
      key: const Key('product-search-screen'),
      appBar: AppBar(
        title: const Text('상품 검색·정렬·필터'),
        actions: [
          TextButton(
            onPressed: () => showCustomerPreviewCart(context),
            child: const Text('장바구니'),
          ),
        ],
      ),
      bottomNavigationBar: ProductNavigation(
        onSearch: () => _focus.requestFocus(),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: CustomScrollView(
            key: const Key('product-search-scroll'),
            slivers: [
              _buildSearchHeader(filter, recent, products.length),
              _buildResults(products, catalog, ratingsReady),
            ],
          ),
        ),
      ),
    );
  }
}
