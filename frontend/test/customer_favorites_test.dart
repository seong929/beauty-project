import 'dart:io';
import 'dart:ui' as ui;
import 'package:beauty_project/model/customer/customers.dart';
import 'package:beauty_project/model/customer/home_product.dart';
import 'package:beauty_project/view/customer/home_screen.dart';
import 'package:beauty_project/view/customer/login/customer_auth_widgets.dart';
import 'package:beauty_project/view/customer/mypage/favorite_list_screen.dart';
import 'package:beauty_project/vm/customer/customer_handler.dart';
import 'package:beauty_project/vm/customer/customer_providers.dart';
import 'package:beauty_project/vm/customer/product_handler.dart';
import 'package:beauty_project/vm/customer/product_search_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'support/checkout_steps.dart';

class _Customer extends CustomerHandler {
  @override
  Customers? build() => const Customers(
    customerId: 'cus_favorites',
    loginId: 'sodam',
    name: '소담고객',
    email: 'sodam@example.com',
    phone: '01012345678',
    address: '서울시',
  );
}

final _products = [
  for (var i = 0; i < 3; i++)
    HomeProduct(
      id: ['sku_live', 'sku_stock', 'sku_missing'][i],
      name: ['수분 진정 세럼', '자동품의 테스트 - 재고 0', '클래식 버블 바디 미스트'][i],
      category: '스킨케어',
      brand: '소담',
      price: [28000.0, 25000.0, 21000.0][i],
      volume: i == 1 ? '용량 정보 없음' : '50ml',
      isDatabaseProduct: true,
      availableQuantity: i == 1 ? 0 : 10,
      imageAsset: homePreviewProducts[i].imageAsset,
      catalogOptions: [
        HomeProductOption(
          label: i == 1 ? '용량 정보 없음' : '50ml',
          price: [28000.0, 25000.0, 21000.0][i],
        ),
      ],
    ),
];

class _Catalog extends Notifier<AsyncValue<List<HomeProduct>>> {
  @override
  AsyncValue<List<HomeProduct>> build() => AsyncData(_products);
  void replace(List<HomeProduct> products) => state = AsyncData(products);
  void fail() => state = AsyncError(Exception('offline'), StackTrace.current);
}

final _catalog = NotifierProvider<_Catalog, AsyncValue<List<HomeProduct>>>(
  _Catalog.new,
);

