import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../customer_auth_validation.dart';
import '../customer_providers.dart';

class LoginIdAvailability {
  const LoginIdAvailability({
    this.loginId = '',
    this.checking = false,
    this.available,
    this.error,
  });
  final String loginId;
  final bool checking;
  final bool? available;
  final String? error;
  bool confirmed(String input) =>
      !checking && available == true && loginId == input.trim();
}

class LoginIdAvailabilityHandler extends Notifier<LoginIdAvailability> {
  int _revision = 0;
  @override
  LoginIdAvailability build() => const LoginIdAvailability();

  void edit(String value) {
    _revision++;
    state = LoginIdAvailability(loginId: value.trim());
  }

  Future<void> check(String input) async {
    final value = input.trim();
    final validation = CustomerAuthValidation.loginId(value);
    final revision = ++_revision;
    if (validation != null) {
      state = LoginIdAvailability(loginId: value, error: validation);
      return;
    }
    state = LoginIdAvailability(loginId: value, checking: true);
    try {
      final available = await ref
          .read(customerAuthServiceProvider)
          .isLoginIdAvailable(value);
      if (ref.mounted && revision == _revision) {
        state = LoginIdAvailability(loginId: value, available: available);
      }
    } catch (error) {
      if (ref.mounted && revision == _revision) {
        state = LoginIdAvailability(loginId: value, error: error.toString());
      }
    }
  }
}

final loginIdAvailabilityProvider =
    NotifierProvider.autoDispose<
      LoginIdAvailabilityHandler,
      LoginIdAvailability
    >(LoginIdAvailabilityHandler.new);

// 변경 내용(2026-10-30): 아이디 변경 시 확인 결과를 취소하고 이전 비동기 응답을 무시한다.
