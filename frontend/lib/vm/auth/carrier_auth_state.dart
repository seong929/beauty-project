
import '../../model/auth/carrier_login.dart';

class CarrierAuthState {
  final CarrierLogin? carrier;
  final bool isLoading;
  final String? errorMessage;

  const CarrierAuthState({
    this.carrier,
    this.isLoading = false,
    this.errorMessage,
  });

  // 로그인 여부 확인
  bool get isLoggedIn => carrier != null;

  // JWT 접근 토큰
  String? get accessToken => carrier?.accessToken;

  // 로그인한 배송업체 ID
  String? get carrierId => carrier?.carrierId;

  // 로그인한 배송업체 계정 ID
  String? get accountId => carrier?.accountId;

  CarrierAuthState copyWith({
    CarrierLogin? carrier,
    bool? isLoading,
    String? errorMessage,
    bool clearCarrier = false,
    bool clearError = false,
  }) {
    return CarrierAuthState(
      carrier: clearCarrier ? null : (carrier ?? this.carrier),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError
          ? null
          : (errorMessage ?? this.errorMessage),
    );
  }
}
