import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:beauty_project/model/customer/cosmetic.dart';
import 'package:beauty_project/model/customer/customers.dart';
import 'package:beauty_project/model/customer/home_product.dart';
import 'package:beauty_project/service/customer/customer_order_service.dart';
import 'package:beauty_project/view/customer/login/customer_auth_widgets.dart';
import 'package:beauty_project/view/customer/mypage/mypage_screen.dart';
import 'package:beauty_project/view/customer/order/check_screen.dart';
import 'package:beauty_project/vm/customer/cart_handler.dart';
import 'package:beauty_project/vm/customer/customer_handler.dart';
import 'package:beauty_project/vm/customer/customer_providers.dart';
import 'package:beauty_project/vm/customer/order_handler.dart';
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
    customerId: 'cus_1',
    loginId: 'sodam',
    name: '김소담',
    email: 'sodam@example.com',
    phone: '01012345678',
    address: '서울시 마포구 월드컵북로 21 301호',
    pointsBalance: 1200,
  );
}

final _product = HomeProduct.fromCatalog(
  const Cosmetic(
    id: 'sku_1',
    name: '수분 진정 세럼',
    brand: '소담',
    category: '스킨케어',
    volume: '50ml',
    price: 28000,
    availableQuantity: 10,
  ),
);
final _other = HomeProduct.fromCatalog(
  const Cosmetic(
    id: 'sku_2',
    name: '수분 크림',
    brand: '소담',
    category: '스킨케어',
    volume: '100ml',
    price: 20000,
    availableQuantity: 10,
  ),
);

http.Response _json(Object data, [int status = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(data)),
  status,
  headers: {'content-type': 'application/json'},
);

Map<String, dynamic> _paid() => {
  'result': 'OK',
  'order_id': 'ord_1',
  'customer_id': 'cus_1',
  'order_status': 'PAID',
  'shipping_address': '서울시 마포구 월드컵북로 21 301호', 'total_amount': 60000,
  // 한 상품이 재고 배치 두 개로 나뉜 실제 서버 응답 형태.
  'items': [
    for (var i = 1; i <= 2; i++)
      {
        'order_item_id': 'ord_1_$i',
        'cosmetic_id': 'sku_1',
        'cosmetic_name': '수분 진정 세럼',
        'quantity': 1,
        'unit_price': 30000,
      },
  ],
};

List<Map<String, dynamic>> _history() => [
  for (var i = 1; i <= 2; i++)
    {
      'order_id': 'ord_1',
      'customer_id': 'cus_1',
      'order_status': 'PAID',
      'shipping_address': '서울시 마포구 월드컵북로 21 301호',
      'order_date': '2026-10-29T12:00:00',
      'order_total_amount': '60000.00',
      'order_item_id': 'ord_1_$i',
      'cosmetic_id': 'sku_1',
      'product_name': '수분 진정 세럼',
      'quantity': 1,
      'unit_price': '30000.00',
    },
];

