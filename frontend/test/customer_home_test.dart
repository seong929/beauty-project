import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:beauty_project/model/customer/customers.dart';
import 'package:beauty_project/model/customer/home_product.dart';
import 'package:beauty_project/vm/customer/cart_persistence_handler.dart';
import 'support/preview_catalog.dart';
import 'package:beauty_project/view/customer/home_screen.dart';
import 'package:beauty_project/view/customer/login/customer_auth_widgets.dart';
import 'package:beauty_project/vm/customer/customer_handler.dart';
import 'package:beauty_project/vm/customer/customer_providers.dart';
import 'package:beauty_project/vm/customer/product_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const products = [
  {
    'cosmetic_id': 'cos_1',
    'cosmetic_name': '수분 에센스',
    'manufacturer_name': '소담',
    'category_name': '스킨케어',
    'volume_text': '150ml',
    'sale_price': '18000',
    'available_quantity': 5,
  },
  {
    'cosmetic_id': 'cos_2',
    'cosmetic_name': '데일리 선크림',
    'manufacturer_name': '소담',
    'category_name': '선케어',
    'volume_text': '50ml',
    'sale_price': 12000,
    'available_quantity': 0,
  },
];

// 화면 검증용 인증 상태. 앱에는 이 고객이나 로그인 우회 코드를 포함하지 않는다.
class SignedInHandler extends CustomerHandler {
  @override
  Customers? build() => const Customers(
    customerId: 'cus_test',
    loginId: 'sodam',
    name: '소담고객',
    email: 'sodam@example.com',
    address: '서울시',
    phone: '01012345678',
  );
}

