class EmployeeLogin {
  final String accessToken;
  final String tokenType;
  final int expiresIn;
  final String employeeId;
  final String employeeRole;

  const EmployeeLogin({
    required this.accessToken,
    required this.tokenType,
    required this.expiresIn,
    required this.employeeId,
    required this.employeeRole,
  });

  factory EmployeeLogin.fromJson(Map<String, dynamic> json) {
    return EmployeeLogin(
      accessToken: json['access_token'] as String,
      tokenType: json['token_type'] as String,
      expiresIn: json['expires_in'] as int,
      employeeId: json['employee_id'] as String,
      employeeRole: json['employee_role'] as String,
    );
  }
}