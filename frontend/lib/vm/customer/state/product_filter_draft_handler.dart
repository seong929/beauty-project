// 기능: 실제 목록과 분리한 필터 창의 임시 선택.
// 상태 계층: 변경은 Notifier/AsyncNotifier에서 발행하고 View는 watch, 동작은 read로 연결한다.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../product_handler.dart';

/// 필터 창의 임시 선택. 적용 버튼을 누르기 전에는 실제 상품 목록을 변경하지 않는다.
class ProductFilterDraftHandler extends Notifier<ProductFilter> {
  ProductFilterDraftHandler(this.initial);
  final ProductFilter initial;
  @override
  ProductFilter build() => initial.copyWith(
    category: customerProductFilterCategories.contains(initial.category)
        ? initial.category
        : '전체',
  );

  void selectCategory(String value) => state = state.copyWith(category: value);
  void stockOnly(bool value) => state = state.copyWith(inStockOnly: value);
  void sort(ProductSort value) => state = state.copyWith(sort: value);
  void reset() => state = const ProductFilter();
}

/// 열 때마다 독립 키를 사용하고 창을 닫으면 임시 선택을 폐기한다.
final productFilterDraftProvider = NotifierProvider.autoDispose
    .family<
      ProductFilterDraftHandler,
      ProductFilter,
      ({Object screen, ProductFilter initial})
    >((key) => ProductFilterDraftHandler(key.initial));