void _seed(ProviderContainer container) {
  final cart = container.read(cartHandlerProvider.notifier);
  cart.add(_product, _product.options.first, 2);
  cart.add(_other, _other.options.first, 1);
  cart.select('${_other.id}:${_other.options.first.label}', false);
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

  ProviderContainer container(http.Client client) {
    final result = ProviderContainer(
      overrides: [
        customerHandlerProvider.overrideWith(_Customer.new),
        customerHttpClientProvider.overrideWithValue(client),
      ],
    );
    addTearDown(result.dispose);
    _seed(result);
    return result;
  }

  test(
    'payment submits real IDs and quantity; receipt uses server prices and preserves unchecked cart',
    () async {
      final scope = container(
        MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/orders_pay');
          expect(jsonDecode(request.body), {
            'customer_id': 'cus_1',
            'shipping_address': '서울시 마포구 월드컵북로 21 301호',
            'items': [
              {'cosmetic_id': 'sku_1', 'quantity': 2, 'sale_option': 'NORMAL'},
            ],
          });
          return _json(_paid());
        }),
      );
      final receipt = await scope.read(customerPaymentProvider.notifier).pay();
      expect(receipt!.total, 60000);
      expect(receipt.quantity, 2);
      expect(scope.read(cartHandlerProvider).single.product.id, 'sku_2');
    },
  );

  test('a pending request is submitted only once', () async {
    final pending = Completer<http.Response>();
    var writes = 0;
    final scope = container(
      MockClient((_) {
        writes++;
        return pending.future;
      }),
    );
    final handler = scope.read(customerPaymentProvider.notifier);
    final first = handler.pay();
    await Future<void>.delayed(Duration.zero);
    expect(scope.read(customerPaymentProvider).isLoading, isTrue);
    expect(await handler.pay(), isNull);
    expect(writes, 1);
    pending.complete(_json(_paid()));
    expect((await first)!.id, 'ord_1');
  });

  test('stock rejection keeps the cart and does not report success', () async {
    final scope = container(
      MockClient((_) async => _json({'detail': '재고가 부족합니다.'}, 409)),
    );
    expect(await scope.read(customerPaymentProvider.notifier).pay(), isNull);
    expect(scope.read(cartHandlerProvider), hasLength(2));
    expect(scope.read(customerPaymentProvider).error.toString(), '재고가 부족합니다.');
    expect(
      scope.read(customerPaymentProvider.notifier).reviewRequired,
      isFalse,
    );
  });

  test(
    'uncertain server result blocks resubmission and keeps cart entries',
    () async {
      var writes = 0;
      final scope = container(
        MockClient((_) async {
          writes++;
          return _json({}, 500);
        }),
      );
      final handler = scope.read(customerPaymentProvider.notifier);
      expect(await handler.pay(), isNull);
      expect(
        scope.read(customerPaymentProvider).error,
        isA<OrderResultUncertain>(),
      );
      expect(handler.reviewRequired, isTrue);
      expect(await handler.pay(), isNull);
      expect(writes, 1);
      expect(scope.read(cartHandlerProvider), hasLength(2));
    },
  );

  test('logout discards a late payment result', () async {
    final pending = Completer<http.Response>();
    final scope = container(MockClient((_) => pending.future));
    final first = scope.read(customerPaymentProvider.notifier).pay();
    await Future<void>.delayed(Duration.zero);
    scope.read(customerHandlerProvider.notifier).logout();
    pending.complete(_json(_paid()));
    expect(await first, isNull);
    expect(scope.read(customerHandlerProvider).value, isNull);
  });

  test(
    'incorrect quantities in a successful response cannot show a completed receipt',
    () async {
      final invalid = _paid();
      invalid['items'] = [(invalid['items'] as List).first];
      final scope = container(MockClient((_) async => _json(invalid)));
      expect(await scope.read(customerPaymentProvider.notifier).pay(), isNull);
      expect(
        scope.read(customerPaymentProvider).error,
        isA<OrderResultUncertain>(),
      );
      expect(scope.read(cartHandlerProvider), hasLength(2));
    },
  );

  test(
    'history groups order rows and ignores duplicate joined item rows',
    () async {
      final rows = _history();
      final service = CustomerOrderService(
        baseUrl: Uri.parse('http://test/'),
        client: MockClient((request) async {
          expect(request.url.queryParameters['customer_id'], 'cus_1');
          return _json({
            'results': [...rows, rows.first],
          });
        }),
      );
      final orders = await service.fetch('cus_1');
      expect(orders, hasLength(1));
      expect(orders.single.quantity, 2);
      expect(orders.single.total, 60000);
      expect(orders.single.orderedAt!.day, 29);
    },
  );

  Future<ProviderContainer> pump(
    WidgetTester tester,
    http.Client client, {
    bool mypage = false,
    GlobalKey? capture,
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          customerHandlerProvider.overrideWith(_Customer.new),
          customerHttpClientProvider.overrideWithValue(client),
        ],
        child: RepaintBoundary(
          key: capture,
          child: MaterialApp(
            theme: SodamStyle.theme,
            debugShowCheckedModeBanner: false,
            home: mypage
                ? const CustomerMyPageScreen()
                : const CustomerCheckoutScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final result = ProviderScope.containerOf(
      tester.element(
        find.byType(mypage ? CustomerMyPageScreen : CustomerCheckoutScreen),
      ),
    );
    if (!mypage) {
      _seed(result);
      await tester.pumpAndSettle();
    }
    return result;
  }

  Future<void> pay(WidgetTester tester) async {
    await openCheckoutAgreement(tester);
    await agreeToCheckout(tester);
    await tapCheckoutControl(tester, 'checkout-payment');
  }

  testWidgets(
    'successful order opens completion and purchase history using the saved amount',
    (tester) async {
      final scope = await pump(
        tester,
        MockClient(
          (request) async => request.method == 'POST'
              ? _json(_paid())
              : _json({'results': _history()}),
        ),
      );
      await pay(tester);
      expect(find.byKey(const Key('customer-order-complete')), findsOneWidget);
      expect(find.text('주문이 완료되었어요'), findsOneWidget);
      expect(find.text('60,000원'), findsWidgets);
      expect(find.byKey(const Key('customer-checkout-screen')), findsNothing);
      expect(scope.read(cartHandlerProvider).single.product.id, 'sku_2');
      await tester.tap(find.byKey(const Key('complete-view-orders')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('order-ord_1')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('failed payment stays on checkout and displays the rejection', (
    tester,
  ) async {
    final scope = await pump(
      tester,
      MockClient((_) async => _json({'detail': '재고가 부족합니다.'}, 409)),
    );
    await pay(tester);
    expect(find.byKey(const Key('customer-order-complete')), findsNothing);
    expect(find.byKey(const Key('customer-checkout-screen')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('checkout-payment-error')));
    expect(find.text('재고가 부족합니다.'), findsOneWidget);
    expect(scope.read(cartHandlerProvider), hasLength(2));
  });

  testWidgets(
    'mypage shows live counts and saves personal information through the existing API',
    (tester) async {
      var writes = 0;
      final scope = await pump(
        tester,
        MockClient((request) async {
          if (request.method == 'PUT') {
            writes++;
            expect(request.url.path, '/customer_update');
            expect(request.url.queryParameters['customer_id'], 'cus_1');
            expect(request.bodyFields['customer_name'], '새소담');
            return _json({'result': 'OK'});
          }
          return _json({'results': _history()});
        }),
        mypage: true,
      );
      scope.read(favoriteProductsProvider.notifier).toggle('sku_1');
      await tester.pumpAndSettle();
      expect(find.text('1,200P'), findsOneWidget);
      expect(find.text('김소담님'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('mypage-edit-profile')));
      await tester.tap(find.byKey(const Key('mypage-edit-profile')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('profile-name')), '새소담');
      await tester.ensureVisible(find.byKey(const Key('profile-save')));
      await tester.tap(find.byKey(const Key('profile-save')));
      await tester.pumpAndSettle();
      expect(writes, 1);
      expect(scope.read(customerHandlerProvider).value!.name, '새소담');
      expect(find.text('새소담님'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'withdrawing requires confirmation and cancellation sends no request on a narrow phone',
    (tester) async {
      var deletes = 0;
      await pump(
        tester,
        MockClient((request) async {
          if (request.method == 'POST') deletes++;
          return _json({'results': []});
        }),
        mypage: true,
        size: const Size(320, 568),
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('mypage-withdraw')),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.drag(find.byType(ListView).first, const Offset(0, -150));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('mypage-withdraw')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('confirm-withdraw')), findsOneWidget);
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(deletes, 0);
      expect(tester.takeException(), isNull);
    },
  );

  test('profile save failure preserves the signed-in profile', () async {
    final scope = container(MockClient((_) async => _json({}, 500)));
    await expectLater(
      scope
          .read(customerHandlerProvider.notifier)
          .updateProfile(
            name: '저장 실패',
            email: 'sodam@example.com',
            phone: '01012345678',
            address: '서울시',
          ),
      throwsException,
    );
    expect(scope.read(customerHandlerProvider).value!.name, '김소담');
    expect(scope.read(customerHandlerProvider).value!.pointsBalance, 1200);
  });

  testWidgets(
    'confirmed withdrawal calls the original API once and returns to login',
    (tester) async {
      var writes = 0;
      final scope = await pump(
        tester,
        MockClient((request) async {
          if (request.method == 'POST') {
            writes++;
            expect(request.url.path, '/customer_delect');
            expect(request.bodyFields, {'customer_id': 'cus_1'});
            return _json({'result': 'OK'});
          }
          return _json({'results': []});
        }),
        mypage: true,
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('mypage-withdraw')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.drag(find.byType(ListView).first, const Offset(0, -150));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('mypage-withdraw')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm-withdraw')));
      await tester.pumpAndSettle();
      expect(writes, 1);
      expect(find.byKey(const Key('login-id')), findsOneWidget);
      expect(scope.read(customerHandlerProvider).value, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('capture completion and mypage when requested', (tester) async {
    final directory = Platform.environment['SODAM_PREVIEW_DIR'];
    if (directory == null) return;
    final key = GlobalKey();
    final client = MockClient(
      (request) async => request.method == 'POST'
          ? _json(_paid())
          : _json({'results': _history()}),
    );
    Future<void> capture(String name) async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final picture = await boundary.toImage(pixelRatio: 1);
        final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
        await Directory(directory).create(recursive: true);
        await File(
          '$directory/$name.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        picture.dispose();
      });
    }

    await pump(tester, client, capture: key);
    await pay(tester);
    await capture('order_complete');
    await tester.pumpWidget(const SizedBox.shrink());
    await pump(tester, client, mypage: true, capture: key);
    await capture('mypage');
  });
}
