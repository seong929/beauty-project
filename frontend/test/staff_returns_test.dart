import 'dart:convert';

import 'package:beauty_project/model/auth/employee_login.dart';
import 'package:beauty_project/service/auth/auth_service.dart';
import 'package:beauty_project/vm/admin/management_vm.dart';
import 'package:beauty_project/vm/auth/api_client_provider.dart';
import 'package:beauty_project/vm/auth/auth_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _StaffAuth extends AuthService {
  const _StaffAuth() : super(baseUrl: 'http://localhost');

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
  test('직원 반품 처리는 로그인한 직원 ID로 요청한다', () async {
    http.Request? sent;
    final client = MockClient((request) async {
      sent = request;
      return http.Response('{}', 200);
    });
    final container = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWith((ref) => const _StaffAuth()),
        apiClientProvider.overrideWith((ref) => client),
      ],
    );
    addTearDown(container.dispose);
    await container
        .read(authProvider.notifier)
        .login(loginId: 's', password: 'p');
    await container.read(managementActionsProvider.notifier).returnAction(
      'return-1',
      'decision',
      'PATCH',
      {'return_status': 'APPROVED'},
    );
    expect(sent!.url.path, '/admin/returns/return-1/decision');
    expect(jsonDecode(sent!.body), {
      'employee_id': 'E_staff_1',
      'return_status': 'APPROVED',
    });
  });
}
