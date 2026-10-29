import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../model/staff/staff_cosmetic.dart';
import '../../model/staff/staff_product_inventory.dart';
import '../../model/staff/staff_inventory_status.dart';
import '../../model/staff/staff_inventory_history.dart';
import 'staff_inventory_http_client.dart';

/// 인증, 네트워크 오류, 서버 응답 오류를 구분하기 위한 예외.
class StaffInventoryApiException implements Exception {
  final String message;
  final int? statusCode;

  const StaffInventoryApiException(this.message, [this.statusCode]);

  @override
  String toString() => message;
}

/// HTTP 접근은 Service, 비동기 상태는 Riverpod ViewModel이 담당합니다.
/// 테스트 JWT 또는 서버가 발급한 테스트 쿠키를 외부에 노출하지 않습니다.
class StaffInventoryService {
  StaffInventoryService({
    required String baseUrl,
    this.enableTemporaryAuth = false,
    String? accessToken,
    http.Client? client,
  })  : baseUrl = baseUrl.replaceFirst(RegExp(r'/+$'), ''),
        _accessToken = accessToken,
        _client = client ?? createStaffInventoryHttpClient();

  final String baseUrl;
  final bool enableTemporaryAuth;
  final http.Client _client;
  String? _accessToken;
  String? _temporarySessionCookie;

  /// 추후 로그인 성공 시 JWT 연결에 사용합니다.
  void setLoginAccessToken(String? value) {
    _accessToken = value;
    _temporarySessionCookie = null;
  }

  /// 백엔드 통신 상태를 인증과 독립적으로 확인합니다.
  /// Web에서는 CORS 차단도 네트워크 오류로 나타나므로 브라우저 콘솔도 확인합니다.
  Future<void> checkServerHealth() async {
    final uri = Uri.parse('$baseUrl/health');
    debugPrint('[STAFF API] GET $uri (health probe)');
    try {
      final response = await _client.get(
        uri,
        headers: const {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 8));
      debugPrint('[STAFF API] GET /health -> HTTP ${response.statusCode}');
      if (response.statusCode != 200) {
        throw StaffInventoryApiException(
          'FastAPI /health 요청이 HTTP ${response.statusCode}를 반환했습니다.',
          response.statusCode,
        );
      }
      final decoded = _decodeResponse(response);
      if (decoded is! Map || decoded['status'] != 'ok') {
        throw const StaffInventoryApiException(
          'GET /health 응답이 예상한 {"status":"ok"} 형식이 아닙니다.',
        );
      }
    } on StaffInventoryApiException {
      rethrow;
    } catch (error) {
      debugPrint('[STAFF API] GET /health failed: $error');
      throw StaffInventoryApiException(
        'GET $uri 연결 실패: $error. '
        '웹에서 요청이 보이지 않으면 실행 주소·개발자 도구 Network·CORS를 확인하세요.',
      );
    }
  }

  /// test_ui.dart에서 화면을 열기 전에 한 번 호출합니다.
  /// ON: POST /tmp/staff-auth-grant (JWT 또는 Set-Cookie 지원)
  /// OFF: 임시 인증 없이 로그인으로 받은 JWT만 사용합니다.
  Future<void> initializeAuthentication() async {
    if (!enableTemporaryAuth) {
      if (_accessToken == null || _accessToken!.trim().isEmpty) {
        throw const StaffInventoryApiException(
          '임시 인증이 OFF입니다. 로그인 후 발급된 직원 JWT를 설정하세요.',
        );
      }
      // 추후 실제 로그인으로 전달받은 JWT도 서버에서 검증합니다.
      await _verifyStaffAuthorization();
      return;
    }

    // 재시도 시 직전 임시 인증 상태를 재사용하지 않습니다.
    _temporarySessionCookie = null;
    _accessToken = null;

    late http.Response response;
    final authUri = Uri.parse('$baseUrl/tmp/staff-auth-grant');
    debugPrint('[STAFF API] POST $authUri');
    try {
      response = await _client.post(
        authUri,
        headers: const {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 12));
    } catch (error) {
      throw StaffInventoryApiException(
        '임시 인증 요청 실패: $error. '
        'Flutter Web이라면 백엔드 CORS 설정과 실행 주소(127.0.0.1)를 확인하세요.',
      );
    }

    debugPrint('[STAFF API] POST /tmp/staff-auth-grant -> HTTP ${response.statusCode}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StaffInventoryApiException(
        '임시 직원 인증 POST 실패 (${response.statusCode}): '
        '${_errorDetail(response)}',
        response.statusCode,
      );
    }

