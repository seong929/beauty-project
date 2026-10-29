import 'dart:async';
import 'dart:convert';

import 'package:beauty_project/model/customer/customers.dart';
import 'package:beauty_project/service/customer/customer_auth_service.dart';
import 'package:beauty_project/vm/customer/customer_auth_validation.dart';
import 'package:beauty_project/vm/customer/auth/customer_registration_model.dart';
import 'package:beauty_project/vm/customer/customer_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const registration = Customers(
  loginId: ' sodam ',
  password: ' secret123 ',
  name: ' 고객 ',
  email: ' sodam@example.com ',
  address: ' 서울시 ',
  phone: ' 010-1234-5678 ',
);

http.Response jsonResponse(Object data, [int status = 200]) =>
    http.Response.bytes(
      utf8.encode(jsonEncode(data)),
      status,
      headers: {'content-type': 'application/json'},
    );

http.Response signupSuccess(http.Request request) => jsonResponse({
  'result': 'OK',
  'customer_id': request.bodyFields['customer_id'],
});

CustomerAuthService serviceWith(
  Future<http.Response> Function(http.Request) handle, {
  Duration timeout = const Duration(seconds: 15),
}) {
  final client = MockClient(handle);
  addTearDown(client.close);
  return CustomerAuthService(
    client: client,
    baseUrl: Uri.parse('http://localhost:8000/'),
    timeout: timeout,
  );
}

