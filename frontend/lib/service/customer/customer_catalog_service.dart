import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:beauty_project/model/customer/cosmetic.dart';
import 'customer_auth_service.dart';

class CustomerCatalogService {
  const CustomerCatalogService({required this.client, required this.baseUrl});
  final http.Client client;
  final Uri baseUrl;

  Future<List<Cosmetic>> fetchProducts() async {
    try {
      final response = await client
          .get(
            baseUrl.resolve('customers_categories_search'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw const CustomerAuthException('상품을 불러오지 못했어요. 잠시 후 다시 시도해 주세요.');
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic> || decoded['result'] is! List) {
        throw const FormatException();
      }
      final rows = decoded['result'] as List;
      if (rows.any((row) => row is! Map<String, dynamic>)) {
        throw const FormatException();
      }
      return rows
          .map((row) => Cosmetic.fromJson(row as Map<String, dynamic>))
          .toList();
    } on TimeoutException {
      throw const CustomerAuthException('상품을 불러오는 시간이 초과됐어요. 다시 시도해 주세요.');
    } on http.ClientException {
      throw const CustomerAuthException('네트워크 연결을 확인하고 다시 시도해 주세요.');
    } on FormatException {
      throw const CustomerAuthException('상품 정보를 확인할 수 없어요. 다시 시도해 주세요.');
    }
  }
}
