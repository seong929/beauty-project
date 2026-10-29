import 'dart:io';
import 'dart:ui' as ui;

import 'package:beauty_project/model/customer/home_product.dart';
import 'package:beauty_project/view/customer/login/customer_auth_widgets.dart';
import 'package:beauty_project/view/customer/product/product_detail.dart';
import 'package:beauty_project/view/customer/product/product_list.dart';
import 'package:beauty_project/vm/customer/cart_handler.dart';
import 'package:beauty_project/vm/customer/cart_persistence_handler.dart';
import 'support/preview_catalog.dart';
import 'package:beauty_project/vm/customer/product_handler.dart';
import 'package:beauty_project/vm/customer/product_search_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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

  Future<ProviderContainer> pumpPage(
    WidgetTester tester, {
    Widget? page,
    Size size = const Size(390, 844),
    GlobalKey? capture,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeCatalogProductsProvider.overrideWithValue(
            AsyncData(homePreviewProducts),
          ),
          cartPersistenceProvider.overrideWith(PreviewCartPersistence.new),
        ],
        child: RepaintBoundary(
          key: capture,
          child: MaterialApp(
            theme: SodamStyle.theme,
            debugShowCheckedModeBanner: false,
            home: page ?? const CustomerProductListScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(
      tester.element(find.byType(Scaffold).first),
    );
  }

  testWidgets('search supports recent queries, empty results and reset', (
    tester,
  ) async {
    final container = await pumpPage(tester);
    expect(find.text('120개의 상품'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('product-search-input')),
      '데일리 보습',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text('4개의 상품'), findsOneWidget);
    expect(container.read(recentProductSearchesProvider), ['데일리 보습']);
    expect(
      find.byKey(const Key('search-product-preview_1:30ml')),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const Key('product-search-input')),
      '없는상품xyz',
    );
    await tester.pumpAndSettle();
    expect(find.text('조건에 맞는 상품이 없어요.'), findsOneWidget);
    await tester.tap(find.text('검색 조건 초기화'));
    await tester.pumpAndSettle();
    expect(find.text('120개의 상품'), findsOneWidget);
  });

  testWidgets('search sorts prices and validates filter ranges', (
    tester,
  ) async {
    final container = await pumpPage(tester);
    await tester.tap(find.byKey(const Key('product-search-sort')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('정렬 : 낮은 가격순').last);
    await tester.pumpAndSettle();
    expect(container.read(homeProductVariantsProvider).first.price, 14900);
    await tester.tap(find.byKey(const Key('product-search-filter')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('search-min-price')), '25000');
    await tester.enterText(find.byKey(const Key('search-max-price')), '20000');
    await tester.tap(find.byKey(const Key('search-apply-filters')));
    await tester.pumpAndSettle();
    expect(find.text('최소 금액 이상으로 입력해 주세요.'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('search-max-price')), '30000');
    await tester.tap(find.byKey(const Key('search-apply-filters')));
    await tester.pumpAndSettle();
    final results = container.read(homeProductVariantsProvider);
    expect(results, isNotEmpty);
    expect(
      results.every(
        (product) => product.price! >= 25000 && product.price! <= 30000,
      ),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'filter shows all skin lotion cream and applies and resets the category',
    (tester) async {
      final container = await pumpPage(tester);
      await tester.tap(find.byKey(const Key('product-search-filter')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widgetList<ChoiceChip>(find.byType(ChoiceChip))
            .map((chip) => (chip.label as Text).data),
        ['전체', '스킨', '로션', '크림'],
      );
      await tester.tap(find.byKey(const Key('search-category-크림')));
      await tester.tap(find.byKey(const Key('search-apply-filters')));
      await tester.pumpAndSettle();
      expect(container.read(productFilterProvider).category, '크림');
      expect(container.read(homeProductVariantsProvider), isNotEmpty);
      expect(
        container
            .read(homeProductVariantsProvider)
            .every((p) => p.name.contains('크림')),
        isTrue,
      );
      await tester.tap(find.byKey(const Key('product-search-filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('초기화'));
      await tester.tap(find.byKey(const Key('search-apply-filters')));
      await tester.pumpAndSettle();
      expect(container.read(productFilterProvider).category, '전체');
      expect(container.read(homeProductVariantsProvider), hasLength(120));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a 50ml card keeps its volume and price in detail and cart without a size selector',
    (tester) async {
      final container = await pumpPage(tester);
      final card = find.byKey(const Key('search-product-preview_1:50ml'));
      await tester.tap(
        find.descendant(
          of: card,
          matching: find.byKey(const Key('favorite-preview_1')),
        ),
      );
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('product-detail-screen')), findsOneWidget);
      expect(container.read(favoriteProductsProvider), contains('preview_1'));
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('add-product-to-cart')))
            .onPressed,
        isNotNull,
      );
      expect(find.text('용량 50ml'), findsOneWidget);
      expect(find.byKey(const Key('product-option-1')), findsNothing);
      expect(find.text('원하는 용량을 선택해 주세요.'), findsNothing);
      await tester.ensureVisible(find.byKey(const Key('quantity-increase')));
      await tester.tap(find.byKey(const Key('quantity-increase')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const Key('detail-total'))).data,
        '49,800원',
      );
      await tester.tap(find.byKey(const Key('add-product-to-cart')));
      await tester.pumpAndSettle();
      final item = container.read(cartHandlerProvider).single;
      expect(item.option.label, '50ml');
      expect(item.quantity, 2);
      expect(item.totalPrice, 49800);
      await tester.tap(find.byKey(const Key('product-nav-2')));
      await tester.pumpAndSettle();
      expect(find.text('합계 49,800원'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('detail and filtering fit a narrow phone', (tester) async {
    await pumpPage(
      tester,
      size: const Size(320, 568),
      page: CustomerProductDetailScreen(
        product: homePreviewProducts.first,
        option: homePreviewProducts.first.options[3],
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('용량 200ml'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('quantity-increase')));
    await tester.tap(find.byKey(const Key('quantity-increase')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('product-nav-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('product-search-screen')), findsOneWidget);
    await tester.tap(find.byKey(const Key('product-search-filter')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'buy button opens existing checkout with only the current product selected',
    (tester) async {
      final container = await pumpPage(
        tester,
        page: CustomerProductDetailScreen(product: homePreviewProducts.first),
      );
      container
          .read(cartHandlerProvider.notifier)
          .add(homePreviewProducts[1], homePreviewProducts[1].options.first, 1);
      await tester.tap(find.byKey(const Key('buy-product-now')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('checkout-step-0')), findsOneWidget);
      expect(
        container.read(selectedCartItemsProvider).single.product.id,
        homePreviewProducts.first.id,
      );
      expect(container.read(cartHandlerProvider), hasLength(2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'snackbar cart action still opens after the detail page is replaced',
    (tester) async {
      await pumpPage(
        tester,
        page: CustomerProductDetailScreen(product: homePreviewProducts.first),
      );
      await tester.tap(find.byKey(const Key('add-product-to-cart')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('product-nav-1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('product-detail-screen')), findsNothing);
      expect(find.text('보기'), findsOneWidget);
      await tester.tap(find.text('보기'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('customer-cart-screen')), findsOneWidget);
      expect(find.text('합계 18,900원'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('capture product screens when preview output is configured', (
    tester,
  ) async {
    final directory = Platform.environment['SODAM_PREVIEW_DIR'];
    if (directory == null) return;
    final key = GlobalKey();
    await pumpPage(tester, capture: key);
    // 캡처에서는 비동기 이미지 디코딩이 끝난 프레임을 사용한다.
    await tester.runAsync(() async {
      final context = tester.element(find.byType(CustomerProductListScreen));
      for (final product in homePreviewProducts.take(3)) {
        await precacheImage(AssetImage(product.imageAsset), context);
      }
    });
    await tester.pumpAndSettle();
    Future<void> capture(String name) async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final picture = await boundary.toImage(pixelRatio: 1);
        final data = await picture.toByteData(format: ui.ImageByteFormat.png);
        await Directory(directory).create(recursive: true);
        await File(
          '$directory/$name.png',
        ).writeAsBytes(data!.buffer.asUint8List());
        picture.dispose();
      });
    }

    await capture('product-search');
    await tester.tap(find.byKey(const Key('search-product-preview_1:30ml')));
    await tester.pumpAndSettle();
    await capture('product-detail');
  });
}
