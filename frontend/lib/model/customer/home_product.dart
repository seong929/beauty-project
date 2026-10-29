import 'cosmetic.dart';

// 상품 표시 모델. DB 상품은 실제 번호·용량·가격을 사용하며 예시 데이터는 별도로 보존한다.
class HomeProduct extends Cosmetic {
  const HomeProduct({
    required super.id,
    required super.name,
    required super.category,
    required double super.price,
    required this.imageAsset,
    this.isDatabaseProduct = false,
    this.hasKnownPrice = true,
    super.brand = '소담 셀렉션',
    super.volume = '',
    super.availableQuantity = 1,
    this.catalogOptions,
  });

  final String imageAsset;
  final bool isDatabaseProduct;
  final bool hasKnownPrice;
  final List<HomeProductOption>? catalogOptions;

  factory HomeProduct.fromCatalog(Cosmetic product) => HomeProduct(
    id: product.id,
    name: product.name,
    brand: product.brand,
    category: product.category,
    price: product.price ?? 0,
    volume: product.volume,
    availableQuantity: product.availableQuantity,
    imageAsset: '',
    isDatabaseProduct: true,
    hasKnownPrice: product.price != null,
    catalogOptions: [
      HomeProductOption(
        label: product.volume.isEmpty ? '용량 정보 없음' : product.volume,
        price: product.price ?? 0,
      ),
    ],
  );

  factory HomeProduct.unavailableCartProduct(Map<String, dynamic> row) =>
      HomeProduct(
        id: row['cosmetic_id'] as String,
        name: row['cosmetic_name']?.toString() ?? '판매 정보 확인 불가',
        brand: row['manufacturer_name']?.toString() ?? '',
        category: row['category_name']?.toString() ?? '',
        price: 0,
        imageAsset: '',
        isDatabaseProduct: true,
        hasKnownPrice: false,
        availableQuantity: 0,
        catalogOptions: const [
          HomeProductOption(label: '판매 정보 확인 불가', price: 0),
        ],
      );

  String get description => isDatabaseProduct
      ? '$brand의 $name입니다. 용량과 가격은 현재 등록된 판매 정보를 기준으로 표시합니다.'
      : '$name으로 매일의 뷰티 루틴을 가볍게 완성해 보세요. '
            '편안한 사용감과 산뜻한 마무리를 담은 소담의 예시 상품입니다.';

  List<HomeProductOption> get options =>
      catalogOptions ??
      [
        HomeProductOption(label: '30ml', price: price!),
        HomeProductOption(label: '50ml', price: price! + 6000),
        HomeProductOption(label: '100ml', price: price! * 2),
        HomeProductOption(label: '200ml', price: price! * 3),
      ];
}

class HomeProductOption {
  const HomeProductOption({required this.label, required this.price});
  final String label;
  final double price;
}

// 목록에서 용량을 선택한 결과. 장바구니에는 원래 상품과 해당 옵션을 전달한다.
class HomeProductVariant extends Cosmetic {
  HomeProductVariant({required this.product, required this.option})
    : super(
        id: '${product.id}:${option.label}',
        name: product.name,
        brand: product.brand,
        category: product.category,
        volume: option.label,
        price: product.hasKnownPrice ? option.price : null,
        availableQuantity: product.availableQuantity,
      );

  final HomeProduct product;
  final HomeProductOption option;
  String get imageAsset => product.imageAsset;
}

const _productDetails = <(String, int, String)>[
  ('데일리 보습 로션', 18900, '스킨케어'),
  ('베리어 밸런스 로션', 21900, '스킨케어'),
  ('카밍 허브 바디 로션', 15900, '헤어·바디'),
  ('프레시 수분 캡슐 로션', 24900, '스킨케어'),
  ('더마 모이스처 로션', 17900, '스킨케어'),
  ('아쿠아 클렌징 로션', 22900, '클렌징'),
  ('블랙 리페어 에멀전', 27900, '스킨케어'),
  ('마일드 보습 바디 로션', 16900, '헤어·바디'),
  ('윤빛 밸런싱 에멀전', 32900, '스킨케어'),
  ('데일리 선 로션', 29900, '선케어'),
  ('시카 카밍 토너', 19900, '스킨케어'),
  ('퓨어 워터 토너', 14900, '스킨케어'),
  ('해양 미네랄 토너', 16900, '스킨케어'),
  ('어성초 수딩 토너', 20900, '스킨케어'),
  ('히알 수분 토너', 21900, '스킨케어'),
  ('그린 밸런스 스킨', 17900, '스킨케어'),
  ('인텐시브 그린 토너', 24900, '스킨케어'),
  ('워터 에센스 토너', 19900, '스킨케어'),
  ('베리어 캡슐 토너', 26900, '스킨케어'),
  ('클리어 진정 토너', 22900, '스킨케어'),
  ('시카 리페어 크림', 21900, '스킨케어'),
  ('블랙 스네일 영양 크림', 28900, '스킨케어'),
  ('하이드로 수딩 크림', 24900, '스킨케어'),
  ('데일리 장벽 크림', 26900, '스킨케어'),
  ('더마 보습 크림', 19900, '스킨케어'),
  ('레드 카밍 크림', 22900, '스킨케어'),
  ('에센셜 밸런스 크림', 35900, '스킨케어'),
  ('리치 리페어 크림', 39900, '스킨케어'),
  ('프레스티지 영양 크림', 32900, '스킨케어'),
  ('오리지널 리페어 크림', 27900, '스킨케어'),
];

final List<HomeProduct> homePreviewProducts = List.unmodifiable([
  for (var index = 0; index < _productDetails.length; index++)
    HomeProduct(
      id: 'preview_${index + 1}',
      name: _productDetails[index].$1,
      price: _productDetails[index].$2.toDouble(),
      category: _productDetails[index].$3,
      imageAsset: 'images/화면 캡처${index + 1}.png',
    ),
]);
