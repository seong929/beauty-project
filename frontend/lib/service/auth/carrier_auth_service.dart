
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../model/auth/carrier_login.dart';

class CarrierAuthService {
  final String baseUrl;

  const CarrierAuthService({
    required this.baseUrl,
  });

  // 배송업체 로그인
  Future<CarrierLogin> login({
    required String loginId,
    required String password,
  }) async {
    final uri = Uri.parse('$baseUrl/delivery/auth/login');

    try {
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode({
          'login_id': loginId,
          'password': password,
        }),
      );

      final decoded = jsonDecode(
        utf8.decode(response.bodyBytes),
      );

      if (response.statusCode == 200) {
        return CarrierLogin.fromJson(
          decoded as Map<String, dynamic>,
        );
      }

      String message = '배송업체 로그인에 실패했습니다.';

      if (decoded is Map<String, dynamic>) {
        final detail = decoded['detail'];

        if (detail is String) {
          message = detail;
        }
      }

      throw Exception(message);
    } on http.ClientException {
      throw Exception(
        '서버에 연결할 수 없습니다. FastAPI 실행 상태를 확인해 주세요.',
      );
    } on FormatException {
      throw Exception(
        '서버 응답 형식이 올바르지 않습니다.',
      );
    }
  }
}
