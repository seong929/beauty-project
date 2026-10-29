import '../../model/auth/employee_login.dart';

class AuthState {
  final EmployeeLogin? employee;
  final bool isLoading;
  final String? errorMessage;

  const AuthState({
    this.employee,
    this.isLoading = false,
    this.errorMessage,
  });

  AuthState copyWith({
    EmployeeLogin? employee,
    bool? isLoading,
    String? errorMessage,
    bool clearEmployee = false,
    bool clearErrorMessage = false,
  }) {
    return AuthState(
      employee: clearEmployee
          ? null
          : (employee ?? this.employee),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
    );
  }

  // 로그인 여부 확인
  bool get isLoggedIn => employee != null;

  // 관리자 여부 확인
  bool get isAdmin => employee?.employeeRole == 'ADMIN';

  // 직원 여부 확인
  bool get isStaff => employee?.employeeRole == 'STAFF';
}