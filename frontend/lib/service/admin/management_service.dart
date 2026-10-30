import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../api_config.dart';

/// API 계약에 맞춘 상품 등록 및 반품 처리 서비스.
class ManagementService {
  ManagementService(this.client);

  final http.Client client;

  Future<dynamic> _request(
    String method,
    String path, [
    Map<String, dynamic>? data,
  ]) async {
    final request = http.Request(
      method,
      Uri.parse('${ApiConfig.baseUrl}$path'),
    );
    request.headers['Content-Type'] = 'application/json';
    if (data != null) request.body = jsonEncode(data);
    final response = await http.Response.fromStream(await client.send(request));
    dynamic body;
    if (response.bodyBytes.isNotEmpty) {
      try {
        body = jsonDecode(utf8.decode(response.bodyBytes));
      } on FormatException {
        body = utf8.decode(response.bodyBytes);
      }
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = body is Map ? body['detail'] : null;
      if (response.statusCode == 401) {
        throw Exception('인증이 만료되었습니다. 다시 로그인해 주세요.');
      }
      if (response.statusCode == 403) throw Exception('이 작업을 수행할 권한이 없습니다.');
      throw Exception(
        detail is String ? detail : '서버 요청 실패 (${response.statusCode})',
      );
    }
    return body;
  }

  Future<List<Map<String, dynamic>>> getReturns() async {
    final result = await _request('GET', '/admin/returns') as List<dynamic>;
    return result.cast<Map<String, dynamic>>();
  }

  Future<void> returnAction(
    String id,
    String action,
    String method,
    Map<String, dynamic> data,
  ) async {
    await _request(
      method,
      '/admin/returns/${Uri.encodeComponent(id)}/$action',
      data,
    );
  }

  Future<Map<String, dynamic>> updateRefundStatus({
    required String returnId,
    required String employeeId,
    required String expectedStatus,
    required String refundStatus,
  }) async =>
      await _request(
            'PATCH',
            '/admin/returns/${Uri.encodeComponent(returnId)}/refund-status',
            {
              'employee_id': employeeId,
              'expected_refund_status': expectedStatus,
              'refund_status': refundStatus,
            },
          )
          as Map<String, dynamic>;

  Future<Map<String, dynamic>> createCosmetic(Map<String, dynamic> data) async {
    return await _request('POST', '/admin/cosmetics', data)
        as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getCarriers() async =>
      (await _request('GET', '/staff/carriers') as List)
          .cast<Map<String, dynamic>>();

  Future<List<Map<String, dynamic>>> getCategories() async =>
      (await _request('GET', '/admin/categories') as List)
          .cast<Map<String, dynamic>>();

  Future<void> changeSaleStatus(String cosmeticId, String status) async {
    await _request(
      'PATCH',
      '/admin/cosmetics/${Uri.encodeComponent(cosmeticId)}/sale-status',
      {'sale_status': status},
    );
  }

  Future<Map<String, dynamic>> getCosmeticDetails(String cosmeticId) async =>
      await _request(
            'GET',
            '/staff/cosmetics/${Uri.encodeComponent(cosmeticId)}/detail',
          )
          as Map<String, dynamic>;

  Future<void> updateCosmeticDetails(
    String cosmeticId,
    Map<String, dynamic> data,
  ) async {
    await _request(
      'PATCH',
      '/admin/cosmetics/${Uri.encodeComponent(cosmeticId)}',
      data,
    );
  }

  Future<String?> getCosmeticImage(String cosmeticId) async {
    final result = await _request(
      'GET',
      '/staff/cosmetics/${Uri.encodeComponent(cosmeticId)}/image',
    );
    return (result as Map<String, dynamic>)['image_url'] as String?;
  }

  Future<void> uploadCosmeticImage(
    String cosmeticId,
    Uint8List bytes,
    String filename,
  ) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse(
        '${ApiConfig.baseUrl}/admin/cosmetics/${Uri.encodeComponent(cosmeticId)}/image',
      ),
    );
    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: filename),
    );
    final response = await http.Response.fromStream(await client.send(request));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String? detail;
      try {
        final body = jsonDecode(utf8.decode(response.bodyBytes));
        detail = body['detail'] is String ? body['detail'] as String : null;
      } catch (_) {}
      throw Exception(detail ?? '이미지 업로드에 실패했습니다. (${response.statusCode})');
    }
  }
}
