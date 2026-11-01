// 기능: DB 상품의 가격·분류·판매 재고 데이터.
// 데이터 모델 계층: Riverpod 의존성을 넣지 않고 데이터와 변환·계산만 제공한다.

// 기존 고객 상품 조회 API 응답. 가격이 없는 상품은 임의의 금액을 표시하지 않는다.
class Cosmetic {
  const Cosmetic({
    required this.id,
    required this.name,
    required this.brand,
    required this.category,
    this.volume = '',
    this.price,
    this.availableQuantity = 0,
  });

  final String id;
  final String name;
  final String brand;
  final String category;
  final String volume;
  final double? price;
  final int availableQuantity;

  factory Cosmetic.fromJson(Map<String, dynamic> json) => Cosmetic(
    id: json['cosmetic_id']?.toString() ?? '',
    name: json['cosmetic_name']?.toString() ?? '',
    brand: json['manufacturer_name']?.toString() ?? '',
    category: json['category_name']?.toString() ?? '',
    volume: json['volume_text']?.toString() ?? '',
    price: double.tryParse(json['sale_price']?.toString() ?? ''),
    availableQuantity:
        int.tryParse(json['available_quantity']?.toString() ?? '') ?? 0,
  );
}
