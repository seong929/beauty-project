import 'dart:convert';

import 'package:beauty_project/model/customer/customers.dart';
import 'package:beauty_project/service/customer/customer_auth_service.dart';
import 'package:beauty_project/service/customer/customer_delivery_service.dart';
import 'package:beauty_project/view/customer/delivery/address_search_screen.dart';
import 'package:beauty_project/view/customer/delivery/delivery_address_screen.dart';
import 'package:beauty_project/view/customer/order/check_screen.dart';
import 'package:beauty_project/view/customer/mypage/profile_edit_screen.dart';
import 'package:beauty_project/vm/customer/customer_handler.dart';
import 'package:beauty_project/vm/customer/customer_providers.dart';
import 'package:beauty_project/vm/customer/delivery_handler.dart';
import 'package:beauty_project/vm/customer/checkout_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _SignedIn extends CustomerHandler {
  @override
  Customers? build() => const Customers(
    customerId: 'cus_1',
    loginId: 'sodam',
    name: '소담고객',
    email: 'test@example.com',
    phone: '01012345678',
    address: '서울시 기존 주소',
  );
}

http.Response _json(Object data, [int status = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(data)),
  status,
  headers: {'content-type': 'application/json'},
);

Map<String, dynamic> _order({
  String id = 'ord_1',
  String status = 'PAID',
  String address = '서울시 주문 주소',
  String? delivery,
}) => {
  'customer_id': 'cus_1',
  'order_id': id,
  'order_status': status,
  'shipping_address': address,
  'delivery_id': delivery,
};

