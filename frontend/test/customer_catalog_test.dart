import 'package:beauty_project/model/customer/cosmetic.dart';
import 'package:beauty_project/model/customer/home_product.dart';
import 'package:beauty_project/service/customer/customer_auth_service.dart';
import 'package:beauty_project/service/customer/customer_catalog_service.dart';
import 'package:beauty_project/vm/customer/product_handler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class ProductFixture extends ProductHandler {
  @override
  Future<List<Cosmetic>> build() async => const [
    Cosmetic(
      id: 'a',
      name: '에센스',
      brand: '소담',
      category: '스킨케어',
      price: 18000,
      availableQuantity: 3,
    ),
    Cosmetic(id: 'b', name: '선크림', brand: '소담', category: '선케어', price: 12000),
    Cosmetic(
      id: 'c',
      name: '토너',
      brand: '소담',
      category: '스킨케어',
      availableQuantity: 1,
    ),
  ];
}

void main() {
  test(
    'skin lotion cream filters use DB subcategories and product names without treating all skincare as skin',
    () {
      const products = [
        Cosmetic(
          id: 'toner',
          name: '수분 진정 토너',
          brand: '소담',
          category: '스킨케어',
          price: 10000,
          availableQuantity: 2,
        ),
        Cosmetic(
          id: 'lotion',
          name: '데일리 스킨 로션',
          brand: '소담',
          category: '스킨케어',
          price: 20000,
          availableQuantity: 1,
        ),
        Cosmetic(
          id: 'cream',
          name: '더마 크림',
          brand: '소담',
          category: '스킨케어',
          price: 30000,
        ),
        Cosmetic(
          id: 'other',
          name: '수분 세럼',
          brand: '소담',
          category: '스킨케어',
          price: 15000,
        ),
        Cosmetic(
          id: 'explicit',
          name: '시그니처 보습',
          brand: '소담',
          category: '로션',
          price: 40000,
        ),
      ];
      expect(customerProductFilterCategories, ['전체', '스킨', '로션', '크림']);
      expect(
        filterProducts(
          products,
          const ProductFilter(category: '스킨'),
        ).map((p) => p.id),
        ['toner'],
      );
      expect(
        filterProducts(
          products,
          const ProductFilter(category: '로션'),
        ).map((p) => p.id),
        ['lotion', 'explicit'],
      );
      expect(
        filterProducts(
          products,
          const ProductFilter(category: '크림'),
        ).map((p) => p.id),
        ['cream'],
      );
      expect(filterProducts(products, const ProductFilter()).length, 5);
      expect(
        filterProducts(products, const ProductFilter(category: '스킨케어')).length,
        4,
      );
      expect(
        filterProducts(
          products,
          const ProductFilter(
            category: '로션',
            minPrice: 15000,
            maxPrice: 30000,
            inStockOnly: true,
          ),
        ).map((p) => p.id),
        ['lotion'],
      );
    },
  );
  test(
    'volume and product search uses the price of the displayed capacity',
    () {
      final container = ProviderContainer(
        overrides: [
          homeCatalogProductsProvider.overrideWithValue(
            AsyncData(homePreviewProducts),
          ),
        ],
      );
      addTearDown(container.dispose);
      final filters = container.read(productFilterProvider.notifier);
      expect(container.read(homeProductVariantsProvider), hasLength(120));
      filters.search('데일리 보습 50ml');
      final product = container.read(homeProductVariantsProvider).single;
      expect(product.volume, '50ml');
      expect(product.price, 24900);
      filters.apply(
        inStockOnly: false,
        sort: ProductSort.recommended,
        minPrice: 24000,
        maxPrice: 25000,
      );
      expect(container.read(homeProductVariantsProvider).single.volume, '50ml');
      filters.apply(
        inStockOnly: false,
        sort: ProductSort.recommended,
        maxPrice: 20000,
      );
      expect(container.read(homeProductVariantsProvider), isEmpty);
    },
  );
  test(
    'price sorting leaves products with unknown prices at the end',
    () async {
      final container = ProviderContainer(
        overrides: [productHandlerProvider.overrideWith(ProductFixture.new)],
      );
      addTearDown(container.dispose);
      await container.read(productHandlerProvider.future);
      final filters = container.read(productFilterProvider.notifier);
      filters.apply(inStockOnly: false, sort: ProductSort.priceLow);
      expect(container.read(filteredProductsProvider).map((p) => p.id), [
        'b',
        'a',
        'c',
      ]);
      filters.apply(inStockOnly: false, sort: ProductSort.priceHigh);
      expect(container.read(filteredProductsProvider).map((p) => p.id), [
        'a',
        'b',
        'c',
      ]);
      filters.apply(inStockOnly: true, sort: ProductSort.priceHigh);
      expect(container.read(filteredProductsProvider).map((p) => p.id), [
        'a',
        'c',
      ]);
    },
  );

  test(
    'malformed catalog responses are readable errors instead of an empty catalog',
    () async {
      final client = MockClient(
        (_) async => http.Response('{"result": [null]}', 200),
      );
      addTearDown(client.close);
      final service = CustomerCatalogService(
        client: client,
        baseUrl: Uri.parse('http://localhost:8000/'),
      );
      await expectLater(
        service.fetchProducts(),
        throwsA(isA<CustomerAuthException>()),
      );
    },
  );
}
