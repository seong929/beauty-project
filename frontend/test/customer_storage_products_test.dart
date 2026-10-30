import 'dart:convert';
import 'package:beauty_project/model/customer/customers.dart';
import 'package:beauty_project/model/customer/home_product.dart';
import 'package:beauty_project/model/customer/storage_image.dart';
import 'package:beauty_project/view/customer/home_screen.dart';
import 'package:beauty_project/view/customer/home/storage_product_image.dart';
import 'package:beauty_project/view/customer/product/product_cart_screen.dart';
import 'package:beauty_project/view/customer/product/product_list.dart';
import 'package:beauty_project/view/customer/product/product_widgets.dart';
import 'package:beauty_project/view/customer/mypage/mypage_screen.dart';
import 'package:beauty_project/vm/customer/cart_persistence_handler.dart';
import 'package:beauty_project/vm/customer/customer_providers.dart';
import 'package:beauty_project/vm/customer/customer_handler.dart';
import 'package:beauty_project/vm/customer/product_handler.dart';
import 'package:beauty_project/vm/customer/storage_image_handler.dart';
import 'package:beauty_project/vm/customer/storage_product_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'support/preview_catalog.dart';

const bucket = 'beauty-skin-20e94.firebasestorage.app';
const photos = [
  CustomerStorageImage(bucket: bucket, objectName: '1025 독도 토너.png'),
  CustomerStorageImage(bucket: bucket, objectName: '세라마이드 아토 로션.png'),
  CustomerStorageImage(bucket: bucket, objectName: '에스트라 아토베리어365 크림.png'),
];

class _SignedIn extends CustomerHandler {
  @override
  Customers? build() => const Customers(
    customerId: 'c1',
    loginId: 'sodam',
    name: '고객',
    email: '',
    phone: '',
    address: '',
  );
}

