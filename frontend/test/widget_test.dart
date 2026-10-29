import 'package:beauty_project/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('로그인하지 않은 사용자는 로그인 화면을 본다', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MyApp()));
    await tester.pumpAndSettle();
    expect(find.text('로그인 아이디'), findsOneWidget);
    expect(find.text('비밀번호'), findsOneWidget);
    expect(find.text('관리자 대시보드'), findsNothing);
  });
}
