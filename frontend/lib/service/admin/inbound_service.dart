import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../model/admin/inbound.dart';

class InboundService {
  final String baseUrl;
  final http.Client _client;

  InboundService({required this.baseUrl, http.Client? client})
    : _client = client ?? http.Client();

  // 본사 직원 입고 등록
  Future<InboundCreateResponse> createInbound({
    required InboundCreateRequest request,
    required String accessToken,
  }) async {
    final uri = Uri.parse('$baseUrl/admin/inbounds');

    final response = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(request.toJson()),
    );

    final responseBody = utf8.decode(response.bodyBytes);

    Map<String, dynamic> json;

    try {
      json = jsonDecode(responseBody) as Map<String, dynamic>;
    } on FormatException {
      throw Exception(
        '서버 응답을 처리할 수 없습니다. '
        '(HTTP ${response.statusCode})',
      );
    }

    if (response.statusCode == 201) {
      return InboundCreateResponse.fromJson(json);
    }

    final detail = json['detail'];

    if (detail is String) {
      throw Exception(detail);
    }

    if (response.statusCode == 401) {
      throw Exception('로그인 인증이 필요합니다. 다시 로그인해 주세요.');
    }

    if (response.statusCode == 403) {
      throw Exception('입고 등록 권한이 없습니다.');
    }

    if (response.statusCode == 422) {
      throw Exception('입고 정보를 확인해 주세요.');
    }

    throw Exception(
      '입고 등록에 실패했습니다. '
      '(HTTP ${response.statusCode})',
    );
  }
}
