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
