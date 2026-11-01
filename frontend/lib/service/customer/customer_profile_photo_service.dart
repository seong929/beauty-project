// 기능: 휴대폰에서 선택한 프로필 사진을 고객별로 현재 기기에 저장한다.
// 상품 이미지·Firebase·고객 API와 분리하며 로그아웃해도 사진을 유지한다.
import 'dart:convert';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';

class CustomerProfilePhotoService {
  CustomerProfilePhotoService({
    Future<SharedPreferences> Function()? preferences,
  }) : _preferences = preferences ?? SharedPreferences.getInstance;

  static const maxBytes = 2 * 1024 * 1024;
  final Future<SharedPreferences> Function() _preferences;

  String _key(String customerId) {
    if (customerId.trim().isEmpty) {
      throw const FormatException('고객번호를 확인해 주세요.');
    }
    return 'customer-profile-photo.v1.${base64Url.encode(utf8.encode(customerId))}';
  }

  /// Function: 고객별 저장 사진을 읽는다. 저장된 경로 대신 이미지 자체를 보관한다.
  Future<Uint8List?> load(String customerId) async {
    final preferences = await _preferences().timeout(
      const Duration(seconds: 5),
    );
    final value = preferences.getString(_key(customerId));
    if (value == null) return null;
    final bytes = base64Decode(value);
    _validateSize(bytes);
    return bytes;
  }

  /// Function: 사진 저장 또는 기본 프로필로 되돌리기를 처리한다.
  Future<void> save(String customerId, Uint8List? bytes) async {
    final key = _key(customerId);
    final preferences = await _preferences().timeout(
      const Duration(seconds: 5),
    );
    final bool saved;
    if (bytes == null) {
      saved = await preferences.remove(key);
    } else {
      _validateSize(bytes);
      saved = await preferences.setString(key, base64Encode(bytes));
    }
    if (!saved) throw StateError('프로필 사진을 저장하지 못했습니다.');
  }

  static void _validateSize(Uint8List bytes) {
    if (bytes.isEmpty || bytes.length > maxBytes) {
      throw const FormatException('2MB 이하의 사진을 선택해 주세요.');
    }
  }
}
