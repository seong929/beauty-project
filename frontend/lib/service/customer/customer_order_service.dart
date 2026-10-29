import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:beauty_project/model/customer/cart_item.dart';
import 'package:beauty_project/model/customer/order.dart';
import 'customer_auth_service.dart';

// 응답이 끊긴 결제 요청은 서버에서 저장되었을 수 있으므로 자동 재시도하지 않는다.
class OrderResultUncertain extends CustomerAuthException {
  const OrderResultUncertain()
    : super('주문 저장 결과를 확인하지 못했습니다. 중복 주문을 방지하기 위해 구매 내역을 먼저 확인해 주세요.');
}

class CustomerOrderService {
  const CustomerOrderService({required this.client, required this.baseUrl});
  final http.Client client;
  final Uri baseUrl;

  Future<CustomerOrder> pay(
    String customerId,
    String address,
    List<CustomerCartItem> items,
  ) async {
    if (items.isEmpty ||
        address.trim().isEmpty ||
        address.trim().length > 500 ||
        items.any(
          (item) =>
              !item.product.isDatabaseProduct ||
              !item.product.hasKnownPrice ||
              item.product.id.startsWith('preview_') ||
              item.quantity < 1,
        )) {
      throw const CustomerAuthException('실제 판매 상품과 배송지를 확인해 주세요.');
    }
    final quantities = <String, int>{};
    for (final item in items) {
      quantities.update(
        item.product.id,
        (count) => count + item.quantity,
        ifAbsent: () => item.quantity,
      );
    }
    final data = await _request(
      () => client.post(
        baseUrl.resolve('orders_pay'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'customer_id': customerId,
          'shipping_address': address.trim(),
          'items': [
            for (final entry in quantities.entries)
              {
                'cosmetic_id': entry.key,
                'quantity': entry.value,
                'sale_option': 'NORMAL',
              },
          ],
        }),
      ),
      payment: true,
    );
    try {
      if (data['result'] != 'OK' ||
          data['order_status'] != 'PAID' ||
          data['customer_id'] != customerId ||
          data['order_id'] is! String ||
          (data['order_id'] as String).isEmpty ||
          data['shipping_address'] != address.trim() ||
          data['items'] is! List) {
        throw const FormatException();
      }
      final lines = (data['items'] as List).map((row) => _line(row)).toList();
      final returnedQuantities = <String, int>{};
      for (final line in lines) {
        returnedQuantities.update(
          line.productId,
          (count) => count + line.quantity,
          ifAbsent: () => line.quantity,
        );
      }
      if (returnedQuantities.length != quantities.length ||
          quantities.entries.any(
            (entry) => returnedQuantities[entry.key] != entry.value,
          )) {
        throw const FormatException();
      }
      final total = _amount(data['total_amount']);
      if ((total - lines.fold<double>(0, (sum, item) => sum + item.total))
              .abs() >
          0.01) {
        throw const FormatException();
      }
      return CustomerOrder(
        id: data['order_id'],
        customerId: customerId,
        status: 'PAID',
        address: data['shipping_address'],
        total: total,
        items: List.unmodifiable(lines),
      );
    } on FormatException {
      throw const OrderResultUncertain();
    }
  }

  Future<List<CustomerOrder>> fetch(String customerId) async {
    final data = await _request(
      () => client.get(
        baseUrl
            .resolve('orders')
            .replace(queryParameters: {'customer_id': customerId}),
      ),
    );
    try {
      final rows = data['results'];
      if (rows is! List) throw const FormatException();
      final grouped = <String, List<Map<String, dynamic>>>{};
      for (final row in rows) {
        if (row is! Map<String, dynamic> ||
            row['customer_id'] != customerId ||
            row['order_id'] is! String ||
            (row['order_id'] as String).isEmpty) {
          throw const FormatException();
        }
        grouped.putIfAbsent(row['order_id'], () => []).add(row);
      }
      return [
        for (final entry in grouped.entries)
          _order(entry.key, customerId, entry.value),
      ];
    } on FormatException {
      throw const CustomerAuthException('구매 내역 응답을 확인할 수 없습니다.');
    }
  }

  CustomerOrder _order(
    String id,
    String customerId,
    List<Map<String, dynamic>> rows,
  ) {
    final first = rows.first;
    if (first['order_status'] is! String ||
        first['shipping_address'] is! String) {
      throw const FormatException();
    }
    // 같은 주문 상품이 배송 조인으로 여러 번 나타나도 한 번만 계산한다.
    final lines = <String, CustomerOrderLine>{};
    for (final row in rows) {
      if (row['order_item_id'] != null) {
        final line = _line(row);
        lines[line.id] = line;
      }
    }
    return CustomerOrder(
      id: id,
      customerId: customerId,
      status: first['order_status'],
      address: first['shipping_address'],
      total: first['order_total_amount'] == null
          ? lines.values.fold<double>(0, (sum, item) => sum + item.total)
          : _amount(first['order_total_amount']),
      orderedAt: DateTime.tryParse(first['order_date']?.toString() ?? ''),
      items: List.unmodifiable(lines.values),
    );
  }

  CustomerOrderLine _line(dynamic row) {
    if (row is! Map ||
        row['order_item_id'] is! String ||
        row['cosmetic_id'] is! String ||
        (row['order_item_id'] as String).isEmpty ||
        (row['cosmetic_id'] as String).isEmpty) {
      throw const FormatException();
    }
    final quantity = int.tryParse(row['quantity']?.toString() ?? '');
    if (quantity == null || quantity < 1) throw const FormatException();
    return CustomerOrderLine(
      id: row['order_item_id'],
      productId: row['cosmetic_id'],
      name: (row['cosmetic_name'] ?? row['product_name'] ?? '상품').toString(),
      quantity: quantity,
      unitPrice: _amount(row['unit_price']),
      saleOption: row['sale_option']?.toString() ?? 'NORMAL',
      deliveryId: row['delivery_id']?.toString(),
    );
  }

  double _amount(dynamic value) {
    final number = double.tryParse(value?.toString() ?? '');
    if (number == null || !number.isFinite || number < 0) {
      throw const FormatException();
    }
    return number;
  }

  Future<Map<String, dynamic>> _request(
    Future<http.Response> Function() send, {
    bool payment = false,
  }) async {
    try {
      final response = await send().timeout(const Duration(seconds: 20));
      if (response.statusCode >= 500) {
        if (payment) throw const OrderResultUncertain();
        throw const CustomerAuthException('주문 서버에 연결할 수 없습니다. 다시 조회해 주세요.');
      }
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data is! Map<String, dynamic>) throw const FormatException();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw CustomerAuthException(
          data['detail'] is String
              ? data['detail'] as String
              : '주문 정보를 다시 확인해 주세요.',
        );
      }
      return data;
    } on TimeoutException {
      if (payment) throw const OrderResultUncertain();
      throw const CustomerAuthException('주문 조회 시간이 초과되었습니다.');
    } on http.ClientException {
      if (payment) throw const OrderResultUncertain();
      throw const CustomerAuthException('네트워크 연결을 확인해 주세요.');
    } on FormatException {
      if (payment) throw const OrderResultUncertain();
      throw const CustomerAuthException('주문 응답을 확인할 수 없습니다.');
    }
  }
}
