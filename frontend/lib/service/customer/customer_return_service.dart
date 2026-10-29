import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:beauty_project/model/customer/return_request.dart';
import 'customer_auth_service.dart';

class ReturnResultUncertain extends CustomerAuthException {
  const ReturnResultUncertain()
    : super('반품 신청 결과를 확인하지 못했습니다. 중복 신청을 방지하기 위해 반품 내역을 먼저 새로고침해 주세요.');
}

class CustomerReturnService {
  const CustomerReturnService({required this.client, required this.baseUrl});
  final http.Client client;
  final Uri baseUrl;

  Future<List<CustomerReturnRequest>> fetch(
    String customerId, {
    String? itemId,
  }) async {
    final data = await _request(
      () => client.get(
        baseUrl
            .resolve('return_requests')
            .replace(
              queryParameters: {
                'customer_id': customerId,
                'order_item_id': ?itemId,
              },
            ),
      ),
    );
    final rows = data['result'];
    if (rows is! List) {
      throw const CustomerAuthException('반품 조회 응답을 확인할 수 없습니다.');
    }
    return [for (final row in rows) _parse(row, customerId, itemId: itemId)];
  }

  Future<CustomerReturnRequest> create({
    required String customerId,
    required String itemId,
    required String reason,
    required int quantity,
  }) async {
    if (customerId.isEmpty ||
        itemId.isEmpty ||
        reason.trim().isEmpty ||
        reason.trim().length > 500 ||
        quantity < 1) {
      throw const CustomerAuthException('반품할 상품, 수량과 사유를 확인해 주세요.');
    }
    final data = await _request(
      () => client.post(
        baseUrl.resolve('return_requests'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'customer_id': customerId,
          'order_item_id': itemId,
          'return_reason': reason.trim(),
          'return_quantity': quantity,
        }),
      ),
      mutation: true,
    );
    try {
      final request = _parse(data, customerId, itemId: itemId);
      if (request.quantity != quantity ||
          request.reason != reason.trim() ||
          request.status != 'REQUESTED') {
        throw const ReturnResultUncertain();
      }
      return request;
    } on CustomerAuthException {
      throw const ReturnResultUncertain();
    }
  }

  CustomerReturnRequest _parse(
    dynamic row,
    String customerId, {
    String? itemId,
  }) {
    if (row is! Map<String, dynamic> ||
        row['customer_id'] != customerId ||
        (itemId != null && row['order_item_id'] != itemId) ||
        [
          'return_id',
          'order_item_id',
          'return_reason',
          'return_status',
          'refund_status',
          'pickup_status',
        ].any(
          (field) => row[field] is! String || (row[field] as String).isEmpty,
        ) ||
        (int.tryParse(row['return_quantity']?.toString() ?? '') ?? 0) < 1) {
      throw const CustomerAuthException('반품 응답을 확인할 수 없습니다.');
    }
    return CustomerReturnRequest.fromJson(row);
  }

  Future<Map<String, dynamic>> _request(
    Future<http.Response> Function() send, {
    bool mutation = false,
  }) async {
    try {
      final response = await send().timeout(const Duration(seconds: 15));
      if (response.statusCode >= 500) {
        if (mutation) throw const ReturnResultUncertain();
        throw const CustomerAuthException('반품 서버에 연결할 수 없습니다. 다시 조회해 주세요.');
      }
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data is! Map<String, dynamic>) throw const FormatException();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw CustomerAuthException(
          response.statusCode == 404
              ? '반품 기능 또는 주문상품을 찾을 수 없습니다. 서버 연결과 구매 내역을 확인해 주세요.'
              : data['detail'] is String
              ? data['detail'] as String
              : '반품 요청을 처리하지 못했습니다.',
        );
      }
      return data;
    } on TimeoutException {
      if (mutation) throw const ReturnResultUncertain();
      throw const CustomerAuthException('반품 조회 시간이 초과되었습니다.');
    } on http.ClientException {
      if (mutation) throw const ReturnResultUncertain();
      throw const CustomerAuthException('네트워크 연결을 확인해 주세요.');
    } on FormatException {
      if (mutation) throw const ReturnResultUncertain();
      throw const CustomerAuthException('반품 응답을 확인할 수 없습니다.');
    }
  }
}
