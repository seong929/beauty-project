import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:beauty_project/model/customer/customers.dart';
import 'package:beauty_project/model/customer/home_product.dart';
import 'package:beauty_project/model/customer/order.dart';
import 'package:beauty_project/service/customer/customer_auth_service.dart';
import 'package:beauty_project/service/customer/customer_delivery_service.dart';
import 'package:beauty_project/service/customer/customer_order_service.dart';
import 'package:beauty_project/service/customer/customer_return_service.dart';
import 'package:beauty_project/view/customer/login/customer_auth_widgets.dart';
import 'package:beauty_project/view/customer/mypage/mypage_screen.dart';
import 'package:beauty_project/view/customer/order/check_screen.dart';
import 'package:beauty_project/view/customer/order/list_screen.dart';
import 'package:beauty_project/view/customer/return/return_request_screen.dart';
import 'package:beauty_project/vm/customer/cart_handler.dart';
import 'package:beauty_project/vm/customer/customer_handler.dart';
import 'package:beauty_project/vm/customer/customer_providers.dart';
import 'package:beauty_project/vm/customer/product_handler.dart';
import 'package:beauty_project/vm/customer/return_handler.dart';
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
    customerId: 'cus_history',
    loginId: 'sodam',
    name: '소담고객',
    email: 'sodam@example.com',
    phone: '01012345678',
    address: '서울 마포구 월드컵북로 21 301호',
  );
}

http.Response _json(Object data, [int status = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(data)),
  status,
  headers: {'content-type': 'application/json'},
);