void main() {
  test(
    'Firebase cards contain only uploaded skin, lotion and cream products',
    () {
      final products = buildStorageProducts(
        [
          ...photos,
          const CustomerStorageImage(bucket: bucket, objectName: '샴푸.png'),
          const CustomerStorageImage(bucket: bucket, objectName: '데일리 틴트.png'),
          const CustomerStorageImage(bucket: bucket, objectName: '더마 선크림.png'),
          const CustomerStorageImage(
            bucket: bucket,
            objectName: 'cosmetics/missing/image',
          ),
        ],
        const [
          HomeProduct(
            id: 'tint',
            name: '데일리 틴트',
            category: '메이크업',
            price: 11900,
            imageAsset: '',
          ),
        ],
      );
      expect(products.map((p) => p.name), photos.map((p) => p.title));
      expect(products.map((p) => p.category), ['스킨', '로션', '크림']);
      expect(
        products.every(
          (p) =>
              p.price! > 0 &&
              p.volume.isNotEmpty &&
              p.isTemporary &&
              !p.detailProduct.isDatabaseProduct,
        ),
        isTrue,
      );
    },
  );

  test(
    'real SKU photos take priority and preserve real price, stock and ID',
    () {
      const actual = HomeProduct(
        id: 'sku1',
        name: '1025 독도 토너',
        category: '스킨케어',
        price: 25000,
        imageAsset: '',
        isDatabaseProduct: true,
        availableQuantity: 7,
        catalogOptions: [HomeProductOption(label: '200ml', price: 25000)],
      );
      const image = CustomerStorageImage(
        bucket: bucket,
        objectName: 'cosmetics/sku1/image',
      );
      final result = buildStorageProducts([...photos, image], [actual]);
      final linked = result.singleWhere((p) => p.id == 'sku1');
      expect(linked.image, image);
      expect(linked.linkedProduct, same(actual));
      expect(linked.price, 25000);
      expect(linked.volume, '200ml');
      expect(linked.availableQuantity, 7);
      expect(result.length, 3);
    },
  );

  test(
    'Firebase list remains visible when the sales API fails and category filtering works',
    () async {
      final container = ProviderContainer(
        overrides: [
          homeCatalogProductsProvider.overrideWithValue(
            AsyncError(StateError('offline'), StackTrace.current),
          ),
          customerStorageImagesProvider.overrideWith((ref) async => photos),
        ],
      );
      addTearDown(container.dispose);
      await container.read(customerStorageImagesProvider.future);
      expect(container.read(storageProductsProvider).value, hasLength(3));
      container.read(productFilterProvider.notifier).selectCategory('크림');
      expect(
        container.read(filteredStorageProductsProvider).single.name,
        photos.last.title,
      );
    },
  );

  testWidgets(
    'home renders temporary volume and price and opens a Firebase product detail without checkout',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final loaded = <String>[];
      final pixel = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGNgYGBgAAAABQABpfZFQAAAAABJRU5ErkJggg==',
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            customerHandlerProvider.overrideWith(_SignedIn.new),
            homeCatalogProductsProvider.overrideWithValue(
              const AsyncData([
                HomeProduct(
                  id: 'tint',
                  name: '데일리 틴트',
                  category: '메이크업',
                  price: 11900,
                  imageAsset: '',
                  isDatabaseProduct: true,
                ),
              ]),
            ),
            customerStorageImagesProvider.overrideWith((ref) async => photos),
            customerStorageImageLoaderProvider.overrideWithValue((url) {
              loaded.add(url);
              return MemoryImage(pixel);
            }),
          ],
          child: const MaterialApp(home: CustomerHomeScreen()),
        ),
      );
      await tester.pumpAndSettle();
      final card = find.byKey(
        ValueKey('firebase-product-${photos.first.objectName}'),
      );
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: card, matching: find.text(photos.first.title)),
        findsOneWidget,
      );
      expect(find.text('데일리 틴트'), findsNothing);
      expect(find.text('11,900원'), findsNothing);
      expect(loaded, contains(photos.first.downloadUri.toString()));
      expect(
        find.descendant(of: card, matching: find.byIcon(Icons.spa_outlined)),
        findsNothing,
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(CustomerHomeScreen)),
      );
      final first = container.read(filteredStorageProductsProvider).first;
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('product-detail-screen')), findsOneWidget);
      expect(find.text('용량 200ml'), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('detail-total'))).data,
        productPrice(first.price!),
      );
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('add-product-to-cart')))
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('home-nav-1')));
      await tester.pumpAndSettle();
      expect(find.text('3개의 상품'), findsOneWidget);
      expect(find.text('데일리 틴트'), findsNothing);
      final searchCard = find.byKey(
        ValueKey('search-product-${first.id}:${first.volume}'),
      );
      await tester.ensureVisible(searchCard);
      await tester.tap(searchCard);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('product-detail-screen')), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('detail-total'))).data,
        productPrice(first.price!),
      );
    },
  );

  testWidgets(
    'switching bottom tabs clears previous tabs and both back actions return home',
    (tester) async {
      final client = MockClient(
        (_) async => http.Response('{"results":[],"result":[]}', 200),
      );
      addTearDown(client.close);
      final pixel = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGNgYGBgAAAABQABpfZFQAAAAABJRU5ErkJggg==',
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            customerHandlerProvider.overrideWith(_SignedIn.new),
            homeCatalogProductsProvider.overrideWithValue(const AsyncData([])),
            customerStorageImagesProvider.overrideWith((ref) async => photos),
            customerStorageImageLoaderProvider.overrideWithValue(
              (_) => MemoryImage(pixel),
            ),
            customerHttpClientProvider.overrideWithValue(client),
            cartPersistenceProvider.overrideWith(PreviewCartPersistence.new),
          ],
          child: const MaterialApp(home: CustomerHomeScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('home-nav-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('product-nav-2')));
      await tester.pumpAndSettle();
      expect(find.byType(CustomerCartScreen), findsOneWidget);
      expect(
        find.byType(CustomerProductListScreen, skipOffstage: false),
        findsNothing,
      );
      await tester.tap(find.byKey(const Key('product-nav-3')));
      await tester.pumpAndSettle();
      expect(find.byType(CustomerMyPageScreen), findsOneWidget);
      expect(
        find.byType(CustomerCartScreen, skipOffstage: false),
        findsNothing,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('customer-home')), findsOneWidget);
      await tester.tap(find.byKey(const Key('home-nav-3')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('product-nav-1')));
      await tester.pumpAndSettle();
      expect(find.byType(CustomerProductListScreen), findsOneWidget);
      expect(
        find.byType(CustomerMyPageScreen, skipOffstage: false),
        findsNothing,
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('customer-home')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
