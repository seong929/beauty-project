import 'cosmetic.dart';
import 'home_product.dart';
import 'storage_image.dart';

// 이미지 목록의 항목과 실제 판매 상품을 구분한다. 이미지 파일명을 DB 상품번호로 보내지 않는다.
class StorageProduct extends Cosmetic {
  StorageProduct({
    required this.image,
    required String type,
    this.linkedProduct,
  }) : super(
         id: linkedProduct?.id ?? 'storage:${image.objectName}',
         name: linkedProduct?.name ?? image.title,
         brand: linkedProduct?.brand ?? type,
         category: type,
         volume: linkedProduct?.options.first.label ?? _previewVolume(type),
         price: linkedProduct == null
             ? _previewPrice(image.title, type)
             : linkedProduct.hasKnownPrice
             ? linkedProduct.options.first.price
             : null,
         availableQuantity: linkedProduct?.availableQuantity ?? 0,
       );

  final CustomerStorageImage image;
  final HomeProduct? linkedProduct;
  bool get isTemporary => linkedProduct == null;

  HomeProduct get detailProduct => HomeProduct(
    id: id,
    name: name,
    category: category,
    brand: brand,
    price: price ?? 0,
    volume: volume,
    imageAsset: linkedProduct?.imageAsset ?? '',
    storageImage: image,
    isDatabaseProduct: linkedProduct?.isDatabaseProduct ?? false,
    hasKnownPrice: price != null,
    availableQuantity: linkedProduct?.availableQuantity ?? 0,
    catalogOptions: [HomeProductOption(label: volume, price: price ?? 0)],
  );

  String get cardKey => linkedProduct == null
      ? 'firebase-product-${image.objectName}'
      : 'product-${linkedProduct!.id}:${linkedProduct!.options.first.label}';
}

String _previewVolume(String type) => switch (type) {
  '스킨' => '200ml',
  '로션' => '150ml',
  _ => '50ml',
};

double _previewPrice(String name, String type) {
  final base = switch (type) {
    '스킨' => 15000,
    '로션' => 18000,
    _ => 22000,
  };
  final offset = name.codeUnits.fold<int>(0, (sum, unit) => sum + unit) % 8;
  return (base + offset * 1000 + 900).toDouble();
}

String? storageProductType(String name) {
  final value = name.toLowerCase();
  if (RegExp(
    r'선크림|썬크림|선로션|샴푸|틴트|클렌|테스트|sunscreen|shampoo|tint|cleanser',
  ).hasMatch(value)) {
    return null;
  }
  if (RegExp(r'크림|cream').hasMatch(value)) return '크림';
  if (RegExp(r'로션|에멀전|lotion|emulsion').hasMatch(value)) return '로션';
  if (RegExp(r'토너|스킨(?!케어)|toner|\bskin\b').hasMatch(value)) return '스킨';
  return null;
}

// 변경 내용(2026-10-30): Firebase에 있는 스킨·로션·크림 사진만 홈 상품 카드로 구성한다.
// 미연결 사진의 용량·가격은 일정한 임시 값이며 DB 구매 상품으로 취급하지 않는다.