http.Response response(Object data, [int status = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(data)),
  status,
  headers: {'content-type': 'application/json'},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader(
      'NotoSansKR',
    )..addFont(rootBundle.load('assets/fonts/NotoSansKR.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  Future<ProviderContainer> pumpHome(
    WidgetTester tester, {
    http.Client? client,
    Size size = const Size(390, 844),
    GlobalKey? captureKey,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final httpClient =
        client ??
        MockClient((request) async {
          expect(request.url.path, '/customers_categories_search');
          expect(request.method, 'GET');
          return response({'result': products});
        });
    addTearDown(httpClient.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeCatalogProductsProvider.overrideWithValue(
            AsyncData(homePreviewProducts),
          ),
          cartPersistenceProvider.overrideWith(PreviewCartPersistence.new),
          customerHandlerProvider.overrideWith(SignedInHandler.new),
          customerHttpClientProvider.overrideWithValue(httpClient),
          customerApiBaseUrlProvider.overrideWithValue(
            Uri.parse('http://localhost:8000/'),
          ),
        ],
        child: RepaintBoundary(
          key: captureKey,
          child: MaterialApp(
            theme: SodamStyle.theme,
            debugShowCheckedModeBanner: false,
            home: const CustomerHomeScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(
      tester.element(find.byType(CustomerHomeScreen)),
    );
  }

  testWidgets(
    'home shows sample product photos, names and prices and supports search',
    (tester) async {
      final container = await pumpHome(tester);
      expect(find.byKey(const Key('home-hero')), findsOneWidget);
      await tester.enterText(find.byKey(const Key('home-search')), '데일리 보습');
      await tester.pumpAndSettle();
      expect(container.read(homeProductsProvider).single.id, 'preview_1');
      await tester.ensureVisible(
        find.byKey(const Key('product-preview_1:30ml')),
      );
      await tester.pumpAndSettle();
      expect(find.text('18,900원'), findsOneWidget);
      expect(find.byKey(const Key('product-preview_2:30ml')), findsNothing);
      expect(find.byIcon(Icons.broken_image_outlined), findsNothing);
      await tester.tap(find.byKey(const Key('product-preview_1:30ml')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('product-detail-screen')), findsOneWidget);
      expect(find.text('상품명·가격·옵션은 화면 구성을 위한 예시입니다.'), findsOneWidget);
    },
  );

  testWidgets(
    'category filters work and view all restores the 30 sample products',
    (tester) async {
      final container = await pumpHome(tester);
      expect(container.read(homeProductCategoriesProvider), [
        '전체',
        '스킨',
        '로션',
        '크림',
      ]);
      await tester.tap(find.byKey(const Key('category-크림')));
      await tester.pumpAndSettle();
      expect(container.read(homeProductsProvider), isNotEmpty);
      expect(
        container
            .read(homeProductsProvider)
            .every((product) => product.name.contains('크림')),
        isTrue,
      );
      await tester.tap(find.byKey(const Key('home-filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch));
      await tester.tap(find.byKey(const Key('apply-product-filters')));
      await tester.pumpAndSettle();
      expect(
        container
            .read(homeProductsProvider)
            .every((product) => product.name.contains('크림')),
        isTrue,
      );
      await tester.ensureVisible(find.byKey(const Key('home-view-all')));
      await tester.tap(find.byKey(const Key('home-view-all')));
      await tester.pumpAndSettle();
      expect(container.read(homeProductsProvider), hasLength(30));
    },
  );

  testWidgets(
    'sample products remain available without requesting the catalog API',
    (tester) async {
      var calls = 0;
      final container = await pumpHome(
        tester,
        client: MockClient((_) async {
          calls++;
          return response({}, 500);
        }),
      );
      await tester.ensureVisible(
        find.byKey(const Key('product-preview_1:30ml')),
      );
      await tester.pumpAndSettle();
      expect(calls, 0);
      expect(container.read(homeProductsProvider), hasLength(30));
      expect(find.byKey(const Key('product-preview_1:30ml')), findsOneWidget);
    },
  );

  testWidgets('home remains scrollable on a narrow phone and cart opens', (
    tester,
  ) async {
    await pumpHome(tester, size: const Size(320, 568));
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(
      find.byKey(const Key('product-preview_30:30ml')),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('home-nav-2')));
    await tester.pumpAndSettle();
    expect(find.text('장바구니가 비어 있어요.'), findsOneWidget);
  });

  testWidgets(
    'capture the home screen when a preview directory is configured',
    (tester) async {
      final destination = Platform.environment['SODAM_PREVIEW_DIR'];
      if (destination == null) return;
      final key = GlobalKey();
      await pumpHome(tester, captureKey: key);
      Future<void> capture(String filename) async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final picture = await boundary.toImage(pixelRatio: 1);
          final bytes = await picture.toByteData(
            format: ui.ImageByteFormat.png,
          );
          await Directory(destination).create(recursive: true);
          await File(
            '$destination/$filename.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          picture.dispose();
        });
      }

      await capture('home');
      await tester.ensureVisible(
        find.byKey(const Key('product-preview_1:30ml')),
      );
      await tester.pumpAndSettle();
      await capture('home-products');
    },
  );

  testWidgets(
    'the featured image gallery shows 10 images and supports full size viewing',
    (tester) async {
      await pumpHome(tester);
      final firstImage = find.byKey(const Key('uploaded-product-1'));
      await tester.ensureVisible(firstImage);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.broken_image_outlined), findsNothing);
      await tester.tap(firstImage);
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(find.text('상품 이미지 1 / 10'), findsOneWidget);
      expect(find.byIcon(Icons.broken_image_outlined), findsNothing);
      await tester.tap(find.byTooltip('이미지 닫기'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('home-view-all-images')));
      await tester.tap(find.byKey(const Key('home-view-all-images')));
      await tester.pumpAndSettle();
      expect(find.text('상품 이미지 10개'), findsOneWidget);
      final gallery = find.descendant(
        of: find.byKey(const Key('all-product-images')),
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('uploaded-product-10')),
        300,
        scrollable: gallery,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('uploaded-product-10')));
      await tester.pumpAndSettle();
      expect(find.text('상품 이미지 10 / 10'), findsOneWidget);
      expect(find.byIcon(Icons.broken_image_outlined), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
