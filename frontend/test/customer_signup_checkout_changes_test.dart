import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:beauty_project/model/customer/cart_item.dart';
import 'package:beauty_project/model/customer/customers.dart';
import 'package:beauty_project/model/customer/home_product.dart';
import 'package:beauty_project/view/customer/delivery/address_search_screen.dart';
import 'package:beauty_project/view/customer/login/customer_auth_widgets.dart';
import 'package:beauty_project/view/customer/login/customer_signup_screen.dart';
import 'package:beauty_project/view/customer/order/check_screen.dart';
import 'package:beauty_project/view/customer/product/product_cart_screen.dart';
import 'package:beauty_project/view/customer/product/product_detail.dart';
import 'package:beauty_project/vm/customer/auth/login_id_availability.dart';
import 'package:beauty_project/vm/customer/cart_handler.dart';
import 'package:beauty_project/vm/customer/checkout_stock_handler.dart';
import 'package:beauty_project/vm/customer/customer_handler.dart';
import 'package:beauty_project/vm/customer/customer_providers.dart';
import 'package:beauty_project/vm/customer/order_handler.dart';
import 'package:beauty_project/vm/customer/product_handler.dart';
import 'package:beauty_project/vm/customer/storage_image_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'support/preview_catalog.dart';
import 'package:beauty_project/vm/customer/cart_persistence_handler.dart';

http.Response jsonResponse(Object data, [int status = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(data)), status);
const product = HomeProduct(
  id: 'sku_1',
  name: '수분 토너',
  brand: '소담',
  category: '스킨',
  volume: '50ml',
  price: 10000,
  imageAsset: '',
  isDatabaseProduct: true,
  availableQuantity: 10,
  catalogOptions: [
    HomeProductOption(label: '50ml', price: 10000),
    HomeProductOption(label: '100ml', price: 15000),
  ],
);