void main() {
  test('postal message validates the postcode and a nonempty address', () {
    expect(
      PostalAddress.fromMessage(
        '{"zonecode":"04524","address":" 서울 중구 "}',
      ).formatted,
      '(04524) 서울 중구',
    );
    for (final message in [
      '[]',
      '{}',
      '{"zonecode":"123","address":"서울"}',
      '{"zonecode":"12345","address":" "}',
      'bad json',
    ]) {
      expect(() => PostalAddress.fromMessage(message), throwsFormatException);
    }
  });

  test(
    'split deliveries merge into one noneditable order and cancelled orders are blocked',
    () async {
      final service = CustomerDeliveryService(
        baseUrl: Uri.parse('http://test/'),
        client: MockClient((request) async {
          expect(request.url.queryParameters['customer_id'], 'cus_1');
          return _json({
            'result': [
              _order(delivery: 'dlv_ord_1_1'),
              _order(),
              _order(id: 'ord_2', status: 'CANCELLED'),
              _order(id: 'ord_3'),
            ],
          });
        }),
      );
      final orders = await service.fetch('cus_1');
      expect(orders, hasLength(3));
      expect(orders.map((order) => order.canChangeAddress), [
        false,
        false,
        true,
      ]);
    },
  );

  test('foreign customer data cannot be displayed', () async {
    final service = CustomerDeliveryService(
      baseUrl: Uri.parse('http://test/'),
      client: MockClient(
        (_) async => _json({
          'result': [
            {..._order(), 'customer_id': 'cus_other'},
          ],
        }),
      ),
    );
    await expectLater(
      service.fetch('cus_1'),
      throwsA(isA<CustomerAuthException>()),
    );
  });

  test(
    'save uses JSON and does not accept a mismatched success response',
    () async {
      final service = CustomerDeliveryService(
        baseUrl: Uri.parse('http://test/'),
        client: MockClient((request) async {
          expect(request.method, 'PUT');
          expect(request.url.path, '/customer_delivery_update');
          expect(jsonDecode(request.body), {
            'customer_id': 'cus_1',
            'order_id': 'ord_1',
            'shipping_address': '(04524) 서울 중구 101호',
          });
          return _json({
            'result': 'OK',
            'customer_id': 'cus_1',
            'order_id': 'ord_other',
            'shipping_address': '(04524) 서울 중구 101호',
          });
        }),
      );
      await expectLater(
        service.updateAddress('cus_1', 'ord_1', ' (04524) 서울 중구 101호 '),
        throwsA(isA<CustomerAuthException>()),
      );
    },
  );

  Future<ProviderContainer> pump(
    WidgetTester tester, {
    http.Client? client,
    PostalAddress? searchResult = const PostalAddress(
      zonecode: '04524',
      address: '서울 중구 세종대로 110',
    ),
    Widget home = const CustomerCheckoutScreen(),
  }) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          customerHandlerProvider.overrideWith(_SignedIn.new),
          addressSearchLauncherProvider.overrideWithValue(
            (_) async => searchResult,
          ),
          if (client != null)
            customerHttpClientProvider.overrideWithValue(client),
        ],
        child: MaterialApp(home: home),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(
      tester.element(find.byType(home.runtimeType)),
    );
  }

  testWidgets(
    'profile address editor combines searched postcode and detail before saving the profile',
    (tester) async {
      final container = await pump(
        tester,
        home: const CustomerProfileEditScreen(addressOnly: true),
      );
      await tester.tap(find.text('주소 검색'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('search-shipping-address')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('shipping-address-detail')),
        '101동 202호',
      );
      await tester.ensureVisible(
        find.byKey(const Key('save-shipping-address')),
      );
      await tester.tap(find.byKey(const Key('save-shipping-address')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('profile-address')))
            .controller!
            .text,
        '(04524) 서울 중구 세종대로 110 101동 202호',
      );
      expect(
        container.read(customerHandlerProvider).value!.address,
        '서울시 기존 주소',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('cancelled search preserves the current address', (tester) async {
    await pump(
      tester,
      searchResult: null,
      home: const CustomerProfileEditScreen(addressOnly: true),
    );
    await tester.tap(find.text('주소 검색'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('search-shipping-address')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('save-shipping-address')));
    await tester.tap(find.byKey(const Key('save-shipping-address')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('profile-address')))
          .controller!
          .text,
      '서울시 기존 주소',
    );
  });

  for (final entry in ['checkout-change-address', 'checkout-order-shipping']) {
    testWidgets(
      'checkout edits shipping through $entry without changing the customer profile',
      (tester) async {
        final scope = await pump(tester);
        await tester.ensureVisible(find.byKey(Key(entry)));
        expect(find.text('주문 배송 정보 변경'), findsOneWidget);
        expect(find.text('결제 완료 주문의 배송 정보 변경'), findsNothing);
        await tester.tap(find.byKey(Key(entry)));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('shipping-recipient')),
          '다른 수령인',
        );
        await tester.enterText(
          find.byKey(const Key('shipping-phone')),
          '01099998888',
        );
        await tester.ensureVisible(
          find.byKey(const Key('search-shipping-address')),
        );
        await tester.tap(find.byKey(const Key('search-shipping-address')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('shipping-address-detail')),
          '303호',
        );
        await tester.ensureVisible(
          find.byKey(const Key('save-shipping-address')),
        );
        await tester.tap(find.byKey(const Key('save-shipping-address')));
        await tester.pumpAndSettle();
        final shipping = scope.read(checkoutAddressProvider)!;
        expect(shipping.recipient, '다른 수령인');
        expect(shipping.phone, '01099998888');
        expect(shipping.address, '(04524) 서울 중구 세종대로 110 303호');
        expect(find.text('다른 수령인 01099998888'), findsOneWidget);
        expect(scope.read(customerHandlerProvider).value!.name, '소담고객');
        expect(scope.read(customerHandlerProvider).value!.address, '서울시 기존 주소');
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'existing order address saves through the API and reloads from the server',
    (tester) async {
      var stored = '서울시 주문 주소';
      var recipient = '기존 수령인';
      var phone = '01012345678';
      var memo = '';
      var reads = 0;
      var writes = 0;
      final client = MockClient((request) async {
        if (request.method == 'GET') {
          reads++;
          return _json({
            'result': [
              {
                ..._order(address: stored),
                'shipping_recipient': recipient,
                'shipping_phone': phone,
                'delivery_request': memo,
              },
              _order(id: 'ord_2', status: 'SHIPPED'),
            ],
          });
        }
        writes++;
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        stored = body['shipping_address'] as String;
        recipient = body['shipping_recipient'] as String;
        phone = body['shipping_phone'] as String;
        memo = body['delivery_request'] as String;
        return _json({'result': 'OK', ...body});
      });
      final container = await pump(
        tester,
        client: client,
        home: const CustomerDeliveryAddressScreen(),
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const Key('change-order-address-ord_2')),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byKey(const Key('change-order-address-ord_1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('shipping-recipient')), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('shipping-recipient')),
        '배송 수령인',
      );
      await tester.enterText(
        find.byKey(const Key('shipping-phone')),
        '01055556666',
      );
      await tester.ensureVisible(find.byKey(const Key('shipping-request')));
      await tester.enterText(
        find.byKey(const Key('shipping-request')),
        '배송 전에 연락해 주세요.',
      );
      await tester.ensureVisible(
        find.byKey(const Key('search-shipping-address')),
      );
      await tester.tap(find.byKey(const Key('search-shipping-address')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('shipping-address-detail')),
        '303호',
      );
      await tester.ensureVisible(
        find.byKey(const Key('save-shipping-address')),
      );
      await tester.tap(find.byKey(const Key('save-shipping-address')));
      await tester.pumpAndSettle();
      expect(writes, 1);
      expect(reads, 2);
      expect(find.text('(04524) 서울 중구 세종대로 110 303호'), findsOneWidget);
      expect(find.text('배송 수령인 01055556666'), findsOneWidget);
      expect(find.text('배송 전에 연락해 주세요.'), findsOneWidget);
      expect(
        container.read(customerHandlerProvider).value!.address,
        '서울시 기존 주소',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a concurrent dispatch rejects the save and refreshes the order status',
    (tester) async {
      var dispatched = false;
      final client = MockClient((request) async {
        if (request.method == 'GET') {
          return _json({
            'result': [_order(status: dispatched ? 'SHIPPED' : 'PAID')],
          });
        }
        dispatched = true;
        return _json({'detail': '출고 전인 주문만 배송지를 변경할 수 있습니다.'}, 409);
      });
      await pump(
        tester,
        client: client,
        home: const CustomerDeliveryAddressScreen(),
      );
      await tester.tap(find.byKey(const Key('change-order-address-ord_1')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('shipping-address')),
        '부산시 새 주소',
      );
      await tester.ensureVisible(
        find.byKey(const Key('save-shipping-address')),
      );
      await tester.tap(find.byKey(const Key('save-shipping-address')));
      await tester.pumpAndSettle();
      expect(find.text('서울시 주문 주소'), findsOneWidget);
      expect(find.text('부산시 새 주소'), findsNothing);
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const Key('change-order-address-ord_1')),
            )
            .onPressed,
        isNull,
      );
      expect(find.text('주문 배송지를 저장했습니다.'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  test('stale customer cannot send a delivery update after logout', () async {
    var writes = 0;
    final container = ProviderContainer(
      overrides: [
        customerHttpClientProvider.overrideWithValue(
          MockClient((_) async {
            writes++;
            return _json({});
          }),
        ),
      ],
    );
    addTearDown(container.dispose);
    await expectLater(
      container
          .read(deliveryAddressHandlerProvider)
          .save('cus_1', 'ord_1', '서울시'),
      throwsA(isA<CustomerAuthException>()),
    );
    expect(writes, 0);
  });
}
