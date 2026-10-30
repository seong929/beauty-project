import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beauty_project/model/customer/home_product.dart';
import 'cart_handler.dart';
import 'product_handler.dart';

class CheckoutStockIssue {
  const CheckoutStockIssue({
    required this.key,
    required this.name,
    required this.message,
  });
  final String key;
  final String name;
  final String message;
}

class CheckoutStockState {
  const CheckoutStockState({
    this.ready = false,
    this.error,
    this.products = const {},
    this.issues = const [],
    this.byItem = const {},
    this.requested = const {},
  });
  final bool ready;
  final String? error;
  final Map<String, HomeProduct> products;
  final List<CheckoutStockIssue> issues;
  final Map<String, CheckoutStockIssue> byItem;
  final Map<String, int> requested;
  bool get canPurchase => ready && issues.isEmpty;
  int? available(String id) =>
      ready ? products[id]?.availableQuantity ?? 0 : null;
}

final checkoutStockProvider = Provider<CheckoutStockState>((ref) {
  final items = ref.watch(cartHandlerProvider);
  if (items.isEmpty) return const CheckoutStockState(ready: true);
  final catalog = ref.watch(homeCatalogProductsProvider);
  if (catalog.isLoading) return const CheckoutStockState();
  if (catalog.hasError || !catalog.hasValue) {
    return const CheckoutStockState(error: '판매 재고를 확인하지 못했어요. 다시 조회해 주세요.');
  }
  final products = {for (final product in catalog.value!) product.id: product};
  final requested = <String, int>{};
  for (final item in items.where((item) => item.selected)) {
    requested.update(
      item.product.id,
      (quantity) => quantity + item.quantity,
      ifAbsent: () => item.quantity,
    );
  }
  final issues = <CheckoutStockIssue>[];
  final byItem = <String, CheckoutStockIssue>{};
  for (final item in items) {
    final product = products[item.product.id];
    final quantity = item.selected
        ? requested[item.product.id]!
        : item.quantity;
    final message = product == null
        ? '판매 중인 상품 정보를 확인할 수 없습니다.'
        : !product.hasKnownPrice
        ? '상품 가격을 확인할 수 없어 구매할 수 없습니다.'
        : product.availableQuantity <= 0
        ? '품절 · 재고 부족 (구매 가능 0개)'
        : quantity > product.availableQuantity
        ? '재고 부족 · 요청 $quantity개 / 구매 가능 ${product.availableQuantity}개'
        : null;
    if (message != null) {
      final issue = CheckoutStockIssue(
        key: item.key,
        name: item.product.name,
        message: message,
      );
      byItem[item.key] = issue;
      if (item.selected) issues.add(issue);
    }
  }
  return CheckoutStockState(
    ready: true,
    products: products,
    issues: issues,
    byItem: byItem,
    requested: requested,
  );
});

// 변경 내용(2026-10-30): 최신 판매 재고와 주문 수량을 비교한다. 같은 상품의 여러 행은 합산해 검사한다.
// 조회 실패·판매 중단·가격 미확인·재고 0·주문 수량 초과 시 결제를 차단한다.
