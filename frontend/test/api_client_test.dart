import 'dart:io';
import 'dart:async';

import 'package:beauty_project/model/auth/employee_login.dart';
import 'package:beauty_project/service/auth/auth_service.dart';
import 'package:beauty_project/vm/auth/api_client_provider.dart';
import 'package:beauty_project/vm/auth/auth_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _LoginService extends AuthService {
  const _LoginService() : super(baseUrl: 'http://localhost');

  @override
  Future<EmployeeLogin> login({
    required String loginId,
    required String password,
  }) async => EmployeeLogin(
    accessToken: loginId == 'a' ? 'real-session-token' : 'new-session-token',
    tokenType: 'bearer',
    expiresIn: 3600,
    employeeId: 'admin-1',
    employeeRole: 'ADMIN',
  );
}

void main() {
  test('로그인 JWT를 전달하고 403은 유지, 401은 세션을 종료한다', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var status = 403;
    String? authorization;
    server.listen((request) async {
      authorization = request.headers.value(HttpHeaders.authorizationHeader);
      request.response.statusCode = status;
      await request.response.close();
    });
    final container = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWith((ref) => const _LoginService()),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await server.close(force: true);
    });

    expect(
      await container
          .read(authProvider.notifier)
          .login(loginId: 'a', password: 'b'),
      isTrue,
    );
    final client = container.read(apiClientProvider);
    final url = Uri.parse('http://127.0.0.1:${server.port}/test');
    final forbidden = await client.get(url);
    expect(forbidden.statusCode, 403);
    expect(authorization, 'Bearer real-session-token');
    expect(container.read(authProvider).isLoggedIn, isTrue);

    status = 401;
    expect((await client.get(url)).statusCode, 401);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(authProvider).isLoggedIn, isFalse);
    expect(container.read(authProvider).errorMessage, contains('만료'));
  });

  test('이전 계정의 지연된 401은 새로운 세션을 종료하지 않는다', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requestReceived = Completer<void>();
    final releaseResponse = Completer<void>();
    server.listen((request) async {
      requestReceived.complete();
      await releaseResponse.future;
      request.response.statusCode = 401;
      await request.response.close();
    });
    final container = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWith((ref) => const _LoginService()),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await server.close(force: true);
    });

    await container
        .read(authProvider.notifier)
        .login(loginId: 'a', password: 'b');
    final response = container
        .read(apiClientProvider)
        .get(Uri.parse('http://127.0.0.1:${server.port}/test'));
    await requestReceived.future;
    container.read(authProvider.notifier).logout();
    await container
        .read(authProvider.notifier)
        .login(loginId: 'new', password: 'b');
    releaseResponse.complete();
    expect((await response).statusCode, 401);
    await Future<void>.delayed(Duration.zero);
    expect(
      container.read(authProvider).employee?.accessToken,
      'new-session-token',
    );
  });
}
