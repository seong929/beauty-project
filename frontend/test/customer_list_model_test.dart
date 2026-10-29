import 'dart:async';
import 'dart:convert';

import 'package:beauty_project/model/customer/customers.dart';
import 'package:beauty_project/service/customer/customer_auth_service.dart';
import 'package:beauty_project/vm/customer/customer_providers.dart';
import 'package:beauty_project/vm/customer/profile/customer_list_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const row = {
  'customer_id': 'cus_1',
  'customer_name': '소담',
  'phone_number': '01012345678',
  'address': '서울시',
};
const customer = Customers(
  customerId: 'cus_1',
  loginId: 'sodam',
  name: ' 소담 ',
  email: ' sodam@example.com ',
  address: ' 서울시 ',
  phone: ' 01012345678 ',
  password: ' secret123 ',
);

http.Response jsonResponse(Object data, [int status = 200]) =>
    http.Response.bytes(
      utf8.encode(jsonEncode(data)),
      status,
      headers: {'content-type': 'application/json'},
    );

ProviderContainer containerWith(
  Future<http.Response> Function(http.Request) respond, {
  Duration timeout = const Duration(seconds: 15),
}) {
  final client = MockClient(respond);
  final container = ProviderContainer(
    overrides: [
      customerAuthServiceProvider.overrideWithValue(
        CustomerAuthService(
          client: client,
          baseUrl: Uri.parse('http://localhost:8000/'),
          timeout: timeout,
        ),
      ),
    ],
  );
  addTearDown(container.dispose);
  addTearDown(client.close);
  return container;
}

void main() {
  test(
    'loads the original result array and partial profile fields automatically',
    () async {
      final container = containerWith((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/customer_select');
        return jsonResponse({
          'result': [row],
        });
      });
      final customers = await container.read(customerListModelProvider.future);
      expect(customers.single.customerId, 'cus_1');
      expect(customers.single.phone, '01012345678');
      expect(customers.single.loginId, isEmpty);
      expect(customers.single.accountStatus, isEmpty);
    },
  );

  test(
    'registration uses the original seven form fields and refreshes',
    () async {
      final requests = <String>[];
      final container = containerWith((request) async {
        requests.add(request.method);
        if (request.method == 'POST') {
          expect(request.url.path, '/customer_upload');
          expect(request.bodyFields, hasLength(7));
          expect(request.bodyFields['password'], ' secret123 ');
          return jsonResponse({
            'result': 'OK',
            'customer_id': request.bodyFields['customer_id'],
          });
        }
        return jsonResponse({
          'result': [row],
        });
      });
      await container.read(customerListModelProvider.future);
      expect(
        await container
            .read(customerListModelProvider.notifier)
            .insertCustomer(customer),
        'OK',
      );
      expect(requests, ['GET', 'POST', 'GET']);
    },
  );

  test('update sends a query ID and only supported form fields', () async {
    final container = containerWith((request) async {
      if (request.method == 'PUT') {
        expect(request.url.path, '/customer_update');
        expect(request.url.queryParameters, {'customer_id': 'cus_1'});
        expect(request.bodyFields, {
          'customer_name': '소담',
          'email': 'sodam@example.com',
          'address': '서울시',
          'phone': '01012345678',
        });
        return jsonResponse({'result': 'OK'});
      }
      return jsonResponse({
        'result': [row],
      });
    });
    await container.read(customerListModelProvider.future);
    expect(
      await container
          .read(customerListModelProvider.notifier)
          .updateCustomer(customer),
      'OK',
    );
  });

  test(
    'withdrawal uses the original path and retains rows preserved by the API',
    () async {
      final container = containerWith((request) async {
        if (request.method == 'POST') {
          expect(request.url.path, '/customer_delect');
          expect(request.bodyFields, {'customer_id': 'cus_1'});
          return jsonResponse({'result': 'OK'});
        }
        return jsonResponse({
          'result': [row],
        });
      });
      await container.read(customerListModelProvider.future);
      expect(
        await container
            .read(customerListModelProvider.notifier)
            .deleteCustomer(' cus_1 '),
        'OK',
      );
      expect(
        container
            .read(customerListModelProvider.notifier)
            .customers
            .single
            .customerId,
        'cus_1',
      );
    },
  );

  test('failed mutations preserve old data and show the API error', () async {
    final container = containerWith(
      (request) async => request.method == 'GET'
          ? jsonResponse({
              'result': [row],
            })
          : jsonResponse({'detail': '이미 탈퇴 처리된 고객입니다.'}, 409),
    );
    await container.read(customerListModelProvider.future);
    expect(
      await container
          .read(customerListModelProvider.notifier)
          .deleteCustomer('cus_1'),
      'ERROR',
    );
    expect(
      container
          .read(customerListModelProvider.notifier)
          .customers
          .single
          .customerId,
      'cus_1',
    );
    expect(
      container.read(customerListModelProvider).error.toString(),
      '이미 탈퇴 처리된 고객입니다.',
    );
  });

  test(
    'a failed refresh never turns a completed update into a failed update',
    () async {
      var gets = 0;
      final container = containerWith((request) async {
        if (request.method == 'PUT') return jsonResponse({'result': 'OK'});
        if (gets++ > 0) return http.Response('SQL traceback', 500);
        return jsonResponse({
          'result': [row],
        });
      });
      await container.read(customerListModelProvider.future);
      expect(
        await container
            .read(customerListModelProvider.notifier)
            .updateCustomer(customer),
        'OK',
      );
      final state = container.read(customerListModelProvider);
      expect(
        container
            .read(customerListModelProvider.notifier)
            .customers
            .single
            .customerId,
        'cus_1',
      );
      expect(state.error.toString(), contains('요청은 완료되었지만'));
      expect(state.error.toString(), isNot(contains('SQL')));
    },
  );

  test('duplicates are ignored while a mutation is pending', () async {
    final pending = Completer<http.Response>();
    var writes = 0;
    final container = containerWith((request) async {
      if (request.method == 'POST') {
        writes++;
        return pending.future;
      }
      return jsonResponse({
        'result': [row],
      });
    });
    await container.read(customerListModelProvider.future);
    final vm = container.read(customerListModelProvider.notifier);
    final first = vm.deleteCustomer('cus_1');
    expect(await vm.deleteCustomer('cus_1'), 'BUSY');
    pending.complete(jsonResponse({'result': 'OK'}));
    expect(await first, 'OK');
    expect(writes, 1);
  });

  test('malformed refresh results preserve the previous list', () async {
    var gets = 0;
    final container = containerWith(
      (_) async => jsonResponse(
        gets++ == 0
            ? {
                'result': [row],
              }
            : {
                'result': [row, null],
              },
      ),
    );
    await container.read(customerListModelProvider.future);
    await container.read(customerListModelProvider.notifier).refreshCustomers();
    expect(
      container
          .read(customerListModelProvider.notifier)
          .customers
          .single
          .customerId,
      'cus_1',
    );
    expect(container.read(customerListModelProvider).hasError, isTrue);
  });

  test('timeouts resolve to an error state and no longer load', () async {
    final pending = Completer<http.Response>();
    final container = containerWith(
      (_) => pending.future,
      timeout: const Duration(milliseconds: 5),
    );
    await expectLater(
      container.read(customerListModelProvider.future),
      throwsA(isA<CustomerAuthException>()),
    );
    expect(container.read(customerListModelProvider).isLoading, isFalse);
    pending.complete(jsonResponse({'result': []}));
  });
}
