import 'package:beauty_project/main.dart';
import 'package:beauty_project/view/customer/login/customer_login_screen.dart';
import 'package:beauty_project/view/auth/login_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('기본 앱은 고객 로그인만 표시한다', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MyApp()));

    await tester.pumpAndSettle();

    expect(find.byType(CustomerLoginScreen), findsOneWidget);
    expect(find.byType(LoginPage), findsNothing);
    expect(find.text('로그인 유형 선택'), findsNothing);
    expect(find.text('관리자 대시보드'), findsNothing);
  });
}
