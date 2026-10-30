import 'dart:io';
import 'dart:ui' as ui;

import 'package:beauty_project/model/customer/customers.dart';
import 'package:beauty_project/model/customer/home_product.dart';
import 'package:beauty_project/view/customer/login/customer_auth_widgets.dart';
import 'package:beauty_project/view/customer/product/product_cart_screen.dart';
import 'package:beauty_project/vm/customer/cart_handler.dart';
import 'package:beauty_project/vm/customer/cart_persistence_handler.dart';
import 'package:beauty_project/vm/customer/product_handler.dart';
import 'support/preview_catalog.dart';
import 'support/checkout_steps.dart';
import 'package:beauty_project/vm/customer/checkout_handler.dart';
import 'package:beauty_project/vm/customer/customer_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class CheckoutCustomer extends CustomerHandler {
  @override
  Customers? build() => const Customers(
    customerId: 'cus_preview',
    loginId: 'sodam',
    name: '소담고객',
    email: 'sodam@example.com',
    phone: '01012345678',
    address: '서울시 강남구 1',
  );
}

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

  Future<ProviderContainer> pumpCart(
    WidgetTester tester, {
    bool signedIn = true,
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
          if (signedIn)
            customerHandlerProvider.overrideWith(CheckoutCustomer.new),
        ],
        child: RepaintBoundary(
          key: capture,
          child: MaterialApp(
            theme: SodamStyle.theme,
            debugShowCheckedModeBanner: false,
            home: const CustomerCartScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(CustomerCartScreen)),
    );
    container
        .read(cartHandlerProvider.notifier)
        .add(
          homePreviewProducts.first,
          homePreviewProducts.first.options.first,
          2,
        );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets(
    'cart has no quantity controls, merges sizes, and handles selection and deletion',
    (tester) async {
      final container = await pumpCart(tester);
      final cart = container.read(cartHandlerProvider.notifier);
      final product = homePreviewProducts.first;
      cart.add(product, product.options[1], 1);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('increase-preview_1:30ml')), findsNothing);
      expect(container.read(cartHandlerProvider).first.quantity, 2);
      await tester.tap(find.byKey(const Key('change-size-preview_1:30ml')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('cart-size-50ml')));
      await tester.pumpAndSettle();
      expect(container.read(cartHandlerProvider), hasLength(1));
      expect(container.read(cartHandlerProvider).single.quantity, 3);
      expect(container.read(selectedCartTotalProvider), 74700);
      await tester.tap(find.byKey(const Key('select-all-cart')));
      await tester.pumpAndSettle();
      expect(container.read(selectedCartTotalProvider), 0);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('cart-go-checkout')))
            .onPressed,
        isNull,
      );
      await tester.tap(find.byKey(const Key('remove-preview_1:50ml')));
      await tester.pumpAndSettle();
      expect(find.text('장바구니가 비어 있어요.'), findsOneWidget);
    },
  );

  testWidgets('checkout shows cart edits and an editable shipping address', (
    tester,
  ) async {
    final container = await pumpCart(tester);
    await tester.ensureVisible(
      find.byKey(const Key('change-size-preview_1:30ml')),
    );
    await tester.tap(find.byKey(const Key('change-size-preview_1:30ml')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cart-size-50ml')));
    await tester.pumpAndSettle();
    expect(container.read(selectedCartTotalProvider), 49800);
    await tester.tap(find.byKey(const Key('cart-go-checkout')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('customer-checkout-screen')), findsOneWidget);
    expect(find.text('서울시 강남구 1'), findsOneWidget);
    expect(find.byKey(const Key('checkout-change-address')), findsOneWidget);
    expect(find.text('관리'), findsNothing);
    expect(container.read(checkoutAddressProvider)!.address, '서울시 강남구 1');
    expect(container.read(customerHandlerProvider).value!.address, '서울시 강남구 1');
    await openCheckoutAgreement(tester);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('checkout-payment')))
          .onPressed,
      isNull,
    );
    expect(find.text('49,800원 결제하기'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text(
        '결제수단 선택은 화면에서만 적용됩니다. 현재는 카드·계좌에서 금액이 청구되지 않고 주문이 결제 완료 상태로 저장됩니다.',
      ),
      180,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    expect(
      find.text(
        '결제수단 선택은 화면에서만 적용됩니다. 현재는 카드·계좌에서 금액이 청구되지 않고 주문이 결제 완료 상태로 저장됩니다.',
      ),
      findsOneWidget,
    );
    await agreeToCheckout(tester);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('checkout-payment')))
          .onPressed,
      isNotNull,
    );
    expect(container.read(cartHandlerProvider), hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('checkout requires a valid address before payment', (
    tester,
  ) async {
    await pumpCart(tester, signedIn: false, size: const Size(320, 568));
    await tester.tap(find.byKey(const Key('cart-go-checkout')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('checkout-next')))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextButton>(find.byKey(const Key('checkout-change-address')))
          .onPressed,
      isNull,
    );
    expect(find.text('배송지를 입력해 주세요.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test(
    'changing sizes cannot silently discard quantities over the option limit',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final cart = container.read(cartHandlerProvider.notifier);
      final product = homePreviewProducts.first;
      cart.add(product, product.options[0], 60);
      cart.add(product, product.options[1], 50);
      expect(cart.changeOption('preview_1:30ml', product.options[1]), isFalse);
      expect(container.read(cartHandlerProvider).map((item) => item.quantity), [
        60,
        50,
      ]);
    },
  );

  testWidgets('capture cart and checkout when preview output is configured', (
    tester,
  ) async {
    final directory = Platform.environment['SODAM_PREVIEW_DIR'];
    if (directory == null) return;
    final key = GlobalKey();
    await pumpCart(tester, capture: key);
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

    await capture('cart');
    await tester.tap(find.byKey(const Key('cart-go-checkout')));
    await tester.pumpAndSettle();
    await capture('checkout');
  });
}
