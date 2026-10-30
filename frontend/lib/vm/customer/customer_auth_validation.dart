// 기존 고객 API의 필수 항목과 길이 제한에 맞춘 입력 검증.
class CustomerAuthValidation {
  static String? loginId(String? value) {
    final text = value?.trim() ?? '';
    if (text.length < 2 || text.length > 50) {
      return '아이디는 2~50자로 입력해 주세요.';
    }
    return null;
  }

  static String? password(String? value) {
    final text = value ?? '';
    if (text.length < 8 || text.length > 20) {
      return '비밀번호는 8~20자로 입력해 주세요.';
    }
    return null;
  }

  static String? confirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) return '비밀번호를 다시 입력해 주세요.';
    if (value != password) return '비밀번호가 일치하지 않습니다.';
    return null;
  }

  static String? name(String? value) {
    final text = value?.trim() ?? '';
    if (text.length < 2 || text.length > 30) return '이름은 2~30자로 입력해 주세요.';
    return null;
  }

  static String? email(String? value) {
    final text = value?.trim() ?? '';
    if (text.length > 100 ||
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(text)) {
      return '올바른 이메일 주소를 입력해 주세요.';
    }
    return null;
  }

  static String? address(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty || text.length > 500) return '주소를 500자 이내로 입력해 주세요.';
    return null;
  }

  static String? phone(String? value) {
    final text = value?.trim() ?? '';
    final digits = text.replaceAll(RegExp(r'\D'), '');
    if (text.length > 30 ||
        digits.length < 7 ||
        !RegExp(r'^\+?[0-9\s()-]+$').hasMatch(text)) {
      return '올바른 전화번호를 입력해 주세요.';
    }
    return null;
  }
}

// 변경 내용(2026-10-30): 주소 API 결과·상세주소 500자를 검증한다. 출생연도 검증은 제거했다.