void main() {
  setUpAll(() async {
    await (FontLoader(
      'NotoSansKR',
    )..addFont(rootBundle.load('assets/fonts/NotoSansKR.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  Future<ProviderContainer> pump(
    WidgetTester tester, {
    bool home = false,
    Size size = const Size(390, 844),
    double scale = 1,
    GlobalKey? capture,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          customerHandlerProvider.overrideWith(_Customer.new),
          homeCatalogProductsProvider.overrideWith(
            (ref) => ref.watch(_catalog),
          ),
          customerHttpClientProvider.overrideWithValue(
            MockClient((_) async => http.Response('{"results":[]}', 200)),
          ),
        ],
        child: RepaintBoundary(
          key: capture,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: SodamStyle.theme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: home
                ? const CustomerHomeScreen()
                : const CustomerFavoriteListScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(
      tester.element(
        find.byType(home ? CustomerHomeScreen : CustomerFavoriteListScreen),
      ),
    );
  }

  void seed(ProviderContainer scope) {
    for (final product in _products) {
      scope
          .read(favoriteProductsProvider.notifier)
          .toggle(product.id, product: product);
    }
  }

  testWidgets(
    'home top-right favorite toggles without opening detail and syncs with mypage',
    (tester) async {
      final scope = await pump(tester, home: true);
      final card = find.byKey(const Key('product-sku_live:50ml'));
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      final heart = find.descendant(
        of: card,
        matching: find.byKey(const Key('favorite-sku_live')),
      );
      expect(
        tester.getCenter(heart).dx,
        greaterThan(tester.getCenter(card).dx),
      );
      expect(
        tester.getCenter(heart).dy,
        lessThan(tester.getTopLeft(card).dy + 45),
      );
      await tester.tap(heart);
      await tester.pumpAndSettle();
      expect(scope.read(favoriteProductsProvider), contains('sku_live'));
      expect(find.byKey(const Key('product-detail-screen')), findsNothing);
      await tapCheckoutControl(tester, 'home-nav-3');
      await tapCheckoutControl(tester, 'mypage-favorites');
      expect(find.text('1개'), findsOneWidget);
      await tapCheckoutControl(tester, 'favorite-sku_live');
      expect(scope.read(favoriteProductsProvider), isEmpty);
      expect(find.text('찜한 상품이 없습니다.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'sold-out and missing catalog entries keep their metadata and can be removed',
    (tester) async {
      final scope = await pump(tester);
      seed(scope);
      scope.read(_catalog.notifier).replace(_products.take(2).toList());
      await tester.pumpAndSettle();
      expect(find.text('3개'), findsOneWidget);
      expect(find.text('클래식 버블 바디 미스트'), findsOneWidget);
      expect(scope.read(favoriteProductEntriesProvider).last.listed, isFalse);
      expect(
        tester
            .widget<InkWell>(
              find.byKey(const Key('favorite-product-sku_stock')),
            )
            .onTap,
        isNull,
      );
      expect(
        tester
            .widget<InkWell>(
              find.byKey(const Key('favorite-product-sku_missing')),
            )
            .onTap,
        isNull,
      );
      await tapCheckoutControl(tester, 'favorite-sku_missing');
      expect(scope.read(favoriteProductsProvider), hasLength(2));
      expect(
        scope
            .read(favoriteProductsProvider.notifier)
            .snapshots
            .containsKey('sku_missing'),
        isFalse,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'network failure keeps favorites and does not claim they were removed from sale',
    (tester) async {
      final scope = await pump(tester);
      seed(scope);
      await tester.pumpAndSettle();
      scope.read(_catalog.notifier).fail();
      await tester.pumpAndSettle();
      expect(find.text('3개'), findsOneWidget);
      expect(
        scope
            .read(favoriteProductEntriesProvider)
            .every((entry) => entry.listed == null),
        isTrue,
      );
      expect(
        scope.read(favoriteProductsProvider.notifier).snapshots,
        hasLength(3),
      );
      await tapCheckoutControl(tester, 'favorite-sku_live');
      expect(scope.read(favoriteProductsProvider), hasLength(2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('home sold-out cards fit a narrow screen with larger text', (
    tester,
  ) async {
    await pump(tester, home: true, size: const Size(320, 568), scale: 1.3);
    await tester.ensureVisible(
      find.byKey(const Key('product-sku_stock:용량 정보 없음')),
    );
    await tester.pumpAndSettle();
    expect(find.text('품절'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('favorites paginate and retain an accurate total', (
    tester,
  ) async {
    final scope = await pump(tester, size: const Size(320, 568));
    final products = [
      for (var i = 0; i < 12; i++)
        HomeProduct(
          id: 'page_$i',
          name: '찜 상품 $i',
          category: '스킨케어',
          price: 15000,
          imageAsset: '',
          availableQuantity: 5,
          volume: '50ml',
          isDatabaseProduct: true,
        ),
    ];
    scope.read(_catalog.notifier).replace(products);
    for (final product in products) {
      scope
          .read(favoriteProductsProvider.notifier)
          .toggle(product.id, product: product);
    }
    await tester.pumpAndSettle();
    await tapCheckoutControl(tester, 'favorite-next-page');
    expect(find.text('12개'), findsOneWidget);
    expect(find.byKey(const Key('favorite-product-page_10')), findsOneWidget);
    expect(find.byKey(const Key('favorite-product-page_0')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('logout clears favorite IDs and cached metadata', (tester) async {
    final scope = await pump(tester);
    seed(scope);
    await tester.pumpAndSettle();
    scope.read(customerHandlerProvider.notifier).logout();
    await tester.pumpAndSettle();
    expect(scope.read(favoriteProductsProvider), isEmpty);
    expect(scope.read(favoriteProductsProvider.notifier).snapshots, isEmpty);
    expect(find.text('찜한 상품이 없습니다.'), findsOneWidget);
  });

  testWidgets('capture favorites when requested', (tester) async {
    final directory = Platform.environment['SODAM_PREVIEW_DIR'];
    if (directory == null) return;
    final key = GlobalKey();
    final scope = await pump(tester, capture: key);
    seed(scope);
    scope.read(_catalog.notifier).replace(_products.take(2).toList());
    await tester.pumpAndSettle();
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final picture = await boundary.toImage(pixelRatio: 1);
      final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
      await Directory(directory).create(recursive: true);
      await File(
        '$directory/favorites.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      picture.dispose();
    });
  });
}
