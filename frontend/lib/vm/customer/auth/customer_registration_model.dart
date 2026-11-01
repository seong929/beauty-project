// 기능: 로그인 상태와 분리한 회원가입 요청·결과 관리.
// 상태 계층: 변경은 Notifier/AsyncNotifier에서 발행하고 View는 watch, 동작은 read로 연결한다.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:beauty_project/model/customer/customers.dart';
import '../customer_providers.dart';

// 회원가입 결과는 로그인한 고객 정보와 분리한다.
class CustomerRegistrationModel extends AsyncNotifier<String?> {
  /// Function: Provider가 처음 구독될 때 초기 상태 또는 초기 조회 결과를 준비한다.
  @override
  FutureOr<String?> build() => null;

  /// Function: 회원가입 요청 결과를 로그인 세션과 별도 상태로 관리한다.
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
