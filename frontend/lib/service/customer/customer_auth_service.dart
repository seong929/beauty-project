import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../model/customer/customers.dart';

Uri customerApiBaseUrl() {
  const configured = String.fromEnvironment('API_BASE_URL');
  final address = configured.isNotEmpty
      ? configured
      : !kIsWeb && defaultTargetPlatform == TargetPlatform.android
      ? 'http://10.0.2.2:8000'
      : 'http://127.0.0.1:8000';
  return Uri.parse(address.endsWith('/') ? address : '$address/');
}

class CustomerAuthException implements Exception {
  const CustomerAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class CustomerAuthService {
  CustomerAuthService({
    http.Client? client,
    Uri? baseUrl,
    this.timeout = const Duration(seconds: 15),
  }) : client = client ?? http.Client(),
       baseUrl = _normalizeBaseUrl(baseUrl ?? customerApiBaseUrl()),
       _ownsClient = client == null;

  final http.Client client;
  final Uri baseUrl;
  final Duration timeout;
  final bool _ownsClient;

  static Uri _normalizeBaseUrl(Uri url) {
    return url.path.endsWith('/') ? url : url.replace(path: '${url.path}/');
  }

  void dispose() {
    if (_ownsClient) client.close();
  }

  // 가입 시 저장한 비밀번호 해시를 검증하는 고객 전용 로그인 API.
  Future<Customers> login({
    required String loginId,
    required String password,
  }) async {
    final response = await _post({
      'login_id': loginId.trim(),
      'password': password,
    }, path: 'customer_login');
    final profile = response['customer'];
    if (profile is! Map<String, dynamic>) {
      throw const CustomerAuthException('로그인한 고객 정보를 확인할 수 없습니다.');
    }
    final customer = Customers.fromJson(profile);
    if (customer.customerId.isEmpty ||
        customer.loginId != loginId.trim() ||
        customer.accountStatus != 'ACTIVE') {
      throw const CustomerAuthException('로그인한 고객 정보를 확인할 수 없습니다.');
    }
    return customer;
  }

  Future<String> register(Customers registration) async {
    // 기존 API는 고객번호를 필수로 받으므로 앱에서 충돌 가능성이 낮은 번호를 만든다.
    final random = Random.secure();
    final suffix = List.generate(
      16,
      (_) => random.nextInt(256),
    ).map((value) => value.toRadixString(16).padLeft(2, '0')).join();
    final generatedId = 'cus_$suffix';
    final result = await _post(registration.toForm(customerId: generatedId));
    final customerId = result['customer_id'];
    if (customerId != generatedId) {
      throw const CustomerAuthException('회원가입 결과를 확인할 수 없습니다. 다시 시도해 주세요.');
    }
    return generatedId;
  }

  Future<Map<String, dynamic>> _post(
    Map<String, String> form, {
    String path = 'customer_upload',
  }) async {
    try {
      final response = await client
          .post(
            baseUrl.resolve(path),
            headers: {'Accept': 'application/json'},
            body: form,
          )
          .timeout(timeout);
      if (response.statusCode >= 500) {
        throw const CustomerAuthException('서버에 연결할 수 없습니다. 잠시 후 다시 시도해 주세요.');
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Invalid API response');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final detail = decoded['detail'];
        throw CustomerAuthException(
          detail is String ? detail : '입력한 정보를 다시 확인해 주세요.',
        );
      }
      if (decoded['result'] != 'OK') {
        throw const CustomerAuthException('요청을 처리하지 못했습니다. 다시 시도해 주세요.');
      }
      return decoded;
    } on TimeoutException {
      throw const CustomerAuthException('연결 시간이 초과되었습니다. 다시 시도해 주세요.');
    } on http.ClientException {
      throw const CustomerAuthException('서버에 연결할 수 없습니다. 네트워크를 확인해 주세요.');
    } on FormatException {
      throw const CustomerAuthException('서버 응답을 확인할 수 없습니다. 다시 시도해 주세요.');
    }
  }
}
