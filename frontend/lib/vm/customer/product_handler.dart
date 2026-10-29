import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:beauty_project/model/customer/cosmetic.dart';
import 'package:beauty_project/model/customer/home_product.dart';
import 'package:beauty_project/model/customer/review.dart';
import 'package:beauty_project/service/customer/customer_catalog_service.dart';
import 'customer_providers.dart';
import 'review_handler.dart';

final customerCatalogServiceProvider = Provider<CustomerCatalogService>(
  (ref) => CustomerCatalogService(
    client: ref.watch(customerHttpClientProvider),
    baseUrl: ref.watch(customerApiBaseUrlProvider),
  ),
);

class ProductHandler extends AsyncNotifier<List<Cosmetic>> {
  @override
  Future<List<Cosmetic>> build() =>
      ref.watch(customerCatalogServiceProvider).fetchProducts();

  Future<void> refreshProducts() async {
    if (state.isLoading) return;
    final service = ref.read(customerCatalogServiceProvider);
    state = const AsyncLoading();
    final result = await AsyncValue.guard(service.fetchProducts);
    if (ref.mounted) state = result;
  }
}

final productHandlerProvider =
    AsyncNotifierProvider<ProductHandler, List<Cosmetic>>(
      ProductHandler.new,
      retry: (_, _) => null,
    );

enum ProductSort { recommended, priceLow, priceHigh, ratingHigh }

const customerProductFilterCategories = ['전체', '스킨', '로션', '크림'];

bool matchesProductCategory(Cosmetic product, String category) {
  if (category == '전체') return true;
  // DB의 세부 분류가 있으면 우선 사용한다. 기존 '스킨케어' 같은 넓은
  // 분류만 있는 상품은 상품명에서 유형을 찾으며 DB 값은 바꾸지 않는다.
  String? typeOf(String value) => switch (value.trim().toLowerCase()) {
    '스킨' || '토너' || 'skin' || 'toner' => '스킨',
    '로션' || '에멀전' || 'lotion' || 'emulsion' => '로션',
    '크림' || 'cream' => '크림',
    _ => null,
  };
  if (!customerProductFilterCategories.contains(category)) {
    return product.category == category;
  }
  var type = typeOf(product.category);
  if (type == null) {
    final name = product.name.toLowerCase();
    // '스킨 로션'처럼 이름에 두 표현이 있으면 제형을 우선한다.
    if (RegExp(r'크림|\bcream\b').hasMatch(name)) {
      type = '크림';
    } else if (RegExp(r'로션|에멀전|\b(lotion|emulsion)\b').hasMatch(name)) {
      type = '로션';
    } else if (RegExp(r'토너|스킨(?!케어)|\b(toner|skin)\b').hasMatch(name)) {
      type = '스킨';
    }
  }
  return type == category;
}

class ProductFilter {
  const ProductFilter({
    this.query = '',
    this.category = '전체',
    this.inStockOnly = false,
    this.sort = ProductSort.recommended,
    this.minPrice,
    this.maxPrice,
  });
  final String query;
  final String category;
  final bool inStockOnly;
  final ProductSort sort;
  final double? minPrice;
  final double? maxPrice;
}

class ProductFilterHandler extends Notifier<ProductFilter> {
  @override
  ProductFilter build() => const ProductFilter();

  void search(String query) => state = ProductFilter(
    query: query,
    category: state.category,
    inStockOnly: state.inStockOnly,
    sort: state.sort,
    minPrice: state.minPrice,
    maxPrice: state.maxPrice,
  );
  void selectCategory(String category) => state = ProductFilter(
    query: state.query,
    category: category,
    inStockOnly: state.inStockOnly,
    sort: state.sort,
    minPrice: state.minPrice,
    maxPrice: state.maxPrice,
  );
  void apply({
    required bool inStockOnly,
    required ProductSort sort,
    double? minPrice,
    double? maxPrice,
  }) => state = ProductFilter(
    query: state.query,
    category: state.category,
    inStockOnly: inStockOnly,
    sort: sort,
    minPrice: minPrice,
    maxPrice: maxPrice,
  );
  void reset() => state = const ProductFilter();
}

