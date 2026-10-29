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
