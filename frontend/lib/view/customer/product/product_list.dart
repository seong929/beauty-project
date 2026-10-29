import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:beauty_project/vm/customer/product_handler.dart';
import 'package:beauty_project/vm/customer/product_search_handler.dart';
import 'package:beauty_project/vm/customer/review_handler.dart';
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

  Future<void> _filter() async {
    final current = ref.read(productFilterProvider);
    final formKey = GlobalKey<FormState>();
    final min = TextEditingController(
      text: current.minPrice?.toStringAsFixed(0) ?? '',
    );
    final max = TextEditingController(
      text: current.maxPrice?.toStringAsFixed(0) ?? '',
    );
    var category = customerProductFilterCategories.contains(current.category)
        ? current.category
        : '전체';
    var stockOnly = current.inStockOnly;
    const categories = customerProductFilterCategories;
    ModalRoute<bool>? sheetRoute;
    try {
      final applied = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) {
          sheetRoute = ModalRoute.of<bool>(context);
          return StatefulBuilder(
            builder: (context, update) => SafeArea(
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
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
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
                              selected: category == label,
                              onSelected: (_) => update(() => category = label),
                            ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const Text('가격 범위'),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              key: const Key('search-min-price'),
                              controller: min,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: const InputDecoration(
                                hintText: '최소 금액',
                                suffixText: '원',
                              ),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.all(12),
                            child: Text('~'),
                          ),
                          Expanded(
                            child: TextFormField(
                              key: const Key('search-max-price'),
                              controller: max,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: const InputDecoration(
                                hintText: '최대 금액',
                                suffixText: '원',
                              ),
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
                          ),
                        ],
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('구매 가능한 상품만'),
                        value: stockOnly,
                        onChanged: (value) => update(() => stockOnly = value),
                      ),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () => update(() {
                              category = '전체';
                              stockOnly = false;
                              min.clear();
                              max.clear();
                            }),
                            child: const Text('초기화'),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              key: const Key('search-apply-filters'),
                              onPressed: () {
                                if (formKey.currentState!.validate()) {
                                  Navigator.pop(context, true);
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
            ),
          );
        },
      );
      if (applied == true && mounted) {
        final filters = ref.read(productFilterProvider.notifier);
        filters.selectCategory(category);
        filters.apply(
          inStockOnly: stockOnly,
          sort: current.sort,
          minPrice: double.tryParse(min.text),
          maxPrice: double.tryParse(max.text),
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

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(productFilterProvider);
    final products = ref.watch(homeProductVariantsProvider);
    final catalog = ref.watch(homeCatalogProductsProvider);
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
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              key: const Key('product-search-input'),
                              controller: _query,
                              focusNode: _focus,
                              autofocus: widget.autofocus,
                              onChanged: (value) => ref
                                  .read(productFilterProvider.notifier)
                                  .search(value),
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                            ),
                            child: const Text('필터'),
                          ),
                        ],
                      ),
                      if (recent.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Text(
                              '최근 검색',
                              style: const TextStyle(
                                fontSize: 10,
                                color: SodamStyle.muted,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Wrap(
                                spacing: 6,
                                children: [
                                  for (final query in recent)
                                    ActionChip(
                                      label: Text(
                                        query,
                                        style: const TextStyle(fontSize: 10),
                                      ),
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
                                onPressed: () => ref
                                    .read(
                                      recentProductSearchesProvider.notifier,
                                    )
                                    .clear(),
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 14),
                      Container(
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
                            items: const [
                              DropdownMenuItem(
                                value: ProductSort.recommended,
                                child: Text('정렬 : 기본순'),
                              ),
                              DropdownMenuItem(
                                value: ProductSort.priceLow,
                                child: Text('정렬 : 낮은 가격순'),
                              ),
                              DropdownMenuItem(
                                value: ProductSort.priceHigh,
                                child: Text('정렬 : 높은 가격순'),
                              ),
                              DropdownMenuItem(
                                value: ProductSort.ratingHigh,
                                child: Text('정렬 : 별점 높은 순'),
                              ),
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
                      ),
                      const ProductRatingSortStatus(),
                      const SizedBox(height: 12),
                      Center(
                        child: Text(
                          '${products.length}개의 상품',
                          key: const Key('product-result-count'),
                          style: const TextStyle(
                            fontSize: 11,
                            color: SodamStyle.muted,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Center(
                        child: Text(
                          '등록된 상품의 가격과 용량입니다.',
                          style: TextStyle(
                            fontSize: 9,
                            color: SodamStyle.muted,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
              if (catalog.isLoading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (catalog.hasError)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(catalog.error.toString()),
                        TextButton(
                          onPressed: () =>
                              ref.invalidate(productHandlerProvider),
                          child: const Text('다시 시도'),
                        ),
                      ],
                    ),
                  ),
                )
              else if (!ratingsReady)
                const SliverToBoxAdapter(child: SizedBox.shrink())
              else if (products.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.search_off,
                          size: 36,
                          color: SodamStyle.muted,
                        ),
                        const SizedBox(height: 12),
                        const Text('조건에 맞는 상품이 없어요.'),
                        TextButton(
                          onPressed: () {
                            _query.clear();
                            ref.read(productFilterProvider.notifier).reset();
                          },
                          child: const Text('검색 조건 초기화'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverLayoutBuilder(
                    builder: (context, constraints) {
                      final columns = customerProductColumns(
                        context,
                        constraints.crossAxisExtent,
                      );
                      final height =
                          (constraints.crossAxisExtent - (columns - 1) * 12) /
                          columns;
                      return SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 20,
                          mainAxisExtent: customerProductCardExtent(
                            context,
                            height,
                          ),
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => ProductTile(
                            product: products[index],
                            photoHeight: height,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CustomerProductDetailScreen(
                                  product: products[index].product,
                                  option: products[index].option,
                                  fromSearch: true,
                                ),
                              ),
                            ),
                          ),
                          childCount: products.length,
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