class _Customer extends CustomerHandler {
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

class _Cart extends CartHandler {
  @override
  List<CustomerCartItem> build() => [
    CustomerCartItem(
      product: product,
      option: product.options.first,
      quantity: 2,
    ),
  ];
}

class _Shop {
  int stock = 3;
  int payments = 0;
  bool failCatalog = false;
  Future<http.Response> handle(http.Request request) async {
    if (request.url.path.endsWith('/customers_categories_search')) {
      if (failCatalog) return jsonResponse({}, 503);
      return jsonResponse({
        'result': [
          {
            'cosmetic_id': product.id,
            'cosmetic_name': product.name,
            'manufacturer_name': product.brand,
            'category_name': product.category,
            'volume_text': '50ml',
            'sale_price': 10000,
            'available_quantity': stock,
          },
        ],
      });
    }
    if (request.url.path.endsWith('/orders_pay')) {
      payments++;
      return jsonResponse({'detail': '테스트 결제 거절'}, 409);
    }
    return jsonResponse({'result': []});
  }
}

void main() {
  setUpAll(() async {
    await (FontLoader(
      'NotoSansKR',
    )..addFont(rootBundle.load('assets/fonts/NotoSansKR.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  test('edited login IDs discard delayed availability responses', () async {
    final pending = Completer<http.Response>();
    final client = MockClient(
      (request) async => request.url.queryParameters['login_id'] == 'first'
          ? pending.future
          : jsonResponse({
              'result': 'OK',
              'login_id': 'second',
              'available': false,
            }),
    );
    final container = ProviderContainer(
      overrides: [customerHttpClientProvider.overrideWithValue(client)],
    );
    addTearDown(container.dispose);
    addTearDown(client.close);
    final subscription = container.listen(
      loginIdAvailabilityProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);
    final notifier = container.read(loginIdAvailabilityProvider.notifier);
    final first = notifier.check('first');
    notifier.edit('second');
    pending.complete(
      jsonResponse({'result': 'OK', 'login_id': 'first', 'available': true}),
    );
    await first;
    expect(
      container.read(loginIdAvailabilityProvider).confirmed('second'),
      isFalse,
    );
    await notifier.check('second');
    expect(container.read(loginIdAvailabilityProvider).available, isFalse);
    notifier.edit('first');
    expect(
      container.read(loginIdAvailabilityProvider).confirmed('first'),
      isFalse,
    );
  });

  test('legacy birth year is not retained or sent by customer models', () {
    final customer = Customers.fromJson({
      'login_id': 'sodam',
      'birth_year': 1997,
    });
    expect(customer.toJson().containsKey('birth_year'), isFalse);
    expect(customer.toForm().containsKey('birth_year'), isFalse);
  });

  Future<void> tap(WidgetTester tester, Finder target) async {
    FocusManager.instance.primaryFocus?.unfocus();
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'signup checks ID, selects API address, and saves gender without birth year',
    (tester) async {
      Map<String, String>? submitted;
      var addressCalls = 0;
      final client = MockClient((request) async {
        if (request.method == 'GET') {
          return jsonResponse({
            'result': 'OK',
            'login_id': request.url.queryParameters['login_id'],
            'available': true,
          });
        }
        submitted = request.bodyFields;
        return jsonResponse({
          'result': 'OK',
          'customer_id': request.bodyFields['customer_id'],
        });
      });
      addTearDown(client.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            customerHttpClientProvider.overrideWithValue(client),
            addressSearchLauncherProvider.overrideWithValue((_) async {
              addressCalls++;
              return const PostalAddress(
                zonecode: '12345',
                address: '서울특별시 강남구',
              );
            }),
          ],
          child: MaterialApp(
            theme: SodamStyle.theme,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CustomerSignupScreen(),
                    ),
                  ),
                  child: const Text('가입 화면'),
                ),
              ),
            ),
          ),
        ),
      );
      await tap(tester, find.text('가입 화면'));
      expect(find.byKey(const Key('signup-birth-year')), findsNothing);
      await tester.enterText(find.byType(TextFormField).first, 'new_customer');
      await tap(tester, find.byKey(const Key('check-login-id')));
      expect(find.text('사용 가능한 아이디입니다.'), findsOneWidget);
      for (final entry in {
        'signup-name': '소담고객',
        'signup-password': 'secret123',
        'signup-confirmation': 'secret123',
      }.entries) {
        await tester.ensureVisible(find.byKey(Key(entry.key)));
        await tester.enterText(find.byKey(Key(entry.key)), entry.value);
      }
      await tap(tester, find.byKey(const Key('signup-search-address')));
      expect(addressCalls, 1);
      for (final entry in {'signup-address-detail': '101동 202호'}.entries) {
        await tester.ensureVisible(find.byKey(Key(entry.key)));
        await tester.enterText(find.byKey(Key(entry.key)), entry.value);
      }
      await tap(tester, find.byKey(const Key('signup-gender')));
      await tester.tap(find.text('여성').last);
      await tester.pumpAndSettle();
      for (final entry in {
        'signup-email': 'new@example.com',
        'signup-phone': '01012345678',
      }.entries) {
        await tester.ensureVisible(find.byKey(Key(entry.key)));
        await tester.enterText(find.byKey(Key(entry.key)), entry.value);
      }
      await tester.ensureVisible(find.byType(TextFormField).first);
      await tester.enterText(
        find.byType(TextFormField).first,
        'edited_customer',
      );
      await tap(tester, find.byKey(const Key('signup-submit')));
      expect(submitted, isNull);
      await tap(tester, find.byKey(const Key('check-login-id')));
      await tap(tester, find.byKey(const Key('signup-submit')));
      expect(submitted?['login_id'], 'edited_customer');
      expect(submitted!.containsKey('birth_year'), isFalse);
      expect(submitted?['gender'], 'F');
      expect(submitted?['address'], '(12345) 서울특별시 강남구 101동 202호');
      expect(find.byType(CustomerSignupScreen), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'profile saves gender and preserves it for address edits without sending birth year',
    () async {
      final requests = <Map<String, String>>[];
      final client = MockClient((request) async {
        requests.add(request.bodyFields);
        return jsonResponse({'result': 'OK'});
      });
      final container = ProviderContainer(
        overrides: [
          customerHandlerProvider.overrideWith(_Customer.new),
          customerHttpClientProvider.overrideWithValue(client),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(client.close);
      final handler = container.read(customerHandlerProvider.notifier);
      Future<void> save({bool demographics = false}) => handler.updateProfile(
        name: '소담고객',
        email: 'sodam@example.com',
        phone: '01012345678',
        address: '서울시 새 주소',
        gender: 'F',
        updateDemographics: demographics,
      );
      await save(demographics: true);
      expect(requests.last['gender'], 'F');
      await save();
      for (final request in requests) {
        expect(request.containsKey('birth_year'), isFalse);
        expect(request.containsKey('clear_birth_year'), isFalse);
      }
      expect(container.read(customerHandlerProvider).value!.gender, 'F');
    },
  );

  Future<ProviderContainer> shopContainer(_Shop shop) async {
    final client = MockClient(shop.handle);
    final container = ProviderContainer(
      overrides: [
        customerHttpClientProvider.overrideWithValue(client),
        customerHandlerProvider.overrideWith(_Customer.new),
        cartHandlerProvider.overrideWith(_Cart.new),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(client.close);
    await container.read(productHandlerProvider.future);
    container.read(cartHandlerProvider);
    return container;
  }

  test(
    'zero stock, missing sale product and excessive quantities block payment before POST',
    () async {
      for (final stock in [0, 1]) {
        final shop = _Shop()..stock = stock;
        final container = await shopContainer(shop);
        expect(container.read(checkoutStockProvider).canPurchase, isFalse);
        expect(
          container.read(checkoutStockProvider).issues.single.message,
          contains('재고 부족'),
        );
        expect(
          await container.read(customerPaymentProvider.notifier).pay(),
          isNull,
        );
        expect(shop.payments, 0);
      }
    },
  );

  test(
    'catalog failure and a stock drop at final confirmation never send a payment POST',
    () async {
      final shop = _Shop();
      final container = await shopContainer(shop);
      expect(container.read(checkoutStockProvider).canPurchase, isTrue);
      shop.stock = 1;
      expect(
        await container.read(customerPaymentProvider.notifier).pay(),
        isNull,
      );
      expect(shop.payments, 0);
      shop.stock = 10;
      shop.failCatalog = true;
      expect(
        await container.read(customerPaymentProvider.notifier).pay(),
        isNull,
      );
      expect(shop.payments, 0);
      expect(container.read(cartHandlerProvider).single.quantity, 2);
    },
  );

  test(
    'same SKU quantities are combined while unchecked unavailable products do not block',
    () async {
      final shop = _Shop();
      final container = await shopContainer(shop);
      container
          .read(cartHandlerProvider.notifier)
          .add(product, product.options.last, 2);
      expect(container.read(checkoutStockProvider).requested['sku_1'], 4);
      expect(container.read(checkoutStockProvider).canPurchase, isFalse);
      container.read(cartHandlerProvider.notifier).select('sku_1:100ml', false);
      expect(container.read(checkoutStockProvider).canPurchase, isTrue);
    },
  );

  testWidgets(
    'quantity controls exist in checkout only, obey stock limits, and update totals',
    (tester) async {
      final shop = _Shop();
      final client = MockClient(shop.handle);
      addTearDown(client.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            customerHttpClientProvider.overrideWithValue(client),
            customerHandlerProvider.overrideWith(_Customer.new),
            cartHandlerProvider.overrideWith(_Cart.new),
            customerStorageImagesProvider.overrideWith((ref) async => []),
            cartPersistenceProvider.overrideWith(PreviewCartPersistence.new),
          ],
          child: MaterialApp(
            theme: SodamStyle.theme,
            home: const CustomerCartScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('increase-sku_1:50ml')), findsNothing);
      await tap(tester, find.byKey(const Key('cart-go-checkout')));
      await tap(tester, find.byKey(const Key('checkout-increase-sku_1:50ml')));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(CustomerCheckoutScreen)),
      );
      expect(container.read(selectedCartTotalProvider), 30000);
      expect(container.read(cartHandlerProvider).single.quantity, 3);
      expect(
        tester
            .widget<IconButton>(
              find.byKey(const Key('checkout-increase-sku_1:50ml')),
            )
            .onPressed,
        isNull,
      );
      await tap(tester, find.byKey(const Key('checkout-decrease-sku_1:50ml')));
      expect(container.read(selectedCartTotalProvider), 20000);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('product detail has no favorites or quantity picker', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          customerStorageImagesProvider.overrideWith((ref) async => []),
        ],
        child: MaterialApp(
          theme: SodamStyle.theme,
          home: const CustomerProductDetailScreen(product: product),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.favorite_border), findsNothing);
    expect(find.byKey(const Key('quantity-increase')), findsNothing);
    expect(find.text('장바구니'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'signup and stock warnings fit a narrow phone with enlarged text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final boundary = GlobalKey();
      final shop = _Shop()..stock = 1;
      final client = MockClient(shop.handle);
      addTearDown(client.close);
      Future<void> capture(String name) async {
        final directory = Platform.environment['SODAM_PREVIEW_DIR'];
        if (directory == null) return;
        await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory(directory).create(recursive: true);
          await File(
            '$directory/$name.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      Widget app(Widget screen) => ProviderScope(
        overrides: [
          customerHandlerProvider.overrideWith(_Customer.new),
          customerHttpClientProvider.overrideWithValue(client),
          cartHandlerProvider.overrideWith(_Cart.new),
          customerStorageImagesProvider.overrideWith((ref) async => []),
        ],
        child: RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            theme: SodamStyle.theme,
            debugShowCheckedModeBanner: false,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(1.3)),
              child: child!,
            ),
            home: screen,
          ),
        ),
      );
      await tester.pumpWidget(app(const CustomerSignupScreen()));
      await tester.pumpAndSettle();
      await capture('signup-id-check');
      await tester.ensureVisible(find.byKey(const Key('signup-gender')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('signup-birth-year')), findsNothing);
      await capture('signup-demographics');
      await tester.pumpWidget(app(const CustomerCheckoutScreen()));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('checkout-stock-notice')), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('checkout-next')))
            .onPressed,
        isNull,
      );
      await capture('checkout-stock-shortage');
      await tester.scrollUntilVisible(
        find.byKey(const Key('checkout-decrease-sku_1:50ml')),
        180,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      await capture('checkout-quantity');
      expect(tester.takeException(), isNull);
    },
  );
}

// 변경 내용(2026-10-30): 가입 정보 실제 전송·주소 API·아이디 지연 응답·결제 수량·재고 차단·찜 제거를 검증한다.
