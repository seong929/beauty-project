import 'dart:io';
import 'support/catalog_http.dart';
import 'dart:ui' as ui;
import 'package:beauty_project/model/customer/cosmetic.dart';
import 'package:beauty_project/model/customer/customers.dart';
import 'package:beauty_project/model/customer/home_product.dart';
import 'package:beauty_project/model/customer/shipping_address.dart';
import 'package:beauty_project/view/customer/login/customer_auth_widgets.dart';
import 'package:beauty_project/view/customer/order/check_screen.dart';
import 'package:beauty_project/vm/customer/cart_handler.dart';
import 'package:beauty_project/vm/customer/checkout_flow_handler.dart';
import 'package:beauty_project/vm/customer/checkout_points_handler.dart';
import 'package:beauty_project/vm/customer/checkout_handler.dart';
import 'package:beauty_project/vm/customer/customer_handler.dart';
import 'package:beauty_project/vm/customer/customer_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'support/checkout_steps.dart';

class _CheckoutCustomer extends CustomerHandler {
  @override
  Customers? build() => const Customers(
    customerId: 'cus_flow',
    loginId: 'sodam',
    name: '홍길동',
    email: 'sodam@example.com',
    phone: '01012345678',
    address: '서울특별시 강남구 테헤란로 123',
    pointsBalance: 1200,
  );
}

