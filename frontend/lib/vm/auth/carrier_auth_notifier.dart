import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../service/api_config.dart';

import '../../service/auth/carrier_auth_service.dart';
import 'carrier_auth_state.dart';

// 배송업체 인증 Provider
final carrierAuthProvider =
    NotifierProvider<CarrierAuthNotifier, CarrierAuthState>(
      CarrierAuthNotifier.new,
    );

class CarrierAuthNotifier extends Notifier<CarrierAuthState> {
  // FastAPI 서버 주소
  static String get baseUrl => ApiConfig.baseUrl;

  final CarrierAuthService _authService = CarrierAuthService(baseUrl: baseUrl);

  @override
  CarrierAuthState build() {
    return const CarrierAuthState();
  }

  // 배송업체 로그인
  Future<bool> login({
    required String loginId,
    required String password,
  }) async {
    if (state.isLoading) {
      return false;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final carrier = await _authService.login(
        loginId: loginId,
        password: password,
      );

      state = state.copyWith(
        carrier: carrier,
        isLoading: false,
        clearError: true,
      );

      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        clearCarrier: true,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );

      return false;
    }
  }

  // 배송업체 로그아웃
  void logout() {
    state = const CarrierAuthState();
  }
}
