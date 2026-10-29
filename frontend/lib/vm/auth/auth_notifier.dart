import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../service/auth/auth_service.dart';
import 'auth_state.dart';

// 로그인 API 서비스 Provider
final authServiceProvider = Provider<AuthService>((ref) {
  return const AuthService(
    baseUrl: 'http://127.0.0.1:8000',
  );
});

// 로그인 상태 관리 Notifier
class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    return const AuthState();
  }

  // 직원 및 관리자 공통 로그인
  Future<bool> login({
    required String loginId,
    required String password,
  }) async {
    state = state.copyWith(
      isLoading: true,
      clearErrorMessage: true,
    );

    try {
      final authService = ref.read(authServiceProvider);

      final employee = await authService.login(
        loginId: loginId,
        password: password,
      );

      state = state.copyWith(
        employee: employee,
        isLoading: false,
        clearErrorMessage: true,
      );

      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        clearEmployee: true,
        errorMessage: e.toString().replaceFirst(
          'Exception: ',
          '',
        ),
      );

      return false;
    }
  }

  // 로그아웃
  void logout() {
    state = const AuthState();
  }
}

// 로그인 상태 Provider
final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);