import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:beauty_project/model/customer/customers.dart';
import '../customer_providers.dart';

// 회원가입 결과는 로그인한 고객 정보와 분리한다.
class CustomerRegistrationModel extends AsyncNotifier<String?> {
  @override
  FutureOr<String?> build() => null;

  Future<bool> register(Customers registration) async {
    if (state.isLoading) return false;
    state = const AsyncLoading();
    final service = ref.read(customerAuthServiceProvider);
    final result = await AsyncValue.guard(() async {
      await service.register(registration);
      return registration.loginId.trim();
    });
    if (!ref.mounted) return false;
    state = result;
    return !result.hasError;
  }

  void clearError() {
    if (!state.isLoading && state.hasError) state = const AsyncData(null);
  }

  void reset() {
    if (!state.isLoading) state = const AsyncData(null);
  }
}

final customerRegistrationProvider =
    AsyncNotifierProvider<CustomerRegistrationModel, String?>(
      CustomerRegistrationModel.new,
    );
