import 'dart:async';
import 'dart:convert';

import 'package:beauty_project/model/customer/customers.dart';
import 'package:beauty_project/service/customer/customer_auth_service.dart';
import 'package:beauty_project/vm/customer/customer_handler.dart';
import 'package:beauty_project/vm/customer/customer_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const loggedInCustomer = Customers(
  customerId: 'cus_1',
  loginId: 'sodam',
  name: '소담고객',
  email: 'sodam@example.com',
  address: '서울시',
  phone: '01012345678',
  password: 'should-not-be-kept',
);

class LoginService extends CustomerAuthService {
  LoginService(this.respond)
    : super(client: MockClient((_) async => http.Response('', 500)));
  final Future<Customers> Function(String loginId, String password) respond;

  @override
  Future<Customers> login({
    required String loginId,
    required String password,
  }) => respond(loginId, password);
}

ProviderContainer containerWith(CustomerAuthService service) {
  final container = ProviderContainer(
    overrides: [customerAuthServiceProvider.overrideWithValue(service)],
  );
  addTearDown(container.dispose);
  addTearDown(service.client.close);
  return container;
}

void main() {
  test(
    'login posts only credentials and reports authentication errors',
    () async {
      var calls = 0;
      final container = containerWith(
        CustomerAuthService(
          client: MockClient((request) async {
            calls++;
            expect(request.url.path, '/customer_login');
            expect(request.method, 'POST');
            expect(request.bodyFields, {
              'login_id': 'sodam',
              'password': 'secret123',
            });
            return http.Response.bytes(
              utf8.encode(jsonEncode({'detail': '아이디 또는 비밀번호가 올바르지 않습니다.'})),
              401,
            );
          }),
        ),
      );
      final handler = container.read(customerHandlerProvider.notifier);

      expect(
        await handler.login(loginId: 'sodam', password: 'secret123'),
        isFalse,
      );
      expect(
        container.read(customerHandlerProvider).error.toString(),
        '아이디 또는 비밀번호가 올바르지 않습니다.',
      );
      expect(container.read(customerHandlerProvider).value, isNull);
      expect(calls, 1);
      handler.clearError();
      expect(container.read(customerHandlerProvider).hasError, isFalse);
    },
  );

  test(
    'successful authentication stores the profile without a password; logout clears it',
    () async {
      final container = containerWith(
        LoginService((id, password) async {
          expect(id, 'sodam');
          expect(password, ' secret123 ');
          return loggedInCustomer;
        }),
      );
      final handler = container.read(customerHandlerProvider.notifier);
      expect(
        await handler.login(loginId: ' sodam ', password: ' secret123 '),
        isTrue,
      );
      expect(
        container.read(customerHandlerProvider).value!.customerId,
        'cus_1',
      );
      expect(container.read(customerHandlerProvider).value!.password, isEmpty);
      handler.logout();
      expect(container.read(customerHandlerProvider).value, isNull);
    },
  );

  test(
    'duplicate login attempts do not issue duplicate authentication requests',
    () async {
      final pending = Completer<Customers>();
      var calls = 0;
      final container = containerWith(
        LoginService((_, _) {
          calls++;
          return pending.future;
        }),
      );
      final handler = container.read(customerHandlerProvider.notifier);
      final first = handler.login(loginId: 'sodam', password: 'secret123');
      expect(container.read(customerHandlerProvider).isLoading, isTrue);
      expect(
        await handler.login(loginId: 'sodam', password: 'secret123'),
        isFalse,
      );
      pending.complete(loggedInCustomer);
      expect(await first, isTrue);
      expect(calls, 1);
    },
  );

  test('an incomplete profile is not accepted as a login', () async {
    final container = containerWith(
      LoginService(
        (_, _) async => const Customers(
          loginId: 'sodam',
          name: '',
          email: '',
          address: '',
          phone: '',
        ),
      ),
    );
    final handler = container.read(customerHandlerProvider.notifier);
    expect(
      await handler.login(loginId: 'sodam', password: 'secret123'),
      isFalse,
    );
    expect(container.read(customerHandlerProvider).hasError, isTrue);
    expect(container.read(customerHandlerProvider).value, isNull);
  });

  test('a disposed provider ignores a late authentication result', () async {
    final pending = Completer<Customers>();
    final container = ProviderContainer(
      overrides: [
        customerAuthServiceProvider.overrideWithValue(
          LoginService((_, _) => pending.future),
        ),
      ],
    );
    final handler = container.read(customerHandlerProvider.notifier);
    final request = handler.login(loginId: 'sodam', password: 'secret123');
    final service = container.read(customerAuthServiceProvider);
    container.dispose();
    service.client.close();
    pending.complete(loggedInCustomer);
    expect(await request, isFalse);
  });
}
