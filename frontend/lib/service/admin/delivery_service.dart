import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../model/admin/delivery.dart';

class DeliveryService {
  final String baseUrl;
  final http.Client _client;

  DeliveryService({required this.baseUrl, http.Client? client})
    : _client = client ?? http.Client();

  // HTTP 요청 헤더
  Map<String, String> _headers(String accessToken) {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };
  }

  // HTTP 응답 상태 확인
  void _checkResponse(http.Response response) {
    if (response.statusCode == 200) {
      return;
    }

    String message = '배송 목록 조회에 실패했습니다.';

    try {
      final data = jsonDecode(utf8.decode(response.bodyBytes));

      if (data is Map<String, dynamic>) {
        final detail = data['detail'];

        if (detail is String) {
          message = detail;
        }
      }
    } catch (_) {
      // 오류 응답이 JSON이 아닌 경우 기본 메시지 사용
    }

    if (response.statusCode == 401) {
      throw Exception('로그인이 만료되었거나 인증에 실패했습니다.');
    }

    if (response.statusCode == 403) {
      throw Exception('배송 목록 조회 권한이 없습니다.');
    }

    throw Exception(message);
  }

  // 배송 목록 조회
  Future<List<Delivery>> fetchDeliveryList({
    required String accessToken,
    bool isStaff = false,
  }) async {
    final url = Uri.parse('$baseUrl/${isStaff ? 'staff' : 'admin'}/deliveries');

    final response = await _client.get(url, headers: _headers(accessToken));

    _checkResponse(response);

    // UTF-8 디코딩
    final data = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;

    // JSON 데이터를 Delivery 모델로 변환
    final deliveries = data.map((item) {
      return Delivery.fromJson(item as Map<String, dynamic>);
    }).toList();

    return deliveries;
  }
}
