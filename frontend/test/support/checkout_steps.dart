import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> tapCheckoutControl(WidgetTester tester, String key) async {
  final target = find.byKey(Key(key));
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      target,
      180,
      scrollable: find.byType(Scrollable).last,
    );
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> openCheckoutAgreement(WidgetTester tester) async {
  await tapCheckoutControl(tester, 'checkout-next');
  await tapCheckoutControl(tester, 'checkout-next');
  await tapCheckoutControl(tester, 'checkout-method-card');
  await tapCheckoutControl(tester, 'checkout-next');
}

Future<void> agreeToCheckout(
  WidgetTester tester, [
  String key = 'checkout-agree-all',
]) async {
  final row = find.byKey(Key(key));
  if (row.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      row,
      180,
      scrollable: find.byType(Scrollable).last,
    );
  }
  final checkbox = find.descendant(of: row, matching: find.byType(Checkbox));
  await tester.ensureVisible(checkbox);
  await tester.pumpAndSettle();
  await tester.tap(checkbox);
  await tester.pumpAndSettle();
}
