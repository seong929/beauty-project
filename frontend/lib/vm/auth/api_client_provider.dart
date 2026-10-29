import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'auth_notifier.dart';

/// 공유 클라이언트는 요청 시점의 로그인 정보를 사용합니다.
final apiClientProvider = Provider<http.Client>((ref) {
  final client = _AuthenticatedClient(
    token: () => ref.read(authProvider).employee?.accessToken,
    onExpired: (token) {
      // 이전 세션의 늦은 응답이 새 세션을 로그아웃시키지 않도록 합니다.
      if (ref.read(authProvider).employee?.accessToken == token) {
        ref.read(authProvider.notifier).expireSession();
      }
    },
  );
  ref.onDispose(client.close);
  return client;
});

class _AuthenticatedClient extends http.BaseClient {
  _AuthenticatedClient({required this.token, required this.onExpired});

  final String? Function() token;
  final void Function(String) onExpired;
  final http.Client _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final currentToken = token();
    request.headers.remove('Authorization');
    if (currentToken != null && currentToken.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $currentToken';
    }
    request.headers.putIfAbsent('Accept', () => 'application/json');
    if (request.method != 'GET' && request.method != 'HEAD') {
      request.headers.putIfAbsent('Content-Type', () => 'application/json');
    }
    try {
      final response = await _inner
          .send(request)
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 401 &&
          currentToken != null &&
          currentToken.isNotEmpty) {
        scheduleMicrotask(() => onExpired(currentToken));
      }
      return response;
    } on TimeoutException {
      throw Exception('서버 응답 시간이 초과되었습니다.');
    } on http.ClientException {
      throw Exception('서버에 연결할 수 없습니다. 네트워크와 서버 상태를 확인해 주세요.');
    }
  }

  @override
  void close() => _inner.close();
}
