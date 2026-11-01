// 기능: 고객 API 주소·HTTP 클라이언트·서비스 의존성 주입.
// 상태 계층: 변경은 Notifier/AsyncNotifier에서 발행하고 View는 watch, 동작은 read로 연결한다.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'package:beauty_project/service/customer/customer_auth_service.dart';
import 'package:beauty_project/service/customer/customer_service.dart';

final customerApiBaseUrlProvider = Provider<Uri>((ref) => customerApiBaseUrl());

final customerHttpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final customerAuthServiceProvider = Provider<CustomerAuthService>((ref) {
  return CustomerAuthService(
    client: ref.watch(customerHttpClientProvider),
    baseUrl: ref.watch(customerApiBaseUrlProvider),
  );
});

final customerServiceProvider = Provider<CustomerService>((ref) {
  return CustomerService(authService: ref.watch(customerAuthServiceProvider));
});
