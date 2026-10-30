import 'package:beauty_project/app/admin_app.dart';
import 'package:beauty_project/model/auth/employee_login.dart';
import 'package:beauty_project/service/auth/auth_service.dart';
import 'package:beauty_project/view/admin/delivery_page.dart';
import 'package:beauty_project/view/admin/outbound_page.dart';
import 'package:beauty_project/view/admin/return_management_page.dart';
import 'package:beauty_project/view/admin/staff_purchase_order_page.dart';
import 'package:beauty_project/view/staff/staff_inventory_view.dart';
import 'package:beauty_project/view/staff/staff_order_view.dart';
import 'package:beauty_project/vm/auth/api_client_provider.dart';
import 'package:beauty_project/vm/auth/auth_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _StaffLogin extends AuthService {
  const _StaffLogin() : super(baseUrl: 'http://localhost');

  @override
  Future<EmployeeLogin> login({
    required String loginId,
    required String password,
  }) async => const EmployeeLogin(
    accessToken: 'token',
    tokenType: 'bearer',
    expiresIn: 3600,
    employeeId: 'E_staff_1',
    employeeRole: 'STAFF',
  );
}

void main() {
  testWidgets('직원은 공통 업무 화면을 사용하고 품의·발주 메뉴는 볼 수 없다', (tester) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final requested = <String>[];
    final client = MockClient((request) async {
      requested.add(request.url.path);
      final body = request.url.path == '/staff/order/available'
          ? '{"orders":[]}'
          : '[]';
      return http.Response(body, 200);
    });
    final container = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWith((ref) => const _StaffLogin()),
        apiClientProvider.overrideWith((ref) => client),
      ],
    );
    addTearDown(container.dispose);
    await container
        .read(authProvider.notifier)
        .login(loginId: 'staff', password: 'password');
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const AdminApp()),
    );
    await tester.pumpAndSettle();

    expect(find.text('품의 관리'), findsNothing);
    expect(find.text('발주 관리'), findsNothing);
    expect(find.text('발주처 관리'), findsNothing);
    expect(requested, isEmpty);
    final sections = <String, Type>{
      '재고 관리': StaffInventoryView,
      '주문 관리': StaffOrderView,
      '입고 관리': StaffPurchaseOrderPage,
      '출고 관리': OutboundPage,
      '배송 관리': DeliveryPage,
      '반품 관리': ReturnManagementPage,
    };
    for (final entry in sections.entries) {
      final item = find.widgetWithText(ListTile, entry.key);
      await tester.ensureVisible(item);
      await tester.tap(item);
      await tester.pumpAndSettle();
      expect(find.byType(entry.value), findsOneWidget, reason: entry.key);
    }
    expect(requested, contains('/staff/deliveries'));
    expect(requested, contains('/admin/returns'));
    expect(requested, isNot(contains('/admin/approvals')));
    expect(requested, isNot(contains('/admin/deliveries')));
  });
}
