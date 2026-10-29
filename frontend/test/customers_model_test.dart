import 'package:beauty_project/model/customer/customers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('customer JSON maps all supported information to final fields', () {
    final customer = Customers.fromJson({
      'customer_id': 'cus_1',
      'login_id': 'sodam',
      'customer_name': '고객',
      'email': 'customer@example.com',
      'phone': '010-1234-5678',
      'address': '서울시',
      'gender': 'F',
      'points_balance': 1200,
      'account_status': 'ACTIVE',
    });
    expect(customer.customerId, 'cus_1');
    expect(customer.loginId, 'sodam');
    expect(customer.name, '고객');
    expect(customer.email, 'customer@example.com');
    expect(customer.phone, '010-1234-5678');
    expect(customer.address, '서울시');
    expect(customer.gender, 'F');
    expect(customer.pointsBalance, 1200);
    expect(customer.accountStatus, 'ACTIVE');
    expect(Customers.fromJson(customer.toJson()).toJson(), customer.toJson());
  });

  test('existing customer_select rows support the phone_number alias', () {
    final customer = Customers.fromJson({
      'customer_id': 'cus_1',
      'customer_name': '고객',
      'phone_number': '010-1234-5678',
      'address': '서울시',
    });
    expect(customer.phone, '010-1234-5678');
    expect(customer.name, '고객');
    expect(customer.loginId, isEmpty);
    expect(customer.accountStatus, isEmpty);
    expect(customer.toJson()['phone'], '010-1234-5678');
  });

  test('missing and null JSON fields have safe defaults', () {
    for (final json in <Map<String, dynamic>>[
      {},
      {
        'customer_id': null,
        'login_id': null,
        'customer_name': null,
        'email': null,
        'phone': null,
        'address': null,
        'gender': null,
        'points_balance': null,
        'account_status': null,
      },
    ]) {
      final customer = Customers.fromJson(json);
      expect(customer.customerId, isEmpty);
      expect(customer.loginId, isEmpty);
      expect(customer.name, isEmpty);
      expect(customer.email, isEmpty);
      expect(customer.phone, isEmpty);
      expect(customer.address, isEmpty);
      expect(customer.gender, 'UNDISCLOSED');
      expect(customer.pointsBalance, 0);
      expect(customer.accountStatus, isEmpty);
    }
  });

  test('numeric IDs and string points can be read from server responses', () {
    final customer = Customers.fromJson({
      'customer_id': 7,
      'points_balance': '1500',
    });
    expect(customer.customerId, '7');
    expect(customer.pointsBalance, 1500);
    expect(Customers.fromJson({'points_balance': 'invalid'}).pointsBalance, 0);
  });

  test('passwords and hashes are excluded from customer information JSON', () {
    const customer = Customers(
      customerId: 'cus_1',
      loginId: 'sodam',
      name: '고객',
      email: 'customer@example.com',
      phone: '010-1234-5678',
      address: '서울시',
      password: 'private-password',
    );
    expect(customer.toJson().containsKey('password'), isFalse);
    expect(customer.toJson().containsKey('password_hash'), isFalse);
    final received = Customers.fromJson({
      ...customer.toJson(),
      'password': 'private-password',
      'password_hash': 'server-hash',
    });
    expect(received.password, isEmpty);
  });

  test(
    'signup form keeps the existing API fields and explicit ID override',
    () {
      const customer = Customers(
        customerId: 'cus_1',
        loginId: ' sodam ',
        name: ' 고객 ',
        email: ' customer@example.com ',
        phone: ' 010-1234-5678 ',
        address: ' 서울시 ',
        password: ' secret123 ',
        gender: 'F',
        pointsBalance: 1000,
        accountStatus: 'ACTIVE',
      );
      expect(customer.toForm(), {
        'customer_id': 'cus_1',
        'login_id': 'sodam',
        'customer_name': '고객',
        'email': 'customer@example.com',
        'phone': '010-1234-5678',
        'address': '서울시',
        'password': ' secret123 ',
      });
      expect(
        customer.toForm(customerId: 'cus_generated')['customer_id'],
        'cus_generated',
      );
      expect(customer.toForm().containsKey('gender'), isFalse);
      expect(customer.toForm().containsKey('points_balance'), isFalse);
      expect(customer.toForm().containsKey('account_status'), isFalse);
    },
  );
}
