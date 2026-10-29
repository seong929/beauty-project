import 'dart:convert';
import 'package:beauty_project/model/auth/employee_login.dart';
import 'package:beauty_project/service/auth/auth_service.dart';
import 'package:beauty_project/view/staff/cosmetic_option_detail_view.dart';
import 'package:beauty_project/vm/admin/management_vm.dart';
import 'package:beauty_project/vm/auth/api_client_provider.dart';
import 'package:beauty_project/vm/auth/auth_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _Admin extends AuthService {
  const _Admin() : super(baseUrl: 'http://localhost');
  @override
  Future<EmployeeLogin> login({
    required String loginId,
    required String password,
  }) async => const EmployeeLogin(
    accessToken: 't',
    tokenType: 'bearer',
    expiresIn: 3600,
    employeeId: 'E1',
    employeeRole: 'ADMIN',
  );
}

const _data = {
  'cosmetic_id': 'c1',
  'cosmetic_name': '크림',
  'sale_price': '1000.10',
  'unit_cost': '400.25',
  'min_stock_qty': 10,
  'target_stock_qty': 100,
  'volume_text': '50ml',
  'sale_status': 'ON_SALE',
};

Future<void> _open(WidgetTester tester, ProviderContainer container) async {
  await container
      .read(authProvider.notifier)
      .login(loginId: 'admin', password: 'p');
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      const CosmeticOptionDetailView(cosmeticId: 'c1'),
                ),
              ),
              child: const Text('옵션 열기'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('옵션 열기'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('가격 소수와 여섯 필드를 하나의 저장 요청으로 보내고 목록으로 복귀한다', (tester) async {
    http.Request? sent;
    final container = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWith((ref) => const _Admin()),
        cosmeticDetailsProvider('c1').overrideWith((ref) async => _data),
        cosmeticImageProvider('c1').overrideWith((ref) async => null),
        apiClientProvider.overrideWith(
          (ref) => MockClient((request) async {
            sent = request;
            return http.Response('{}', 200);
          }),
        ),
      ],
    );
    addTearDown(container.dispose);
    await _open(tester, container);
    final values = {
      '판매 가격': '1250.75',
      '상품 원가': '550.25',
      '최소 재고 수량': '5',
      '목표 재고 수량': '90',
      '용량': '55ml',
    };
    for (final entry in values.entries) {
      final field = find.widgetWithText(TextFormField, entry.key);
      await tester.ensureVisible(field);
      await tester.enterText(field, entry.value);
    }
    await tester.ensureVisible(find.byType(DropdownButtonFormField<String>));
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('판매 중단').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('변경사항 저장'));
    await tester.tap(find.text('변경사항 저장'));
    await tester.pumpAndSettle();
    expect(sent!.method, 'PATCH');
    expect(sent!.url.path, '/admin/cosmetics/c1');
    expect(jsonDecode(sent!.body), {
      'sale_price': '1250.75',
      'unit_cost': '550.25',
      'min_stock_qty': 5,
      'target_stock_qty': 90,
      'volume_text': '55ml',
      'sale_status': 'DISCONTINUED',
    });
    expect(find.byType(CosmeticOptionDetailView), findsNothing);
    expect(find.text('옵션 열기'), findsOneWidget);
  });

  testWidgets('목표 재고가 최소 재고 이하이면 저장 요청을 보내지 않는다', (tester) async {
    var requests = 0;
    final container = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWith((ref) => const _Admin()),
        cosmeticDetailsProvider('c1').overrideWith((ref) async => _data),
        cosmeticImageProvider('c1').overrideWith((ref) async => null),
        apiClientProvider.overrideWith(
          (ref) => MockClient((request) async {
            requests++;
            return http.Response('{}', 200);
          }),
        ),
      ],
    );
    addTearDown(container.dispose);
    await _open(tester, container);
    final target = find.widgetWithText(TextFormField, '목표 재고 수량');
    await tester.scrollUntilVisible(
      target,
      200,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.enterText(target, '5');
    await tester.ensureVisible(find.text('변경사항 저장'));
    await tester.tap(find.text('변경사항 저장'));
    await tester.pumpAndSettle();
    expect(requests, 0);
    expect(find.text('목표 재고는 최소 재고보다 커야 합니다.'), findsOneWidget);
  });
}