final _product = HomeProduct.fromCatalog(
  const Cosmetic(
    id: 'sku_1',
    name: '하루 수분 토너 기획',
    brand: '소담',
    category: '스킨케어',
    volume: '200ml',
    price: 15900,
    availableQuantity: 10,
  ),
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

  var requests = 0;
  Future<ProviderContainer> pump(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    GlobalKey? capture,
    int pointsBalance = 1200,
  }) async {
    requests = 0;
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          customerHandlerProvider.overrideWith(_CheckoutCustomer.new),
          customerHttpClientProvider.overrideWithValue(
            withCatalogFixture(
              MockClient((_) async {
                requests++;
                return http.Response('{}', 500);
              }),
              [_product],
              pointsBalance: pointsBalance,
            ),
          ),
        ],
        child: RepaintBoundary(
          key: capture,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: SodamStyle.theme,
            home: const CustomerCheckoutScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(CustomerCheckoutScreen)),
    );
    container
        .read(cartHandlerProvider.notifier)
        .add(_product, _product.options.first, 1);
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets(
    'no request is sent before the final step and both confirmations are required',
    (tester) async {
      final scope = await pump(tester);
      expect(find.byKey(const Key('checkout-step-0')), findsOneWidget);
      await tapCheckoutControl(tester, 'checkout-next');
      expect(find.byKey(const Key('checkout-step-1')), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('checkout-points')))
            .enabled,
        isTrue,
      );
      expect(scope.read(selectedCartTotalProvider), 15900);
      await tapCheckoutControl(tester, 'checkout-next');
      expect(find.byKey(const Key('checkout-step-2')), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('checkout-next')))
            .onPressed,
        isNull,
      );
      final wallet = tester.widget<RadioListTile<CheckoutPaymentMethod>>(
        find.byKey(const Key('checkout-method-kakao')),
      );
      expect(wallet.enabled, isFalse);
      scope
          .read(checkoutFlowProvider.notifier)
          .selectMethod(CheckoutPaymentMethod.kakao);
      expect(scope.read(checkoutFlowProvider).method, isNull);
      await tapCheckoutControl(tester, 'checkout-method-card');
      await tapCheckoutControl(tester, 'checkout-next');
      expect(find.byKey(const Key('checkout-step-3')), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('checkout-payment')))
            .onPressed,
        isNull,
      );
      await agreeToCheckout(tester, 'checkout-agree-purchase');
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('checkout-payment')))
            .onPressed,
        isNull,
      );
      await agreeToCheckout(tester, 'checkout-agree-privacy');
      expect(scope.read(checkoutFlowProvider).allAgreed, isTrue);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('checkout-payment')))
            .onPressed,
        isNotNull,
      );
      await agreeToCheckout(tester, 'checkout-agree-purchase');
      expect(scope.read(checkoutFlowProvider).allAgreed, isFalse);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('checkout-payment')))
            .onPressed,
        isNull,
      );
      expect(requests, 0);
    },
  );

  testWidgets(
    'method, quantity and address edits invalidate previous confirmations',
    (tester) async {
      final scope = await pump(tester);
      await openCheckoutAgreement(tester);
      await agreeToCheckout(tester);
      await tapCheckoutControl(tester, 'checkout-method-transfer');
      expect(
        scope.read(checkoutFlowProvider).method,
        CheckoutPaymentMethod.transfer,
      );
      expect(scope.read(checkoutFlowProvider).allAgreed, isFalse);
      await agreeToCheckout(tester);
      scope.read(cartHandlerProvider.notifier).setQuantity('sku_1:200ml', 2);
      await tester.pumpAndSettle();
      expect(scope.read(checkoutFlowProvider).allAgreed, isFalse);
      expect(scope.read(selectedCartTotalProvider), 31800);
      await agreeToCheckout(tester);
      scope
          .read(checkoutAddressProvider.notifier)
          .update(
            const ShippingAddress(
              recipient: '홍길동',
              phone: '01012345678',
              address: '부산시 변경 주소',
            ),
          );
      await tester.pumpAndSettle();
      expect(scope.read(checkoutFlowProvider).allAgreed, isFalse);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('checkout-payment')))
            .onPressed,
        isNull,
      );
      expect(requests, 0);
    },
  );

  testWidgets(
    'points reduce payment, persist across steps and require renewed consent after editing',
    (tester) async {
      final scope = await pump(tester);
      await tapCheckoutControl(tester, 'checkout-next');
      await tester.enterText(find.byKey(const Key('checkout-points')), '500');
      await tester.pumpAndSettle();
      expect(scope.read(checkoutPointSummaryProvider).used, 500);
      expect(find.text('15,400원 · 다음'), findsOneWidget);
      await tapCheckoutControl(tester, 'checkout-next');
      expect(find.text('1540P'), findsWidgets);
      await tapCheckoutControl(tester, 'checkout-method-card');
      await tapCheckoutControl(tester, 'checkout-next');
      await agreeToCheckout(tester);
      expect(find.text('15,400원 결제하기'), findsOneWidget);
      scope.read(checkoutPointsProvider.notifier).edit(600);
      await tester.pumpAndSettle();
      expect(scope.read(checkoutFlowProvider).allAgreed, isFalse);
      expect(find.text('15,300원 결제하기'), findsOneWidget);
      await tapCheckoutControl(tester, 'checkout-back');
      await tapCheckoutControl(tester, 'checkout-back');
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('checkout-points')))
            .controller!
            .text,
        '600',
      );
      await tapCheckoutControl(tester, 'checkout-use-all-points');
      expect(scope.read(checkoutPointSummaryProvider).used, 1200);
      expect(find.text('14,700원 · 다음'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('checkout-points')),
        '999999',
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('checkout-points')))
            .controller!
            .text,
        '1200',
      );
      await tapCheckoutControl(tester, 'checkout-clear-points');
      expect(scope.read(checkoutPointSummaryProvider).used, 0);
      expect(find.text('15,900원 · 다음'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'all points are capped by the order total and a zero payment earns zero',
    (tester) async {
      final scope = await pump(tester, pointsBalance: 20000);
      await tapCheckoutControl(tester, 'checkout-next');
      await tapCheckoutControl(tester, 'checkout-use-all-points');
      expect(scope.read(checkoutPointSummaryProvider).used, 15900);
      expect(find.text('0원 · 다음'), findsOneWidget);
      await tapCheckoutControl(tester, 'checkout-next');
      expect(find.text('0P'), findsWidgets);
      scope.read(customerHandlerProvider.notifier).logout();
      await tester.pumpAndSettle();
      expect(scope.read(checkoutPointsProvider).amount, 0);
      expect(scope.read(checkoutPointsProvider).useAll, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('back traverses steps and logout clears the checkout draft', (
    tester,
  ) async {
    final scope = await pump(tester);
    await openCheckoutAgreement(tester);
    await agreeToCheckout(tester);
    await tapCheckoutControl(tester, 'checkout-back');
    expect(scope.read(checkoutFlowProvider).step, CheckoutStep.method);
    expect(scope.read(checkoutFlowProvider).method, CheckoutPaymentMethod.card);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(scope.read(checkoutFlowProvider).step, CheckoutStep.amount);
    scope.read(customerHandlerProvider.notifier).logout();
    await tester.pumpAndSettle();
    expect(scope.read(checkoutFlowProvider).step, CheckoutStep.information);
    expect(scope.read(checkoutFlowProvider).method, isNull);
    expect(scope.read(checkoutFlowProvider).allAgreed, isFalse);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('checkout-next')))
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('all four steps remain usable on a narrow phone', (tester) async {
    final scope = await pump(tester, size: const Size(320, 568));
    await openCheckoutAgreement(tester);
    await agreeToCheckout(tester);
    expect(scope.read(checkoutFlowProvider).canSubmit, isTrue);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('checkout-payment')))
          .onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
    expect(requests, 0);
  });

  Future<void> chooseRequest(
    WidgetTester tester,
    CheckoutDeliveryRequest request,
  ) async {
    await tapCheckoutControl(tester, 'checkout-delivery-request');
    await tester.tap(find.text(request.label).last);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'delivery presets survive step navigation and appear in the final summary',
    (tester) async {
      final scope = await pump(tester);
      expect(find.text('관리'), findsNothing);
      expect(find.byKey(const Key('checkout-change-address')), findsOneWidget);
      await chooseRequest(tester, CheckoutDeliveryRequest.door);
      expect(
        scope.read(checkoutFlowProvider).deliveryRequestText,
        '문 앞에 놓아주세요.',
      );
      await tapCheckoutControl(tester, 'checkout-next');
      await tapCheckoutControl(tester, 'checkout-back');
      expect(find.text('문 앞에 놓아주세요.'), findsOneWidget);
      await openCheckoutAgreement(tester);
      final summary = find.byKey(
        const Key('checkout-delivery-request-summary'),
      );
      await tester.scrollUntilVisible(
        summary,
        160,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(summary).data, '문 앞에 놓아주세요.');
      expect(
        scope.read(checkoutAddressProvider)!.address,
        '서울특별시 강남구 테헤란로 123',
      );
      expect(requests, 0);
    },
  );

  testWidgets(
    'custom requests require text, preserve edits and invalidate earlier consent',
    (tester) async {
      final scope = await pump(tester);
      await chooseRequest(tester, CheckoutDeliveryRequest.custom);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('checkout-next')))
            .onPressed,
        isNull,
      );
      await tester.enterText(
        find.byKey(const Key('checkout-custom-delivery-request')),
        '   ',
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('checkout-next')))
            .onPressed,
        isNull,
      );
      await tester.enterText(
        find.byKey(const Key('checkout-custom-delivery-request')),
        '초인종은 누르지 말아 주세요.',
      );
      await tester.pumpAndSettle();
      await openCheckoutAgreement(tester);
      await agreeToCheckout(tester);
      expect(scope.read(checkoutFlowProvider).allAgreed, isTrue);
      for (var i = 0; i < 3; i++) {
        await tapCheckoutControl(tester, 'checkout-back');
      }
      expect(find.text('초인종은 누르지 말아 주세요.'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('checkout-custom-delivery-request')),
        '배송 전에 문자 주세요.',
      );
      await tester.pumpAndSettle();
      expect(
        scope.read(checkoutFlowProvider).deliveryRequestText,
        '배송 전에 문자 주세요.',
      );
      expect(scope.read(checkoutFlowProvider).allAgreed, isFalse);
      expect(requests, 0);
    },
  );

  testWidgets('custom delivery input is limited to 200 characters', (
    tester,
  ) async {
    final scope = await pump(tester, size: const Size(320, 568));
    await chooseRequest(tester, CheckoutDeliveryRequest.custom);
    await tester.enterText(
      find.byKey(const Key('checkout-custom-delivery-request')),
      List.filled(201, '가').join(),
    );
    await tester.pumpAndSettle();
    expect(scope.read(checkoutFlowProvider).customDeliveryRequest.length, 200);
    expect(scope.read(checkoutFlowProvider).deliveryRequestValid, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('capture the four checkout steps when requested', (tester) async {
    final directory = Platform.environment['SODAM_PREVIEW_DIR'];
    if (directory == null) return;
    final key = GlobalKey();
    await pump(tester, capture: key);
    Future<void> capture(int step) async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final picture = await boundary.toImage(pixelRatio: 1);
        final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
        await Directory(directory).create(recursive: true);
        await File(
          '$directory/checkout_step_$step.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        picture.dispose();
      });
    }

    await capture(1);
    await tapCheckoutControl(tester, 'checkout-next');
    await capture(2);
    await tapCheckoutControl(tester, 'checkout-next');
    await tapCheckoutControl(tester, 'checkout-method-card');
    await capture(3);
    await tapCheckoutControl(tester, 'checkout-next');
    await agreeToCheckout(tester);
    await capture(4);
  });
}
