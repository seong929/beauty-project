// 기능: 선택 옵션·수량·금액을 가진 장바구니 행.
// 데이터 모델 계층: Riverpod 의존성을 넣지 않고 데이터와 변환·계산만 제공한다.

import 'home_product.dart';

// 장바구니 표시용 행. 고객·상품 관계는 서버에 저장하고 수량·선택 상태는 앱에서 관리한다.
class CustomerCartItem {
  const CustomerCartItem({
    required this.product,
    required this.option,
    required this.quantity,
    this.selected = true,
  });
  final HomeProduct product;
  final HomeProductOption option;
  final int quantity;
  final bool selected;
  String get key => '${product.id}:${option.label}';
  double get totalPrice => option.price * quantity;

  /// Function: 원본을 수정하지 않고 바뀐 값만 반영한 새 상태를 반환한다.
  CustomerCartItem copyWith({
    HomeProductOption? option,
    int? quantity,
    bool? selected,
  }) => CustomerCartItem(
    product: product,
    option: option ?? this.option,
    quantity: quantity ?? this.quantity,
    selected: selected ?? this.selected,
  );
}