    // 백엔드가 JWT를 반환하는 경우 (현재 첨부된 백엔드는 쿠키 방식).
    final body = _decodeResponse(response);
    if (body is Map && body['access_token'] is String &&
        (body['access_token'] as String).isNotEmpty) {
      _accessToken = body['access_token'] as String;
    } else if (!kIsWeb) {
      // 네이티브 http.Client는 쿠키 저장소가 없으므로 직접 보관합니다.
      final setCookie = response.headers['set-cookie'];
      final match = setCookie == null
          ? null
          : RegExp(r'(?:^|[,\s])tmp_staff_session=([^;\s,]+)')
              .firstMatch(setCookie);
      if (match == null) {
        throw const StaffInventoryApiException(
          '임시 인증 응답에 tmp_staff_session 쿠키가 없습니다.',
        );
      }
      _temporarySessionCookie = 'tmp_staff_session=${match.group(1)!}';
    }

    // 브라우저는 HttpOnly Set-Cookie 헤더를 노출하지 않습니다.
    // BrowserClient(withCredentials: true)의 쿠키 보관 결과를 실제 보호된
    // 직원 API에서 검증합니다. 쿠키 발급만으로 인증 성공이라 판단하지 않습니다.
    await _verifyStaffAuthorization();
  }

  Future<void> _verifyStaffAuthorization() async {
    try {
      final response = await _get('/staff/cosmetics/distinct', {
        'page': '1',
        'count': '1',
      });
      _rows(response);
    } on StaffInventoryApiException catch (error) {
      throw StaffInventoryApiException(
        '직원 권한 확인 실패: ${error.message}. '
        'Web에서는 127.0.0.1에서 실행하고, '
        'FastAPI의 로컬 CORS 및 직원 계정 등록 여부를 확인하세요.',
        error.statusCode,
      );
    }
  }

  Map<String, String> _requestHeaders() {
    final headers = <String, String>{'Accept': 'application/json'};
    final token = _accessToken;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    } else if (!kIsWeb && _temporarySessionCookie != null) {
      headers['Cookie'] = _temporarySessionCookie!;
    }
    return headers;
  }

  Future<Object?> _get(String path, [Map<String, dynamic>? query]) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    debugPrint('[STAFF API] GET $uri');
    late http.Response response;
    try {
      response = await _client.get(
        uri,
        headers: _requestHeaders(),
      ).timeout(const Duration(seconds: 15));
    } catch (error) {
      throw StaffInventoryApiException('서버 요청 실패: $error');
    }

    debugPrint('[STAFF API] GET $path -> HTTP ${response.statusCode}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final suffix = response.statusCode == 401
          ? ' (직원 인증 만료 또는 미인증)'
          : '';
      throw StaffInventoryApiException(
        'HTTP ${response.statusCode}$suffix: ${_errorDetail(response)}',
        response.statusCode,
      );
    }
    return _decodeResponse(response);
  }

  /// 주문 Service 등 다른 직원 화면도 같은 인증된 HTTP 클라이언트를 재사용합니다.
  /// statuses=... 등의 다중 쿼리 파라미터를 위해 List<String>도 지원합니다.
  Future<Object?> getAuthorizedJson(
    String path, [
    Map<String, dynamic>? query,
  ]) => _get(path, query);

  /// 다른 직원 도메인에서도 같은 로그인 JWT/임시 세션 쿠키로 PATCH합니다.
  /// 주문 상태 변경 등 확정 버튼을 누른 뒤에만 호출하세요.
  Future<Object?> patchAuthorizedJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final uri = Uri.parse('$baseUrl$path');
    late http.Response response;
    try {
      response = await _client.patch(
        uri,
        headers: {..._requestHeaders(), 'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 15));
    } catch (error) {
      throw StaffInventoryApiException('서버 수정 요청 실패: $error');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StaffInventoryApiException(
        'HTTP ${response.statusCode}: ${_errorDetail(response)}',
        response.statusCode,
      );
    }
    return _decodeResponse(response);
  }

  /// 수량 차감은 사용자가 폐기 확인을 누를 때에만 실행합니다.
  Future<Map<String, dynamic>> discardInventory({
    required String inventoryId,
    required int quantity,
  }) async {
    if (quantity < 1) {
      throw const StaffInventoryApiException('폐기 수량은 1 이상이어야 합니다.');
    }
    final encodedId = Uri.encodeComponent(inventoryId);
    final uri = Uri.parse('$baseUrl/staff/inventory/$encodedId/discard');
    late http.Response response;
    try {
      response = await _client.patch(
        uri,
        headers: {..._requestHeaders(), 'Content-Type': 'application/json'},
        body: jsonEncode({'quantity': quantity}),
      ).timeout(const Duration(seconds: 15));
    } catch (error) {
      throw StaffInventoryApiException('폐기 요청 실패: $error');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StaffInventoryApiException(
        '폐기 처리 실패 (HTTP ${response.statusCode}): ${_errorDetail(response)}',
        response.statusCode,
      );
    }
    final parsed = _decodeResponse(response);
    if (parsed is! Map) {
      throw const StaffInventoryApiException('폐기 결과 형식이 올바르지 않습니다.');
    }
    return Map<String, dynamic>.from(parsed);
  }

  Object? _decodeResponse(http.Response response) {
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw StaffInventoryApiException(
        '서버가 올바른 JSON을 반환하지 않았습니다 (HTTP ${response.statusCode}).',
        response.statusCode,
      );
    }
  }

  String _errorDetail(http.Response response) {
    try {
      final parsed = jsonDecode(utf8.decode(response.bodyBytes));
      if (parsed is Map && parsed['detail'] != null) {
        return parsed['detail'].toString();
      }
    } catch (_) {}
    return '서버 응답을 확인하세요.';
  }

  List<Map<String, dynamic>> _rows(Object? result) {
    // 현재 FastAPI는 배열을 직접 반환. 선택적으로 {results:[...]}도 수용.
    Object? value = result;
    if (value is Map) {
      value = value['results'] ?? value['items'] ?? value['data'];
    }
    if (value is! List) {
      throw const StaffInventoryApiException('API 응답이 목록 형식이 아닙니다.');
    }
    return value.map((item) {
      if (item is! Map) {
        throw const StaffInventoryApiException('목록에 객체가 아닌 항목이 있습니다.');
      }
      return Map<String, dynamic>.from(item);
    }).toList();
  }

  String _requiredString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null || value.toString().trim().isEmpty) {
      throw StaffInventoryApiException('API 응답에 필수 필드 $key 값이 없습니다.');
    }
    return value.toString();
  }

  int _asInt(Object? value) {
    if (value is num) return value.toInt();
    return num.tryParse(value?.toString() ?? '')?.toInt() ?? 0;
  }

  DateTime _requiredDate(Object? value, String field) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    if (parsed == null) {
      throw StaffInventoryApiException('재고 데이터의 $field 날짜가 올바르지 않습니다.');
    }
    return parsed;
  }

  /// 기존 화장품별 화면도 서버가 지원하는 page/count로 페이지 조회합니다.
  Future<List<RootCosmetics>> getDistinctCosmeticsPage({
    required int page,
    int count = 20,
    String? inventoryStatus,
  }) async {
    final rows = _rows(await _get('/staff/cosmetics/distinct', {
      'page': '$page',
      'count': '$count',
      if (inventoryStatus != null) 'inventory_status': inventoryStatus,
    }));
    return rows.map((json) => RootCosmetics(
      name: _requiredString(json, 'cosmetic_name'),
      categoryName: _requiredString(json, 'category_name'),
    )).toList();
  }

  /// 이전 API 호출부의 호환성을 위해 유지합니다.
  Future<List<RootCosmetics>> getDistinctCosmetics() async =>
      getDistinctCosmeticsPage(page: 1);

  /// 화장품 행을 펼친 순간에만 요청합니다.
  Future<List<OptionCosmetics>> getCosmeticOptions(
    String cosmeticName, {String? inventoryStatus,
  }) async {
    final encodedName = Uri.encodeComponent(cosmeticName);
    final rows = _rows(await _get('/staff/cosmetics/$encodedName/options', {
      if (inventoryStatus != null) 'inventory_status': inventoryStatus,
    }));
    return rows.map((json) => OptionCosmetics(
          cosmeticId: _requiredString(json, 'cosmetic_id'),
          manufactureerId: _requiredString(json, 'manufacturer_id'),
          salePrice: _asInt(json['sale_price']),
          unitPrice: _asInt(json['unit_cost']),
          minStock: _asInt(json['min_stock_qty']),
          targetStock: _asInt(json['target_stock_qty']),
          volumeText: json['volume_text']?.toString(),
          saleStatus: json['sale_status']?.toString(),
        )).toList();
  }

  /// 옵션 행을 펼친 순간에만 요청합니다.
  Future<List<StaffProductInventory>> getInventoryByCosmeticId(
    String cosmeticId, {String? inventoryStatus,
  }) async {
    final encodedId = Uri.encodeComponent(cosmeticId);
    final rows = _rows(await _get('/staff/cosmetics/$encodedId/inventory', {
      if (inventoryStatus != null) 'inventory_status': inventoryStatus,
    }));
    return rows.map(_inventoryFromJson).toList();
  }

  StaffProductInventory _inventoryFromJson(Map<String, dynamic> json) {
    final status = _requiredString(json, 'inventory_status');
    final option = _requiredString(json, 'sale_option');
    return StaffProductInventory(
      inventoryId: _requiredString(json, 'inventory_id'),
      cosmeticId: _requiredString(json, 'cosmetic_id'),
      stockQuantity: _asInt(json['stock_quantity']),
      receivedOn: _requiredDate(json['received_on'], 'received_on'),
      expiresOn: json['expires_on'] == null
          ? null
          : _requiredDate(json['expires_on'], 'expires_on'),
      inventoryStatus: InventoryStatus.values.byName(status),
      saleOption: SaleOption.values.byName(option),
    );
  }

  /// GET /staff/inventory/by-status
  /// 기존 백엔드 API를 그대로 사용하며, 직원 인증 헤더/쿠키도 자동 적용됩니다.
  /// 반환: {summary: {MAINTAIN: {...}, ...}, inventories: [...]}
  Future<InventoryStatusOverview> getInventoryGroupedByStatus({
    int page = 1,
    int count = 20,
    bool descending = true,
    String? inventoryStatus,
  }) async {
    final response = await _get('/staff/inventory/by-status', {
      'page': '$page',
      'count': '$count',
      'descending': '$descending',
      if (inventoryStatus != null) 'inventory_status': inventoryStatus,
    });
    if (response is! Map) {
      throw const StaffInventoryApiException('상태별 재고 API 응답이 객체 형식이 아닙니다.');
    }
    final responseMap = Map<String, dynamic>.from(response);
    final rawSummary = responseMap['summary'];
    if (rawSummary is! Map) {
      throw const StaffInventoryApiException('상태별 재고 API 응답에 summary가 없습니다.');
    }
    final summary = <String, InventoryStatusSummary>{};
    for (final status in const ['MAINTAIN', 'HOLD', 'DISCARD', 'DISCARD_COMPLETED']) {
      final item = rawSummary[status];
      if (item is! Map) {
        throw StaffInventoryApiException('상태별 집계값 $status 형식이 올바르지 않습니다.');
      }
      summary[status] = InventoryStatusSummary(
        inventoryCount: _asInt(item['inventory_count']),
        totalQuantity: _asInt(item['total_quantity']),
      );
    }
    final inventoryRows = _rows(responseMap['inventories']);
    final inventories = inventoryRows.map(_inventoryFromJson).toList();
    final cosmeticNames = <String, String>{};
    for (final row in inventoryRows) {
      final id = _requiredString(row, 'cosmetic_id');
      final name = row['cosmetic_name']?.toString().trim();
      if (name != null && name.isNotEmpty) {
        cosmeticNames[id] = name;
      }
    }
    final rawPagination = responseMap['pagination'];
    if (rawPagination is! Map) {
      throw const StaffInventoryApiException(
        '서버가 페이지 정보를 반환하지 않습니다. backend 라우터와 서비스도 교체하세요.',
      );
    }
    return InventoryStatusOverview(
      summary: summary,
      inventories: inventories,
      cosmeticNames: cosmeticNames,
      page: _asInt(rawPagination['page']),
      pageSize: _asInt(rawPagination['count']),
      total: _asInt(rawPagination['total']),
      totalPages: _asInt(rawPagination['total_pages']),
    );
  }

  /// 재고 카드 선택 시에만 단일 배치 상세를 조회합니다.
  Future<StaffInventoryBatchDetail> getInventoryBatchDetail(String inventoryId) async {
    final encoded = Uri.encodeComponent(inventoryId);
    final result = await _get('/staff/inventory/$encoded');
    if (result is! Map) {
      throw const StaffInventoryApiException('재고 상세 응답이 객체가 아닙니다.');
    }
    return StaffInventoryBatchDetail.fromJson(Map<String, dynamic>.from(result));
  }

  /// 입고 이력 섹션을 펼친 시점에만 요청합니다.
  Future<List<StaffInventoryInbound>> getInventoryInboundHistory(String inventoryId) async {
    final encoded = Uri.encodeComponent(inventoryId);
    final result = await _get('/staff/inventory/$encoded/inbound');
    if (result is! Map) {
      throw const StaffInventoryApiException('입고 이력 응답이 객체가 아닙니다.');
    }
    return parseInventoryInbounds(Map<String, dynamic>.from(result));
  }

  /// 출고 이력 섹션을 펼친 시점에만 요청, 20건씩 서버 페이지 조회합니다.
  Future<StaffInventoryOutboundPage> getInventoryOutboundHistory(
    String inventoryId, {
    int page = 1,
    int count = 20,
  }) async {
    final encoded = Uri.encodeComponent(inventoryId);
    final result = await _get('/staff/inventory/$encoded/outbounds', {
      'page': '$page',
      'count': '$count',
    });
    if (result is! Map) {
      throw const StaffInventoryApiException('출고 이력 응답이 객체가 아닙니다.');
    }
    return StaffInventoryOutboundPage.fromJson(Map<String, dynamic>.from(result));
  }

  void dispose() => _client.close();
}