void main() {
  group('Existing customer_upload contract', () {
    test('sends all seven required fields to the unchanged API', () async {
      final service = serviceWith((request) async {
        expect(request.url.path, '/customer_upload');
        expect(request.method, 'POST');
        expect(
          request.headers['content-type'],
          contains('application/x-www-form-urlencoded'),
        );
        final fields = Map<String, String>.of(request.bodyFields);
        final id = fields.remove('customer_id')!;
        expect(id, matches(RegExp(r'^cus_[0-9a-f]{32}$')));
        expect(id.length, lessThanOrEqualTo(60));
        expect(fields, {
          'login_id': 'sodam',
          'password': ' secret123 ',
          'customer_name': '고객',
          'email': 'sodam@example.com',
          'address': '서울시',
          'phone': '010-1234-5678',
        });
        expect(request.bodyFields.containsKey('gender'), isFalse);
        expect(request.bodyFields.containsKey('birth_year'), isFalse);
        return signupSuccess(request);
      });
      expect(await service.register(registration), startsWith('cus_'));
    });

    test('different registrations receive different generated IDs', () async {
      final service = serviceWith((request) async => signupSuccess(request));
      final first = await service.register(registration);
      final second = await service.register(registration);
      expect(first, isNot(second));
    });

    test('duplicate account or email returns the original API error', () async {
      final service = serviceWith(
        (_) async =>
            jsonResponse({'detail': '중복된 고객 ID, 로그인 ID 또는 이메일입니다.'}, 409),
      );
      await expectLater(
        service.register(registration),
        throwsA(
          isA<CustomerAuthException>().having(
            (error) => error.message,
            'message',
            '중복된 고객 ID, 로그인 ID 또는 이메일입니다.',
          ),
        ),
      );
    });

    test('validation errors do not expose echoed passwords', () async {
      final service = serviceWith(
        (_) async => jsonResponse({
          'detail': [
            {
              'loc': ['body', 'password'],
              'input': 'private-password',
            },
          ],
        }, 422),
      );
      await expectLater(
        service.register(registration),
        throwsA(
          isA<CustomerAuthException>().having(
            (error) => error.message,
            'message',
            isNot(contains('private-password')),
          ),
        ),
      );
    });

    test('network failures produce a readable error', () async {
      final service = serviceWith(
        (_) async => throw http.ClientException('Failed'),
      );
      await expectLater(
        service.register(registration),
        throwsA(
          isA<CustomerAuthException>().having(
            (error) => error.message,
            'message',
            contains('네트워크'),
          ),
        ),
      );
    });

    test('timeouts are handled', () async {
      final response = Completer<http.Response>();
      final service = serviceWith(
        (_) => response.future,
        timeout: const Duration(milliseconds: 5),
      );
      await expectLater(
        service.register(registration),
        throwsA(
          isA<CustomerAuthException>().having(
            (error) => error.message,
            'message',
            contains('시간'),
          ),
        ),
      );
      response.complete(jsonResponse({}, 500));
    });

    test('server errors do not expose internal details', () async {
      final service = serviceWith(
        (_) async => http.Response('SQL traceback', 500),
      );
      await expectLater(
        service.register(registration),
        throwsA(
          isA<CustomerAuthException>().having(
            (error) => error.message,
            'message',
            isNot(contains('SQL')),
          ),
        ),
      );
    });

    test(
      'invalid or mismatched responses are not treated as success',
      () async {
        for (final response in [
          http.Response('not JSON', 200),
          jsonResponse({'result': 'Error'}),
          jsonResponse({'result': 'OK'}),
          jsonResponse({'result': 'OK', 'customer_id': 'wrong_customer'}),
        ]) {
          final service = serviceWith((_) async => response);
          await expectLater(
            service.register(registration),
            throwsA(isA<CustomerAuthException>()),
          );
        }
      },
    );
  });

  group('Riverpod registration model', () {
    ProviderContainer containerWith(MockClient client) {
      final container = ProviderContainer(
        overrides: [
          customerHttpClientProvider.overrideWithValue(client),
          customerApiBaseUrlProvider.overrideWithValue(
            Uri.parse('http://localhost:8000/'),
          ),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(client.close);
      return container;
    }

    test('successful registration prepares the login ID', () async {
      final container = containerWith(
        MockClient((request) async => signupSuccess(request)),
      );
      final vm = container.read(customerRegistrationProvider.notifier);
      expect(await vm.register(registration), isTrue);
      expect(container.read(customerRegistrationProvider).value, 'sodam');
      expect(container.read(customerRegistrationProvider).isLoading, isFalse);
    });

    test('duplicate submissions are ignored while registering', () async {
      final received = Completer<http.Request>();
      final response = Completer<http.Response>();
      var calls = 0;
      final container = containerWith(
        MockClient((request) {
          calls++;
          received.complete(request);
          return response.future;
        }),
      );
      final vm = container.read(customerRegistrationProvider.notifier);
      final first = vm.register(registration);
      expect(container.read(customerRegistrationProvider).isLoading, isTrue);
      expect(await vm.register(registration), isFalse);
      response.complete(signupSuccess(await received.future));
      expect(await first, isTrue);
      expect(calls, 1);
    });

    test(
      'failure releases loading state and preserves the error message',
      () async {
        final container = containerWith(
          MockClient((_) async => jsonResponse({'detail': '중복된 정보입니다.'}, 409)),
        );
        final vm = container.read(customerRegistrationProvider.notifier);
        expect(await vm.register(registration), isFalse);
        expect(container.read(customerRegistrationProvider).isLoading, isFalse);
        expect(
          container.read(customerRegistrationProvider).error.toString(),
          '중복된 정보입니다.',
        );
        vm.clearError();
        expect(container.read(customerRegistrationProvider).hasError, isFalse);
      },
    );
  });

  test('required values and password confirmation are validated', () {
    expect(CustomerAuthValidation.loginId(''), isNotNull);
    expect(CustomerAuthValidation.password('short'), isNotNull);
    expect(
      CustomerAuthValidation.confirmPassword('different', 'secret123'),
      isNotNull,
    );
    expect(CustomerAuthValidation.name('고'), isNotNull);
    expect(CustomerAuthValidation.email('invalid'), isNotNull);
    expect(CustomerAuthValidation.address(' '), isNotNull);
    expect(CustomerAuthValidation.phone('abc'), isNotNull);
  });

  test('normal signup values pass validation', () {
    expect(CustomerAuthValidation.loginId(registration.loginId), isNull);
    expect(CustomerAuthValidation.password(registration.password), isNull);
    expect(
      CustomerAuthValidation.confirmPassword(
        registration.password,
        registration.password,
      ),
      isNull,
    );
    expect(CustomerAuthValidation.name(registration.name), isNull);
    expect(CustomerAuthValidation.email(registration.email), isNull);
    expect(CustomerAuthValidation.address(registration.address), isNull);
    expect(CustomerAuthValidation.phone(registration.phone), isNull);
  });
}