final productFilterProvider =
    NotifierProvider<ProductFilterHandler, ProductFilter>(
      ProductFilterHandler.new,
    );

final filteredProductsProvider = Provider<List<Cosmetic>>((ref) {
  final products =
      ref.watch(productHandlerProvider).value ?? const <Cosmetic>[];
  final filter = ref.watch(productFilterProvider);
  return filterProducts(
    products,
    filter,
    ratings: filter.sort == ProductSort.ratingHigh
        ? ref.watch(catalogProductRatingsProvider).value
        : null,
  );
});

// 앱의 판매 목록은 서버의 실제 상품번호·용량·가격을 사용한다.
final homeCatalogProductsProvider = Provider<AsyncValue<List<HomeProduct>>>(
  (ref) => ref
      .watch(productHandlerProvider)
      .whenData((products) => products.map(HomeProduct.fromCatalog).toList()),
);

final homeProductCategoriesProvider = Provider<List<String>>(
  (ref) => customerProductFilterCategories,
);

final homeProductsProvider = Provider<List<HomeProduct>>((ref) {
  final filter = ref.watch(productFilterProvider);
  return filterProducts(
    ref.watch(homeCatalogProductsProvider).value ?? [],
    filter,
    ratings: filter.sort == ProductSort.ratingHigh
        ? ref.watch(catalogProductRatingsProvider).value
        : null,
  );
});

final homeProductVariantsProvider = Provider<List<HomeProductVariant>>((ref) {
  final variants = [
    for (final product
        in ref.watch(homeCatalogProductsProvider).value ?? <HomeProduct>[])
      for (final option in product.options)
        HomeProductVariant(product: product, option: option),
  ];
  final filter = ref.watch(productFilterProvider);
  return filterProducts(
    variants,
    filter,
    ratings: filter.sort == ProductSort.ratingHigh
        ? ref.watch(catalogProductRatingsProvider).value
        : null,
  );
});

List<T> filterProducts<T extends Cosmetic>(
  List<T> products,
  ProductFilter filter, {
  Map<String, ReviewStatistics>? ratings,
}) {
  final query = filter.query.trim().toLowerCase();
  final terms = query.split(RegExp(r'\s+')).where((term) => term.isNotEmpty);
  final filtered = products
      .where(
        (product) =>
            matchesProductCategory(product, filter.category) &&
            (!filter.inStockOnly || product.availableQuantity > 0) &&
            (filter.minPrice == null ||
                product.price != null && product.price! >= filter.minPrice!) &&
            (filter.maxPrice == null ||
                product.price != null && product.price! <= filter.maxPrice!) &&
            (terms.isEmpty ||
                terms.every(
                  (term) =>
                      '${product.name} ${product.brand} ${product.category} ${product.volume}'
                          .toLowerCase()
                          .contains(term),
                )),
      )
      .toList();
  if (filter.sort == ProductSort.ratingHigh && ratings != null) {
    final positions = {
      for (var i = 0; i < filtered.length; i++) filtered[i].id: i,
    };
    String baseId(T product) =>
        product is HomeProductVariant ? product.product.id : product.id;
    filtered.sort((a, b) {
      final first = ratings[baseId(a)];
      final second = ratings[baseId(b)];
      final score = (second?.average ?? 0).compareTo(first?.average ?? 0);
      if (score != 0) return score;
      final count = (second?.count ?? 0).compareTo(first?.count ?? 0);
      return count != 0 ? count : positions[a.id]!.compareTo(positions[b.id]!);
    });
  } else if (filter.sort == ProductSort.priceLow ||
      filter.sort == ProductSort.priceHigh) {
    filtered.sort((a, b) {
      if (a.price == null) return b.price == null ? 0 : 1;
      if (b.price == null) return -1;
      return filter.sort == ProductSort.priceLow
          ? a.price!.compareTo(b.price!)
          : b.price!.compareTo(a.price!);
    });
  }
  return filtered;
}
