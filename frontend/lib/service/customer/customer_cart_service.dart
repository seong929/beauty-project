import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'customer_auth_service.dart';

class CustomerCartService {
  const CustomerCartService({required this.client, required this.baseUrl});
  final http.Client client;
  final Uri baseUrl;

  Future<List<Map<String, dynamic>>> fetch(String customerId) async {
    final data = await _request(
      () => client.get(
        baseUrl
            .resolve('incart_select')
            .replace(queryParameters: {'customer_id': customerId}),
        headers: {'Accept': 'application/json'},
      ),
    );
    final rows = data['result'];
    if (rows is! List ||
        rows.any(
          (row) =>
              row is! Map<String, dynamic> ||
              row['cosmetic_id'] is! String ||
              (row['cosmetic_id'] as String).isEmpty ||
              row['customer_id'] != customerId,
        )) {
      throw const CustomerAuthException('장바구니 응답을 확인할 수 없습니다.');
    }
    return rows.cast<Map<String, dynamic>>();
  }

  Future<void> add(String customerId, String cosmeticId) async {
    try {
      await _request(
        () => client.post(
          baseUrl.resolve('incart_upload'),
          headers: {'Accept': 'application/json'},
          body: {'customer_id': customerId, 'cosmetic_id': cosmeticId},
        ),
        mutation: true,
      );
    } on _CartHttpException catch (error) {
      // 같은 상품을 다시 담는 경우도 DB에 실제로 존재하는지 확인한 뒤 처리한다.
      if (error.status == 409 &&
          (await fetch(
            customerId,
          )).any((row) => row['cosmetic_id'] == cosmeticId)) {
        return;
      }
      rethrow;
    }
  }

  Future<void> remove(String customerId, String cosmeticId) async {
    await _request(
      () => client.delete(
        baseUrl.resolve('incart_delete'),
        headers: {'Accept': 'application/json'},
        body: {'customer_id': customerId, 'cosmetic_id': cosmeticId},
      ),
      mutation: true,
    );
  }

  Future<Map<String, dynamic>> _request(
    Future<http.Response> Function() send, {
    bool mutation = false,
  }) async {
    try {
      final response = await send().timeout(const Duration(seconds: 15));
      if (response.statusCode >= 500) {
        throw const CustomerAuthException(
          '장바구니 서버에 연결할 수 없습니다. 잠시 후 다시 시도해 주세요.',
        );
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) throw const FormatException();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw _CartHttpException(
          response.statusCode,
          decoded['detail'] is String
              ? decoded['detail'] as String
              : '장바구니 요청을 처리하지 못했습니다.',
        );
      }
      if (mutation && decoded['result'] != 'OK') {
        throw const CustomerAuthException('장바구니 저장 결과를 확인할 수 없습니다.');
      }
      return decoded;
    } on TimeoutException {
      throw const CustomerAuthException('장바구니 연결 시간이 초과되었습니다. 다시 조회해 주세요.');
    } on http.ClientException {
      throw const CustomerAuthException('네트워크 연결을 확인한 뒤 장바구니를 다시 조회해 주세요.');
    } on FormatException {
      throw const CustomerAuthException('장바구니 응답을 확인할 수 없습니다.');
    }
  }
}

class _CartHttpException extends CustomerAuthException {
  const _CartHttpException(this.status, super.message);
  final int status;
}
