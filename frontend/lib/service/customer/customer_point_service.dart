import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:beauty_project/model/customer/point_account.dart';
import 'customer_auth_service.dart';

class CustomerPointService {
  const CustomerPointService({required this.client, required this.baseUrl});
  final http.Client client;
  final Uri baseUrl;

  Future<CustomerPointAccount> fetch(String customerId) async {
    try {
      final response = await client
          .get(
            baseUrl
                .resolve('customer_points')
                .replace(queryParameters: {'customer_id': customerId}),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw const CustomerAuthException('포인트 정보를 불러오지 못했어요. 다시 시도해 주세요.');
      }
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data is! Map ||
          data['customer_id'] != customerId ||
          data['balance'] is! int ||
          data['balance'] < 0 ||
          data['history'] is! List) {
        throw const FormatException();
      }
      final entries = <CustomerPointEntry>[];
      for (final row in data['history']) {
        if (row is! Map ||
            row['point_id'] is! String ||
            row['order_id'] is! String ||
            !['EARN', 'CANCEL', 'USE', 'RESTORE'].contains(row['event_type']) ||
            row['points_delta'] is! int ||
            row['balance_after'] is! int ||
            row['balance_after'] < 0) {
          throw const FormatException();
        }
        final date = DateTime.tryParse(row['created_at']?.toString() ?? '');
        if (date == null) throw const FormatException();
        entries.add(
          CustomerPointEntry(
            id: row['point_id'],
            orderId: row['order_id'],
            type: row['event_type'],
            delta: row['points_delta'],
            balanceAfter: row['balance_after'],
            createdAt: date,
          ),
        );
      }
      return CustomerPointAccount(
        balance: data['balance'],
        history: List.unmodifiable(entries),
      );
    } on CustomerAuthException {
      rethrow;
    } catch (_) {
      throw const CustomerAuthException('포인트 내역을 확인할 수 없어요. 다시 시도해 주세요.');
    }
  }
}
