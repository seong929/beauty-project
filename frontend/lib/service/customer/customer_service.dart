import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:beauty_project/model/customer/customers.dart';
import 'customer_auth_service.dart';

// 기존 고객 조회·등록·수정·탈퇴 API를 유지한다. 화면 상태는 VM이 관리한다.
class CustomerService {
  CustomerService({required this.authService});

  final CustomerAuthService authService;

  Future<List<Customers>> fetchCustomers() async {
    final data = await _request(
      () => authService.client.get(
        authService.baseUrl.resolve('customer_select'),
        headers: {'Accept': 'application/json'},
      ),
    );
    final rows = data['result'];
    if (rows is! List || rows.any((row) => row is! Map<String, dynamic>)) {
      throw const CustomerAuthException('서버 응답을 확인할 수 없습니다. 다시 시도해 주세요.');
    }
    return rows
        .map((row) => Customers.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<void> insertCustomer(Customers customer) async {
    await authService.register(customer);
  }

  Future<void> updateCustomer(Customers customer) async {
    _requireCustomerId(customer.customerId);
    await _request(
      () => authService.client.put(
        authService.baseUrl
            .resolve('customer_update')
            .replace(
              queryParameters: {'customer_id': customer.customerId.trim()},
            ),
        headers: {'Accept': 'application/json'},
        body: {
          'customer_name': customer.name.trim(),
          'email': customer.email.trim(),
          'address': customer.address.trim(),
          'phone': customer.phone.trim(),
          'gender': customer.gender,
        },
      ),
      mutation: true,
    );
  }

  // 원본 API의 오탈자 경로를 유지한다. 서버는 행 삭제 대신 탈퇴 이력을 저장한다.
  Future<void> deleteCustomer(String customerId) async {
    _requireCustomerId(customerId);
    await _request(
      () => authService.client.post(
        authService.baseUrl.resolve('customer_delect'),
        headers: {'Accept': 'application/json'},
        body: {'customer_id': customerId.trim()},
      ),
      mutation: true,
    );
  }

  void _requireCustomerId(String customerId) {
    if (customerId.trim().isEmpty) {
      throw const CustomerAuthException('고객번호를 확인해 주세요.');
    }
  }

  Future<Map<String, dynamic>> _request(
    Future<http.Response> Function() send, {
    bool mutation = false,
  }) async {
    try {
      final response = await send().timeout(authService.timeout);
      if (response.statusCode >= 500) {
        throw const CustomerAuthException('서버에 연결할 수 없습니다. 잠시 후 다시 시도해 주세요.');
      }
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data is! Map<String, dynamic>) throw const FormatException();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final detail = data['detail'];
        throw CustomerAuthException(
          detail is String ? detail : '입력한 정보를 다시 확인해 주세요.',
        );
      }
      if (mutation && data['result'] != 'OK') {
        throw const CustomerAuthException('요청을 처리하지 못했습니다. 다시 시도해 주세요.');
      }
      return data;
    } on TimeoutException {
      throw const CustomerAuthException('연결 시간이 초과되었습니다. 다시 시도해 주세요.');
    } on http.ClientException {
      throw const CustomerAuthException('서버에 연결할 수 없습니다. 네트워크를 확인해 주세요.');
    } on FormatException {
      throw const CustomerAuthException('서버 응답을 확인할 수 없습니다. 다시 시도해 주세요.');
    }
  }
}

// 변경 내용(2026-10-30): 개인정보 수정에서 성별을 저장하며 출생연도는 전송하지 않는다.
