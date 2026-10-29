import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beauty_project/model/customer/home_product.dart';
import 'product_handler.dart';

class RecentProductSearches extends Notifier<List<String>> {
  @override
  List<String> build() => const [];

  void add(String query) {
    final value = query.trim();
    if (value.isEmpty) return;
    state = [value, ...state.where((item) => item != value)].take(5).toList();
  }

  void clear() => state = const [];
}

final recentProductSearchesProvider =
    NotifierProvider<RecentProductSearches, List<String>>(
      RecentProductSearches.new,
    );

class FavoriteProducts extends Notifier<Set<String>> {
  final _savedProducts = <String, HomeProduct>{};
  Map<String, HomeProduct> get snapshots => Map.unmodifiable(_savedProducts);

  @override
  Set<String> build() {
    _savedProducts.clear();
    ref.listen(homeCatalogProductsProvider, (_, next) {
      for (final product in next.value ?? <HomeProduct>[]) {
        if (state.contains(product.id)) _savedProducts[product.id] = product;
      }
    });
    return const {};
  }

  void toggle(String id, {HomeProduct? product}) {
    if (state.contains(id)) {
      _savedProducts.remove(id);
      state = {...state}..remove(id);
      return;
    }
    final live = ref
        .read(homeCatalogProductsProvider)
        .value
        ?.where((entry) => entry.id == id)
        .firstOrNull;
    final snapshot = live ?? product;
    if (snapshot?.id == id) _savedProducts[id] = snapshot!;
    state = {...state, id};
  }
}

final favoriteProductsProvider =
    NotifierProvider<FavoriteProducts, Set<String>>(FavoriteProducts.new);

class FavoriteProductEntry {
  const FavoriteProductEntry({
    required this.id,
    required this.product,
    required this.listed,
  });
  final String id;
  final HomeProduct? product;
  // null: 판매 목록을 조회 중이거나 조회에 실패하여 상태를 확정할 수 없음.
  final bool? listed;
  bool get soldOut => listed == true && (product?.availableQuantity ?? 0) <= 0;
  bool get canPurchase =>
      listed == true && product?.hasKnownPrice == true && !soldOut;
}

final favoriteProductEntriesProvider = Provider<List<FavoriteProductEntry>>((
  ref,
) {
  final ids = ref.watch(favoriteProductsProvider);
  final catalog = ref.watch(homeCatalogProductsProvider);
  final snapshots = ref.read(favoriteProductsProvider.notifier).snapshots;
  final products = {
    for (final product in catalog.value ?? <HomeProduct>[]) product.id: product,
  };
  final confirmed = catalog.hasValue && !catalog.hasError && !catalog.isLoading;
  return [
    for (final id in ids)
      FavoriteProductEntry(
        id: id,
        product: products[id] ?? snapshots[id],
        listed: confirmed ? products.containsKey(id) : null,
      ),
  ];
});
