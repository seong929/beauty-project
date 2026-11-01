// 기능: 장바구니 선택·옵션·수량의 불변 상태 갱신.
// 상태 계층: 변경은 Notifier/AsyncNotifier에서 발행하고 View는 watch, 동작은 read로 연결한다.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:beauty_project/model/customer/cart_item.dart';
import 'package:beauty_project/model/customer/home_product.dart';

// 화면 상태 관리. 서버 저장·조회·삭제는 CartPersistenceHandler에서 처리한다.
class CartHandler extends Notifier<List<CustomerCartItem>> {
  /// Function: Provider가 처음 구독될 때 초기 상태 또는 초기 조회 결과를 준비한다.
  @override
  List<CustomerCartItem> build() => const [];

  void add(HomeProduct product, HomeProductOption option, int quantity) {
    if (quantity < 1 ||
        quantity > 99 ||
        !product.options.any(
          (available) =>
              available.label == option.label &&
              available.price == option.price,
        )) {
      return;
    }
    final index = state.indexWhere(
      (item) =>
          item.product.id == product.id && item.option.label == option.label,
    );
    if (index < 0) {
      state = [
        ...state,
        CustomerCartItem(product: product, option: option, quantity: quantity),
      ];
    } else {
      final items = [...state];
      final old = items[index];
      items[index] = old.copyWith(
        quantity: (old.quantity + quantity).clamp(1, 99),
        selected: true,
      );
      state = items;
    }
  }

  void remove(String key) =>
      state = state.where((item) => item.key != key).toList();

  void select(String key, bool selected) => state = [
    for (final item in state)
      item.key == key
          ? item.copyWith(selected: selected && item.product.hasKnownPrice)
          : item,
  ];

  /// Function: 가격이 확인된 장바구니 상품의 선택 여부를 새 목록으로 반영한다.
  void selectAll(bool selected) => state = [
    for (final item in state)
      item.copyWith(selected: selected && item.product.hasKnownPrice),
  ];

  /// Function: 허용 수량 범위 안에서 해당 장바구니 행을 copyWith로 교체한다.
  void setQuantity(String key, int quantity) {
    if (quantity < 1 || quantity > 99) return;
    state = [
      for (final item in state)
        item.key == key ? item.copyWith(quantity: quantity) : item,
    ];
  }

  /// Function: 선택 옵션을 변경하고 같은 옵션 행이 있으면 수량을 합친다.
  bool changeOption(String key, HomeProductOption option) {
    final source = state.where((item) => item.key == key).firstOrNull;
    if (source == null ||
        !source.product.options.any(
          (size) => size.label == option.label && size.price == option.price,
        )) {
      return false;
    }
    final targetKey = '${source.product.id}:${option.label}';
    if (targetKey == key) return true;
    final target = state.where((item) => item.key == targetKey).firstOrNull;
    if (target == null) {
      state = [
        for (final item in state)
          item.key == key ? item.copyWith(option: option) : item,
      ];
    } else {
      if (source.quantity + target.quantity > 99) return false;
      state = [
        for (final item in state)
          if (item.key != key)
            item.key == targetKey
                ? item.copyWith(
                    quantity: source.quantity + target.quantity,
                    selected: source.selected || target.selected,
                  )
                : item,
      ];
    }
    return true;
  }

  void clear() => state = const [];

  /// Function: 서버 조회 결과를 읽기 전용 장바구니 목록으로 반영한다.
  void replaceFromServer(List<CustomerCartItem> items) =>
      state = List.unmodifiable(items);
}

final cartHandlerProvider =
    NotifierProvider<CartHandler, List<CustomerCartItem>>(CartHandler.new);

final selectedCartItemsProvider = Provider<List<CustomerCartItem>>(
  (ref) => ref
      .watch(cartHandlerProvider)
      .where((item) => item.selected && item.product.hasKnownPrice)
      .toList(),
);

final selectedCartTotalProvider = Provider<double>(
  (ref) => ref
      .watch(selectedCartItemsProvider)
      .fold(0, (total, item) => total + item.totalPrice),
);
