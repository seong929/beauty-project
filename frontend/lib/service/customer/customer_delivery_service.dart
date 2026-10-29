import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:beauty_project/model/customer/delivery_order.dart';
import 'package:beauty_project/model/customer/delivery.dart';
import 'customer_auth_service.dart';

class CustomerDeliveryService {
  const CustomerDeliveryService({required this.client, required this.baseUrl});
  final http.Client client;
  final Uri baseUrl;

  Future<List<CustomerDelivery>> fetchShipments(
    String customerId, {
    String? orderId,
  }) async {
    final data = await _request(
      () => client.get(
        baseUrl
            .resolve('customer_delivery_select')
            .replace(
              queryParameters: {
                'customer_id': customerId,
                'order_id': ?orderId,
              },
            ),
      ),
    );
    final rows = data['result'];
    if (rows is! List) throw const CustomerAuthException('배송 응답을 확인할 수 없습니다.');
    final deliveries = <CustomerDelivery>[];
    for (final row in rows) {
      if (row is! Map<String, dynamic> ||
          row['customer_id'] != customerId ||
          row['order_id'] is! String ||
          (row['order_id'] as String).isEmpty ||
          row['order_status'] is! String ||
          row['shipping_address'] is! String ||
          (orderId != null && row['order_id'] != orderId) ||
          [
            'delivery_id',
            'delivery_status',
            'carrier_name',
            'carrier_phone',
          ].any((field) => row[field] != null && row[field] is! String)) {
        throw const CustomerAuthException('배송 응답을 확인할 수 없습니다.');
      }
      deliveries.add(CustomerDelivery.fromJson(row));
    }
    return List.unmodifiable(deliveries);
  }

  Future<List<DeliveryOrder>> fetch(String customerId) async {
    final data = await _request(
      () => client.get(
        baseUrl
            .resolve('customer_delivery_select')
            .replace(queryParameters: {'customer_id': customerId}),
      ),
    );
    final rows = data['result'];
    if (rows is! List) {
      throw const CustomerAuthException('주문 응답을 확인할 수 없습니다.');
    }
    final orders = <String, DeliveryOrder>{};
    // 분할 배송 조회 결과를 주문 단위로 합치고 배송 건이 하나라도 있으면 수정을 막는다.
    for (final row in rows) {
      if (row is! Map ||
          row['customer_id'] != customerId ||
          row['order_id'] is! String ||
          (row['order_id'] as String).isEmpty ||
          row['order_status'] is! String ||
          row['shipping_address'] is! String) {
        throw const CustomerAuthException('주문 응답을 확인할 수 없습니다.');
      }
      final id = row['order_id'] as String;
      orders[id] = DeliveryOrder(
        orderId: id,
        status: row['order_status'] as String,
        address: row['shipping_address'] as String,
        hasDelivery:
            row['delivery_id'] != null || orders[id]?.hasDelivery == true,
      );
    }
    return orders.values.toList();
  }

  Future<String> updateAddress(
    String customerId,
    String orderId,
    String address,
  ) async {
    final data = await _request(
      () => client.put(
        baseUrl.resolve('customer_delivery_update'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'customer_id': customerId,
          'order_id': orderId,
          'shipping_address': address.trim(),
        }),
      ),
    );
    if (data['result'] != 'OK' ||
        data['order_id'] != orderId ||
        data['customer_id'] != customerId ||
        data['shipping_address'] != address.trim()) {
      throw const CustomerAuthException('배송지 저장 결과를 확인할 수 없습니다. 다시 조회해 주세요.');
    }
    return data['shipping_address'] as String;
  }

  Future<Map<String, dynamic>> _request(
    Future<http.Response> Function() send,
  ) async {
    try {
      final response = await send().timeout(const Duration(seconds: 15));
      if (response.statusCode >= 500) {
        throw const CustomerAuthException('배송 서버에 연결할 수 없습니다. 다시 조회해 주세요.');
      }
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data is! Map<String, dynamic>) throw const FormatException();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw CustomerAuthException(
          data['detail'] is String
              ? data['detail'] as String
              : '배송지 요청을 처리하지 못했습니다.',
        );
      }
      return data;
    } on TimeoutException {
      throw const CustomerAuthException('연결 시간이 초과되었습니다. 배송지를 다시 조회해 주세요.');
    } on http.ClientException {
      throw const CustomerAuthException('네트워크 연결을 확인해 주세요.');
    } on FormatException {
      throw const CustomerAuthException('배송 응답을 확인할 수 없습니다.');
    }
  }
}
