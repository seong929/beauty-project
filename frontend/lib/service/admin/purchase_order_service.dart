
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../model/admin/purchase_order.dart';

class PurchaseOrderService {
  final String baseUrl;

  const PurchaseOrderService({
    required this.baseUrl,
  });

  // 1. 발주 목록 조회
  Future<List<PurchaseOrder>> getPurchaseOrderList({
    required String accessToken,
  }) async {
    final url = Uri.parse('$baseUrl/admin/purchase-orders');

    final response = await http.get(
      url,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode == 401) {
      throw Exception('인증에 실패했습니다. 다시 로그인해 주세요.');
    }

    if (response.statusCode == 403) {
      throw Exception('발주 목록을 조회할 권한이 없습니다.');
    }

    if (response.statusCode != 200) {
      throw Exception(
        '발주 목록 조회 실패: ${response.statusCode} '
        '${utf8.decode(response.bodyBytes)}',
      );
    }

    final List<dynamic> jsonList = jsonDecode(
      utf8.decode(response.bodyBytes),
    );

    return jsonList
        .map(
          (json) => PurchaseOrder.fromJson(
            json as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  // 2. 발주 등록
  Future<PurchaseOrderCreateResponse> createPurchaseOrder({
    required PurchaseOrderCreateRequest request,
    required String accessToken,
  }) async {
    final url = Uri.parse('$baseUrl/admin/purchase-orders');

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(request.toJson()),
    );

    if (response.statusCode == 401) {
      throw Exception('인증에 실패했습니다. 다시 로그인해 주세요.');
    }

    if (response.statusCode == 403) {
      throw Exception('발주를 등록할 권한이 없습니다.');
    }

    if (response.statusCode == 404) {
      throw Exception('존재하지 않는 품의입니다.');
    }

    if (response.statusCode == 409) {
      final responseBody = jsonDecode(
        utf8.decode(response.bodyBytes),
      );

      throw Exception(
        responseBody['detail'] ?? '발주 등록이 불가능합니다.',
      );
    }

    if (response.statusCode != 201) {
      throw Exception(
        '발주 등록 실패: ${response.statusCode} '
        '${utf8.decode(response.bodyBytes)}',
      );
    }

    final Map<String, dynamic> json = jsonDecode(
      utf8.decode(response.bodyBytes),
    );

    return PurchaseOrderCreateResponse.fromJson(json);
  }
}
