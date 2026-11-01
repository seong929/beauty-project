import 'package:beauty_project/main.dart';
import 'package:beauty_project/view/customer/login/customer_login_screen.dart';
import 'package:beauty_project/view/auth/login_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('시작 화면은 그라데이션·브랜드 문구 순서로 표시한 뒤 로그인으로 이동한다', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MyApp()));

    expect(find.byKey(const Key('customer-launch-screen')), findsOneWidget);
    expect(find.byType(CustomerLoginScreen), findsNothing);
    final background = tester.widget<DecoratedBox>(
      find.byKey(const Key('customer-launch-background')),
    );
    expect(
      ((background.decoration as BoxDecoration).gradient as LinearGradient)
          .colors
          .first,
      Colors.white,
    );

    await tester.pump(const Duration(milliseconds: 1800));
    expect(find.text('새로운 하나의\n발견'), findsOneWidget);
    expect(
      tester
          .widget<Opacity>(
            find.ancestor(
              of: find.byKey(const Key('customer-launch-message')),
              matching: find.byType(Opacity),
            ),
          )
          .opacity,
      1,
    );
    expect(find.byType(CustomerLoginScreen), findsNothing);

    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('customer-launch-screen')), findsNothing);
    expect(find.byType(CustomerLoginScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('시작 화면을 닫으면 남은 애니메이션도 해제된다', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MyApp()));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(find.byType(CustomerLoginScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('기본 앱은 고객 로그인만 표시한다', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MyApp()));

    await tester.pumpAndSettle();

    expect(find.byType(CustomerLoginScreen), findsOneWidget);
    expect(find.byType(LoginPage), findsNothing);
    expect(find.text('로그인 유형 선택'), findsNothing);
    expect(find.text('관리자 대시보드'), findsNothing);
  });
}
