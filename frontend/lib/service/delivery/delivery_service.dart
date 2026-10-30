import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../model/delivery/delivery.dart';
import '../../model/delivery/return_pickup.dart';

class DeliveryService {
  final String baseUrl;

  const DeliveryService({required this.baseUrl});

  // HTTP 요청 헤더
  Map<String, String> _headers(String accessToken) {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };
  }

  // HTTP 오류 처리
  void _checkResponse(http.Response response, {required int successStatus}) {
    if (response.statusCode == successStatus) {
      return;
    }

    String message = '배송 API 요청에 실패했습니다.';

    try {
      final data = jsonDecode(utf8.decode(response.bodyBytes));

      if (data is Map<String, dynamic>) {
        final detail = data['detail'];

        if (detail is String) {
          message = detail;
        }
      }
    } catch (_) {
      // JSON 형식이 아닌 오류 응답 처리
    }

    if (response.statusCode == 401) {
      throw Exception('로그인이 만료되었거나 인증에 실패했습니다.');
    }

    if (response.statusCode == 403) {
      throw Exception('배송 처리 권한이 없습니다.');
    }

    throw Exception(message);
  }

  // 배송 목록 조회
  Future<List<Delivery>> fetchDeliveryList({
    required String accessToken,
  }) async {
    final url = Uri.parse('$baseUrl/delivery/deliveries');

    final response = await http.get(url, headers: _headers(accessToken));

    _checkResponse(response, successStatus: 200);

    final data = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;

    return data.map((item) {
      return Delivery.fromJson(item as Map<String, dynamic>);
    }).toList();
  }

  // 배송 상태 변경
  Future<DeliveryStatusResult> updateDeliveryStatus({
    required String accessToken,
    required String deliveryId,
    required String deliveryStatus,
  }) async {
    final url = Uri.parse(
      '$baseUrl/delivery/deliveries/'
      '${Uri.encodeComponent(deliveryId)}/status',
    );

    final response = await http.patch(
      url,
      headers: _headers(accessToken),
      body: jsonEncode({'delivery_status': deliveryStatus}),
    );

    _checkResponse(response, successStatus: 200);

    final data =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

    return DeliveryStatusResult.fromJson(data);
  }

  Future<List<ReturnPickup>> fetchReturnPickups({
    required String accessToken,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/delivery/return-pickups'),
      headers: _headers(accessToken),
    );
    _checkResponse(response, successStatus: 200);
    return (jsonDecode(utf8.decode(response.bodyBytes)) as List)
        .map((item) => ReturnPickup.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> completeReturnPickup({
    required String accessToken,
    required String returnId,
  }) async {
    final response = await http.patch(
      Uri.parse(
        '$baseUrl/delivery/return-pickups/${Uri.encodeComponent(returnId)}/complete',
      ),
      headers: _headers(accessToken),
    );
    _checkResponse(response, successStatus: 200);
  }
}
