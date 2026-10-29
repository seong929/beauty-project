import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../../model/auth/employee_login.dart';

class AuthService {
  final String baseUrl;

  const AuthService({required this.baseUrl});

  // 직원 및 관리자 공통 로그인
  Future<EmployeeLogin> login({
    required String loginId,
    required String password,
  }) async {
    final url = Uri.parse('$baseUrl/auth/login');

    late http.Response response;
    try {
      response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'login_id': loginId, 'password': password}),
          )
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw Exception('서버 응답 시간이 초과되었습니다.');
    } on http.ClientException {
      throw Exception('서버에 연결할 수 없습니다. 네트워크와 서버 상태를 확인해 주세요.');
    }

    if (response.statusCode == 200) {
      final responseData = jsonDecode(utf8.decode(response.bodyBytes));
      return EmployeeLogin.fromJson(responseData as Map<String, dynamic>);
    }

    if (response.statusCode == 401) {
      throw Exception('아이디 또는 비밀번호가 올바르지 않습니다.');
    }

    if (response.statusCode == 403) {
      throw Exception('로그인 권한이 없는 계정입니다.');
    }

    if (response.statusCode == 503) {
      throw Exception('인증 서버에 문제가 발생했습니다.');
    }

    throw Exception('로그인에 실패했습니다. (${response.statusCode})');
  }
}
