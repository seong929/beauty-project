
class CarrierLogin {
  final String accessToken;
  final String tokenType;
  final int expiresIn;
  final String accountId;
  final String carrierId;

  const CarrierLogin({
    required this.accessToken,
    required this.tokenType,
    required this.expiresIn,
    required this.accountId,
    required this.carrierId,
  });

  factory CarrierLogin.fromJson(Map<String, dynamic> json) {
    return CarrierLogin(
      accessToken: json['access_token'] as String,
      tokenType: json['token_type'] as String,
      expiresIn: json['expires_in'] as int,
      accountId: json['account_id'] as String,
      carrierId: json['carrier_id'] as String,
    );
  }
}
