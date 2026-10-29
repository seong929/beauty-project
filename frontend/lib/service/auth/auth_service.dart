import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../model/auth/employee_login.dart';

class AuthService {
  final String baseUrl;

  const AuthService({
    required this.baseUrl,
  });

  // 직원 및 관리자 공통 로그인
  Future<EmployeeLogin> login({
    required String loginId,
    required String password,
  }) async {
    final url = Uri.parse('$baseUrl/auth/login');

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'login_id': loginId,
        'password': password,
      }),
    );

    final responseData = jsonDecode(
      utf8.decode(response.bodyBytes),
    );

    if (response.statusCode == 200) {
      return EmployeeLogin.fromJson(
        responseData as Map<String, dynamic>,
      );
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

    throw Exception(
      '로그인에 실패했습니다. (${response.statusCode})',
    );
  }
}