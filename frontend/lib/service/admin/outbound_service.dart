import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../model/admin/outbound.dart';

class OutboundService {
  final String baseUrl;
  final http.Client _client;

  OutboundService({required this.baseUrl, http.Client? client})
    : _client = client ?? http.Client();

  // 공통 HTTP 헤더
  Map<String, String> _headers(String accessToken) {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };
  }

  // API 오류 메시지 처리
  void _checkResponse(http.Response response, int successCode) {
    if (response.statusCode == successCode) {
      return;
    }

    String message = '요청 처리에 실패했습니다.';

    try {
      final data = jsonDecode(utf8.decode(response.bodyBytes));

      if (data is Map<String, dynamic>) {
        final detail = data['detail'];

        if (detail is String) {
          message = detail;
        }
      }
    } catch (_) {
      // 응답을 JSON으로 해석할 수 없는 경우
    }

    if (response.statusCode == 401) {
      throw Exception('로그인이 만료되었거나 인증에 실패했습니다.');
    }

    if (response.statusCode == 403) {
      throw Exception('출고 관리 권한이 없습니다.');
    }

    throw Exception(message);
  }

  // 출고 대상 주문 목록 조회
  Future<List<OutboundOrder>> fetchPreparingOrders({
    required String accessToken,
  }) async {
    final url = Uri.parse('$baseUrl/staff/order/available').replace(
      queryParameters: {
        'page': '1',
        'count': '100',
        'asc': 'false',
        'statuses': 'PREPARING',
      },
    );

    final response = await _client.get(url, headers: _headers(accessToken));

    _checkResponse(response, 200);

    final data =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

    final orders = data['orders'] as List<dynamic>;

    return orders.map((order) {
      return OutboundOrder.fromJson(order as Map<String, dynamic>);
    }).toList();
  }

  // 출고 처리
  Future<OutboundResult> createOutbound({
    required String accessToken,
    required String orderId,
    required String carrierId,
  }) async {
    final url = Uri.parse('$baseUrl/admin/outbounds');

    final response = await _client.post(
      url,
      headers: _headers(accessToken),
      body: jsonEncode({'order_id': orderId, 'carrier_id': carrierId}),
    );

    _checkResponse(response, 201);

    final data =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

    return OutboundResult.fromJson(data);
  }
}
