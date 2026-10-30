import 'dart:async';
import 'dart:convert';
import 'package:beauty_project/model/customer/customers.dart';
import 'package:beauty_project/model/customer/order.dart';
import 'package:beauty_project/service/customer/customer_order_service.dart';
import 'package:beauty_project/view/customer/order/detail_screen.dart';
import 'package:beauty_project/vm/customer/customer_handler.dart';
import 'package:beauty_project/vm/customer/customer_providers.dart';
import 'package:beauty_project/vm/customer/order_handler.dart';
import 'package:beauty_project/vm/customer/point_handler.dart';
import 'package:beauty_project/vm/customer/product_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _Customer extends CustomerHandler {
  @override
  Customers? build() => const Customers(
    customerId: 'cus_cancel',
    loginId: 'cancel',
    name: '소담 고객',
    email: 'test@example.com',
    phone: '01012345678',
    address: '서울 주소',
    pointsBalance: 2000,
  );
}

http.Response _json(Object value, [int status = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(value)),
  status,
  headers: {'content-type': 'application/json'},
);

class _Server {
  String status = 'PAID';
  bool assigned = false;
  bool dispatchOnCancel = false;
  int writes = 0;
  Completer<void>? hold;
  int balance = 2000;

  Map<String, dynamic> get row => {
    'customer_id': 'cus_cancel',
    'order_id': 'ord_cancel',
    'order_status': status,
    'shipping_address': '서울 주소',
    'order_date': '2026-10-30T09:00:00',
    'order_item_id': 'ord_cancel_1',
    'cosmetic_id': 'sku_1',
    'product_name': '테스트 토너',
    'quantity': 1,
    'unit_price': 16000,
    'order_total_amount': 16000,
    'used_points': 500,
    'earned_points': 1550,
    'delivery_id': assigned ? 'dlv_1' : null,
  };

  late final client = MockClient((request) async {
    switch (request.url.path) {
      case '/orders':
        return _json({
          'results': [row],
        });
      case '/customer_delivery_select':
        return _json({
          'result': [row],
        });
      case '/customer_points':
        return _json({
          'customer_id': 'cus_cancel',
          'balance': balance,
          'history': [],
        });
      case '/return_requests':
        return _json({'result': []});
      case '/orders_cancel':
        expect(request.method, 'POST');
        expect(request.url.queryParameters, {
          'customer_id': 'cus_cancel',
          'order_id': 'ord_cancel',
        });
        writes++;
        if (hold != null) await hold!.future;
        if (dispatchOnCancel) {
          status = 'SHIPPED';
          assigned = true;
          return _json({'detail': '출고된 주문은 취소할 수 없습니다.'}, 409);
        }
        status = 'CANCELLED';
        balance += 500 - 1550;
        return _json({
          'result': 'OK',
          'order_id': 'ord_cancel',
          'order_status': status,
          'restored_points': 500,
          'recovered_points': 1550,
        });
      default:
        return _json({'result': []});
    }
  });

  Future<CustomerOrder> order() async => (await CustomerOrderService(
    client: client,
    baseUrl: Uri.parse('http://test/'),
  ).fetch('cus_cancel')).single;
}

void main() {
  Future<ProviderContainer> pump(WidgetTester tester, _Server server) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final order = await server.order();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          customerHandlerProvider.overrideWith(_Customer.new),
          customerHttpClientProvider.overrideWithValue(server.client),
          homeCatalogProductsProvider.overrideWithValue(const AsyncData([])),
        ],
        child: MaterialApp(home: CustomerOrderDetailScreen(order: order)),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(
      tester.element(find.byType(CustomerOrderDetailScreen)),
    );
  }

  Future<void> visible(WidgetTester tester, Finder finder) async {
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        finder,
        180,
        scrollable: find.byType(Scrollable).last,
      );
    }
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await visible(tester, finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'cancellation below address editing requires confirmation and refreshes status and points',
    (tester) async {
      final server = _Server();
      final scope = await pump(tester, server);
      final cancel = find.byKey(const Key('order-detail-cancel'));
      await visible(tester, cancel);
      expect(
        tester.getTopLeft(cancel).dy,
        greaterThan(
          tester.getTopLeft(find.widgetWithText(OutlinedButton, '배송 주소 변경')).dy,
        ),
      );
      await tap(tester, cancel);
      await tap(tester, find.text('돌아가기'));
      expect(server.writes, 0);
      await tap(tester, cancel);
      await tap(tester, find.byKey(const Key('confirm-order-cancel')));
      expect(server.writes, 1);
      expect(find.text('주문이 취소되었습니다.'), findsOneWidget);
      expect(tester.widget<OutlinedButton>(cancel).onPressed, isNull);
      expect(find.text('주문 취소 완료'), findsOneWidget);
      expect(
        (await scope.read(customerOrdersProvider.future)).single.status,
        'CANCELLED',
      );
      expect((await scope.read(customerPointsProvider.future)).balance, 950);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a pending cancellation cannot be submitted twice', (
    tester,
  ) async {
    final server = _Server()..hold = Completer<void>();
    await pump(tester, server);
    final cancel = find.byKey(const Key('order-detail-cancel'));
    await tap(tester, cancel);
    await tap(tester, find.byKey(const Key('confirm-order-cancel')));
    expect(server.writes, 1);
    expect(tester.widget<OutlinedButton>(cancel).onPressed, isNull);
    server.hold!.complete();
    await tester.pumpAndSettle();
    expect(server.writes, 1);
    expect(find.text('주문 취소 완료'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'dispatch during confirmation is rejected and disables cancellation after refresh',
    (tester) async {
      final server = _Server()..dispatchOnCancel = true;
      await pump(tester, server);
      final cancel = find.byKey(const Key('order-detail-cancel'));
      await tap(tester, cancel);
      await tap(tester, find.byKey(const Key('confirm-order-cancel')));
      expect(server.writes, 1);
      expect(find.text('출고된 주문은 취소할 수 없습니다.'), findsOneWidget);
      expect(find.text('주문이 취소되었습니다.'), findsNothing);
      expect(tester.widget<OutlinedButton>(cancel).onPressed, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  for (final status in ['SHIPPED', 'DELIVERED', 'CANCELLED', 'PAID']) {
    testWidgets('cannot cancel $status with an assigned delivery', (
      tester,
    ) async {
      final server = _Server()
        ..status = status
        ..assigned = true;
      await pump(tester, server);
      final cancel = find.byKey(const Key('order-detail-cancel'));
      await visible(tester, cancel);
      expect(tester.widget<OutlinedButton>(cancel).onPressed, isNull);
      expect(server.writes, 0);
      expect(tester.takeException(), isNull);
    });
  }
}
