class Customers {
  final String customerId;
  final String loginId;
  final String name;
  final String email;
  final String phone;
  final String address;
  final String gender;
  final int pointsBalance;
  final String accountStatus;
  final String password;

  const Customers({
    this.customerId = '',
    required this.loginId,
    required this.name,
    required this.email,
    required this.address,
    required this.phone,
    this.gender = 'UNDISCLOSED',
    this.pointsBalance = 0,
    this.accountStatus = '',
    this.password = '',
  });

  factory Customers.fromJson(Map<String, dynamic> json) {
    return Customers(
      customerId: json['customer_id']?.toString() ?? '',
      loginId: json['login_id']?.toString() ?? '',
      name: json['customer_name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: (json['phone'] ?? json['phone_number'])?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      gender: json['gender']?.toString() ?? 'UNDISCLOSED',
      pointsBalance:
          int.tryParse(json['points_balance']?.toString() ?? '') ?? 0,
      accountStatus: json['account_status']?.toString() ?? '',
    );
  }

  // Customers 객체 → 고객 정보 JSON. 비밀번호와 서버 전용 해시는 제외한다.
  Map<String, dynamic> toJson() {
    return {
    'customer_id': customerId,
      'login_id': loginId,
      'customer_name': name,
      'email': email,
      'phone': phone,
      'address': address,
      'gender': gender,
      'points_balance': pointsBalance,
      'account_status': accountStatus,
    };
  }

  // 기존 회원가입 API에 맞는 일곱 개 폼 필드만 전송한다.
  Map<String, String> toForm({String? customerId}) {
    return {
      'customer_id': customerId ?? this.customerId,
    'login_id': loginId.trim(),
    'password': password,
    'customer_name': name.trim(),
    'email': email.trim(),
    'address': address.trim(),
    'phone': phone.trim(),
  };
  }
}