class _Server {
  final requests = <http.Request>[];
  final returns = <Map<String, dynamic>>[];
  int? failure;
  int get writes =>
      requests.where((request) => request.method == 'POST').length;
  final products = [
    for (var i = 1; i <= 3; i++)
      HomeProduct(
        id: 'sku_$i',
        name: ['수분 세럼', '데일리 선크림', '세라마이드 크림'][i - 1],
        category: '스킨케어',
        price: 99999,
        imageAsset: homePreviewProducts[i - 1].imageAsset,
        isDatabaseProduct: true,
        brand: '소담',
        volume: '50ml',
        availableQuantity: 10,
      ),
  ];
  List<Map<String, dynamic>> get orderRows => [
    for (var i = 1; i <= 3; i++)
      {
        'order_id': 'ord_$i',
        'customer_id': 'cus_history',
        'order_item_id': 'ord_${i}_1',
        'order_status': ['PAID', 'SHIPPED', 'DELIVERED'][i - 1],
        'shipping_address': '서울 마포구 월드컵북로 21 301호',
        'order_date': '2026-10-20T10:00:00',
        'cosmetic_id': 'sku_$i',
        'product_name': products[i - 1].name,
        'quantity': 2,
        'unit_price': 14000,
        'order_total_amount': 28000,
        'sale_option': 'NORMAL',
        'delivery_id': i == 1 ? null : 'dlv_$i',
      },
  ];
  final deliveries = [
    for (var i = 1; i <= 3; i++)
      <String, dynamic>{
        'order_id': 'ord_$i',
        'customer_id': 'cus_history',
        'order_status': ['PAID', 'SHIPPED', 'DELIVERED'][i - 1],
        'shipping_address': '서울 마포구 월드컵북로 21 301호',
        'delivery_id': i == 1 ? null : 'dlv_$i',
        'delivery_status': [null, 'IN_TRANSIT', 'DELIVERED'][i - 1],
        'ordered_at': '2026-10-20T10:00:00',
        'shipped_at': i > 1 ? '2026-10-21T13:30:00' : null,
        'arrived_at': i == 3 ? '2026-10-23T16:40:00' : null,
        'carrier_name': i > 1 ? '소담 배송' : null,
        'carrier_phone': i > 1 ? '0212345678' : null,
      },
  ];
  Map<String, dynamic> returnRow({int quantity = 1}) => {
    'return_id': 'ret_ord_3_1_1',
    'order_item_id': 'ord_3_1',
    'customer_id': 'cus_history',
    'return_reason': '파손\n용기가 깨졌습니다.',
    'return_quantity': quantity,
    'requested_on': '2026-10-29',
    'return_status': 'REQUESTED',
    'refund_status': 'PENDING',
    'pickup_status': 'WAITING',
  };
  late final client = MockClient((request) async {
    requests.add(request);
    expect(request.url.path.startsWith('/admin'), isFalse);
    if (request.url.path == '/orders') return _json({'results': orderRows});
    if (request.url.path == '/customer_delivery_select') {
      expect(request.url.queryParameters['customer_id'], 'cus_history');
      return _json({
        'result': deliveries
            .where(
              (row) =>
                  request.url.queryParameters['order_id'] == null ||
                  row['order_id'] == request.url.queryParameters['order_id'],
            )
            .toList(),
      });
    }
    if (request.url.path == '/return_requests') {
      if (request.method == 'POST') {
        if (failure != null) {
          return _json({'detail': '반품 가능한 수량을 초과했습니다.'}, failure!);
        }
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body.keys.toSet(), {
          'customer_id',
          'order_item_id',
          'return_reason',
          'return_quantity',
        });
        expect(body['customer_id'], 'cus_history');
        final row = {...returnRow(), ...body};
        returns.add(row);
        return _json(row, 201);
      }
      expect(request.url.queryParameters['customer_id'], 'cus_history');
      return _json({
        'result': returns
            .where(
              (row) =>
                  request.url.queryParameters['order_item_id'] == null ||
                  row['order_item_id'] ==
                      request.url.queryParameters['order_item_id'],
            )
            .toList(),
      });
    }
    return _json({'result': []});
  });
  Future<CustomerOrder> deliveredOrder() async => (await CustomerOrderService(
    client: client,
    baseUrl: Uri.parse('http://test/'),
  ).fetch('cus_history')).last;
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

  Future<ProviderContainer> pump(
    WidgetTester tester,
    _Server server, {
    Widget home = const CustomerOrderListScreen(),
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
          customerHandlerProvider.overrideWith(_Customer.new),
          customerHttpClientProvider.overrideWithValue(server.client),
          homeCatalogProductsProvider.overrideWithValue(
            AsyncData(server.products),
          ),
        ],
        child: RepaintBoundary(
          key: capture,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: SodamStyle.theme,
            home: home,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(
      tester.element(find.byType(home.runtimeType)),
    );
  }

  Future<void> fillReturn(WidgetTester tester) async {
    await tapCheckoutControl(tester, 'return-reason');
    await tester.tap(find.text('파손').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('return-detail')),
      '용기가 깨져 내용물이 새고 있습니다.',
    );
    await tester.pumpAndSettle();
    await tapCheckoutControl(tester, 'return-confirm');
  }

  test(
    'split shipment records retain dates and reject another customer or order',
    () async {
      final server = _Server();
      final service = CustomerDeliveryService(
        client: server.client,
        baseUrl: Uri.parse('http://test/'),
      );
      final rows = await service.fetchShipments('cus_history');
      expect(rows, hasLength(3));
      expect(rows[1].received, isFalse);
      expect(rows[1].shippedAt!.day, 21);
      expect(rows[2].received, isTrue);
      expect(rows[2].arrivedAt!.day, 23);
      final bad = CustomerDeliveryService(
        baseUrl: Uri.parse('http://test/'),
        client: MockClient(
          (_) async => _json({
            'result': [
              {...server.deliveries.first, 'customer_id': 'other'},
            ],
          }),
        ),
      );
      await expectLater(
        bad.fetchShipments('cus_history'),
        throwsA(isA<CustomerAuthException>()),
      );
    },
  );

  test(
    'return creation confirms an owned item without claiming approval or refund',
    () async {
      final server = _Server();
      final service = CustomerReturnService(
        client: server.client,
        baseUrl: Uri.parse('http://test/'),
      );
      final request = await service.create(
        customerId: 'cus_history',
        itemId: 'ord_3_1',
        reason: '파손\n용기가 깨졌습니다.',
        quantity: 1,
      );
      expect(request.status, 'REQUESTED');
      expect(request.approved, isFalse);
      expect(request.refundLabel, '환불 대기');
      expect(
        (await service.fetch('cus_history', itemId: 'ord_3_1')).single.id,
        request.id,
      );
    },
  );

  test(
    'uncertain return response blocks duplicate submissions and leaves status unconfirmed',
    () async {
      final server = _Server()..failure = 500;
      final order = await server.deliveredOrder();
      final container = ProviderContainer(
        overrides: [
          customerHandlerProvider.overrideWith(_Customer.new),
          customerHttpClientProvider.overrideWithValue(server.client),
        ],
      );
      addTearDown(container.dispose);
      final handler = container.read(customerReturnHandlerProvider.notifier);
      expect(
        await handler.submit(
          order: order,
          item: order.items.first,
          reason: '파손',
          quantity: 1,
        ),
        isNull,
      );
      expect(
        container.read(customerReturnHandlerProvider).error,
        isA<ReturnResultUncertain>(),
      );
      expect(
        await handler.submit(
          order: order,
          item: order.items.first,
          reason: '파손',
          quantity: 1,
        ),
        isNull,
      );
      expect(server.writes, 1);
    },
  );

  test(
    'pending and late return responses do not duplicate or update a logged-out session',
    () async {
      final server = _Server();
      final order = await server.deliveredOrder();
      final pending = Completer<http.Response>();
      var writes = 0;
      final container = ProviderContainer(
        overrides: [
          customerHandlerProvider.overrideWith(_Customer.new),
          customerHttpClientProvider.overrideWithValue(
            MockClient((_) {
              writes++;
              return pending.future;
            }),
          ),
        ],
      );
      addTearDown(container.dispose);
      final handler = container.read(customerReturnHandlerProvider.notifier);
      final first = handler.submit(
        order: order,
        item: order.items.first,
        reason: '파손\n용기가 깨졌습니다.',
        quantity: 1,
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        await handler.submit(
          order: order,
          item: order.items.first,
          reason: '파손',
          quantity: 1,
        ),
        isNull,
      );
      expect(writes, 1);
      container.read(customerHandlerProvider.notifier).logout();
      pending.complete(_json(server.returnRow(), 201));
      expect(await first, isNull);
    },
  );

  testWidgets('coupon sections are removed from both checkout steps', (
    tester,
  ) async {
    final server = _Server();
    final scope = await pump(
      tester,
      server,
      home: const CustomerCheckoutScreen(),
    );
    scope
        .read(cartHandlerProvider.notifier)
        .add(server.products.first, server.products.first.options.first, 1);
    await tester.pumpAndSettle();
    expect(find.textContaining('쿠폰'), findsNothing);
    await tapCheckoutControl(tester, 'checkout-next');
    expect(find.textContaining('쿠폰'), findsNothing);
    expect(find.text('결제 금액 확인'), findsOneWidget);
  });

  testWidgets(
    'mypage opens delivery filters and tracking refresh uses real arrival data',
    (tester) async {
      final server = _Server();
      await pump(tester, server, home: const CustomerMyPageScreen());
      await tapCheckoutControl(tester, 'mypage-delivery-status');
      expect(find.byKey(const Key('customer-delivery-list')), findsOneWidget);
      await tapCheckoutControl(tester, 'delivery-filter-배송 중');
      expect(find.byKey(const Key('delivery-dlv_2')), findsOneWidget);
      expect(find.byKey(const Key('delivery-dlv_3')), findsNothing);
      await tapCheckoutControl(tester, 'delivery-dlv_2');
      expect(
        find.byKey(const Key('customer-delivery-tracking')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Text>(find.byKey(const Key('delivery-current-status')))
            .data,
        '배송 중',
      );
      server.deliveries[1]['delivery_status'] = 'DELIVERED';
      server.deliveries[1]['arrived_at'] = '2026-10-29T15:45:00';
      await tapCheckoutControl(tester, 'delivery-refresh');
      expect(
        tester
            .widget<Text>(find.byKey(const Key('delivery-current-status')))
            .data,
        '수령 완료',
      );
      expect(find.text('2026-10-29 15:45'), findsWidgets);
      expect(server.writes, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'history search and status filtering open image details with historical prices',
    (tester) async {
      final server = _Server();
      await pump(tester, server);
      await tester.enterText(
        find.byKey(const Key('order-history-search')),
        '선크림',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('order-ord_2')), findsOneWidget);
      expect(find.byKey(const Key('order-ord_1')), findsNothing);
      await tester.enterText(find.byKey(const Key('order-history-search')), '');
      await tester.pumpAndSettle();
      await tapCheckoutControl(tester, 'order-history-filter');
      await tapCheckoutControl(tester, 'order-filter-DELIVERED');
      expect(find.byKey(const Key('order-ord_3')), findsOneWidget);
      await tapCheckoutControl(tester, 'order-detail-ord_3_1');
      expect(find.byKey(const Key('customer-order-detail')), findsOneWidget);
      expect(find.text('28,000원'), findsWidgets);
      expect(find.text('99,999원'), findsNothing);
      expect(find.byType(Image), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'return reason and consent are required, then a successful save opens the real result',
    (tester) async {
      final server = _Server();
      final order = await server.deliveredOrder();
      await pump(
        tester,
        server,
        home: CustomerReturnRequestScreen(
          order: order,
          item: order.items.first,
        ),
      );
      await tapCheckoutControl(tester, 'return-confirm');
      await tapCheckoutControl(tester, 'return-submit');
      expect(server.writes, 0);
      expect(find.text('상세 사유를 입력해 주세요.'), findsOneWidget);
      await fillReturn(tester);
      await tapCheckoutControl(tester, 'return-submit');
      expect(server.writes, 1);
      expect(find.byKey(const Key('customer-return-status')), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.byKey(const Key('return-current-status')))
            .data,
        '접수 완료',
      );
      expect(find.text('환불 완료'), findsNothing);
      expect(
        server.returns.single['return_reason'],
        '파손\n용기가 깨져 내용물이 새고 있습니다.',
      );
      server.returns[0].addAll({
        'return_status': 'COMPLETED',
        'pickup_status': 'COLLECTED',
        'refund_status': 'PROCESSING',
        'pickup_requested_on': '2026-10-30',
        'pickup_completed_on': '2026-10-31',
        'headquarters_received_on': '2026-11-01',
        'inspection_result': '파손 확인, 환불 처리 중',
      });
      await tapCheckoutControl(tester, 'return-status-refresh');
      expect(find.text('환불 처리 중'), findsOneWidget);
      expect(find.text('환불 완료'), findsNothing);
      await tester.scrollUntilVisible(
        find.byKey(const Key('return-current-status')),
        -180,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(find.byKey(const Key('return-current-status')))
            .data,
        '처리 완료',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'already returned quantities disable repeat requests on a narrow phone',
    (tester) async {
      final server = _Server();
      final order = await server.deliveredOrder();
      server.returns.add(server.returnRow(quantity: 2));
      await pump(
        tester,
        server,
        home: CustomerReturnRequestScreen(
          order: order,
          item: order.items.first,
        ),
        size: const Size(320, 568),
      );
      await fillReturn(tester);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('return-submit')))
            .onPressed,
        isNull,
      );
      expect(server.writes, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a rejected return save preserves form entries and never opens a success result',
    (tester) async {
      final server = _Server()..failure = 409;
      final order = await server.deliveredOrder();
      await pump(
        tester,
        server,
        home: CustomerReturnRequestScreen(
          order: order,
          item: order.items.first,
        ),
      );
      await fillReturn(tester);
      await tapCheckoutControl(tester, 'return-submit');
      expect(find.byKey(const Key('customer-return-request')), findsOneWidget);
      expect(find.byKey(const Key('customer-return-status')), findsNothing);
      expect(find.text('용기가 깨져 내용물이 새고 있습니다.'), findsOneWidget);
      expect(server.returns, isEmpty);
    },
  );

  testWidgets('capture purchase, delivery and return pages when requested', (
    tester,
  ) async {
    final directory = Platform.environment['SODAM_PREVIEW_DIR'];
    if (directory == null) return;
    final server = _Server();
    final key = GlobalKey();
    await pump(tester, server, capture: key);
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

    await capture('purchase_history');
    await tapCheckoutControl(tester, 'order-detail-ord_3_1');
    await capture('purchase_detail');
    await tapCheckoutControl(tester, 'order-detail-delivery');
    await capture('delivery_tracking');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tapCheckoutControl(tester, 'order-detail-return');
    await fillReturn(tester);
    await capture('return_request');
    await tapCheckoutControl(tester, 'return-submit');
    await capture('return_status');
  });
}
