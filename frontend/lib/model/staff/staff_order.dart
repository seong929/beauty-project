// ignore_for_file: constant_identifier_names

/// GET /staff/order/available, /staff/orders/{order_id},
/// /staff/orders/{order_id}/items 에 대응하는 DTO.
enum StaffOrderStatus {
  PENDING,
  PAID,
  PREPARING,
  SHIPPED,
  DELIVERED,
  CANCELLED,
  RETURNED;

  String get label => switch (this) {
    PENDING => '주문 대기',
    PAID => '결제 완료',
    PREPARING => '상품 준비 중',
    SHIPPED => '배송 중',
    DELIVERED => '배송 완료',
    CANCELLED => '주문 취소',
    RETURNED => '반품 완료',
  };
}

String _requiredText(Map<String, dynamic> json, String field) {
  final result = json[field]?.toString();
  if (result == null || result.trim().isEmpty) {
    throw FormatException('주문 API 응답에 $field 필드가 없습니다.');
  }
  return result;
}

int _number(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is int) return value;
  final parsed = int.tryParse(value?.toString() ?? '');
  if (parsed == null) throw FormatException('주문 API의 $field 값이 정수가 아닙니다.');
  return parsed;
}

Map<String, dynamic> asOrderJson(Object? source) {
  if (source is! Map) throw const FormatException('주문 API 응답은 객체여야 합니다.');
  return Map<String, dynamic>.from(source);
}

class StaffOrder {
  const StaffOrder({
    required this.orderId,
    required this.customerId,
    required this.orderSeq,
    required this.status,
    required this.orderedAt,
    required this.shippingAddress,
  });

  final String orderId;
  final String customerId;
  final int orderSeq;
  final StaffOrderStatus status;
  final DateTime orderedAt;
  final String shippingAddress;

  factory StaffOrder.fromJson(Map<String, dynamic> json) {
    final rawDate = _requiredText(json, 'ordered_at');
    final orderedAt = DateTime.tryParse(rawDate);
    if (orderedAt == null) {
      throw const FormatException('주문 일시(ordered_at)가 잘못되었습니다.');
    }
    return StaffOrder(
      orderId: _requiredText(json, 'order_id'),
      customerId: _requiredText(json, 'customer_id'),
      orderSeq: _number(json, 'order_seq'),
      status: StaffOrderStatus.values.byName(_requiredText(json, 'order_status')),
      orderedAt: orderedAt,
      shippingAddress: _requiredText(json, 'shipping_address'),
    );
  }
}

class StaffOrderPage {
  const StaffOrderPage({required this.orders, required this.page, required this.pageSize});
  final List<StaffOrder> orders;
  final int page;
  final int pageSize;

  /// 현 API는 total/total_pages를 반환하지 않으므로 추정만 가능합니다.
  bool get mayHaveNext => orders.length == pageSize;
}

class StaffOrderItem {
  const StaffOrderItem({
    required this.orderItemId,
    required this.cosmeticName,
    required this.cosmeticId,
    required this.inventoryId,
    required this.quantity,
    required this.unitPrice,
    required this.saleOption,
    required this.usedPoints,
    required this.earnedPoints,
    this.expiresOn,
  });

  final String orderItemId;
  final String cosmeticName;
  final String cosmeticId;
  final String inventoryId;
  final int quantity;
  /// 서버의 Decimal 값을 손실 없이 표시하도록 원문 문자열을 보관합니다.
  final String unitPrice;
  final String saleOption;
  final int usedPoints;
  final int earnedPoints;
  final DateTime? expiresOn;

  factory StaffOrderItem.fromJson(Map<String, dynamic> json) => StaffOrderItem(
    orderItemId: _requiredText(json, 'order_item_id'),
    cosmeticName: _requiredText(json, 'cosmetic_name'),
    cosmeticId: _requiredText(json, 'cosmetic_id'),
    inventoryId: _requiredText(json, 'inventory_id'),
    quantity: _number(json, 'purchase_quantity'),
    unitPrice: _requiredText(json, 'purchase_unit_price'),
    saleOption: _requiredText(json, 'sale_option'),
    usedPoints: _number(json, 'used_points'),
    earnedPoints: _number(json, 'earned_points'),
    expiresOn: json['expires_on'] == null
        ? null
        : DateTime.tryParse(json['expires_on'].toString()),
  );
}

String formatOrderDate(DateTime date) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${date.year}-${two(date.month)}-${two(date.day)} ${two(date.hour)}:${two(date.minute)}';
}

String formatOrderDateOnly(DateTime date) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${date.year}-${two(date.month)}-${two(date.day)}';
}

String formatOrderMoney(String decimal) {
  final parts = decimal.split('.');
  final original = parts.first;
  final negative = original.startsWith('-');
  final digits = negative ? original.substring(1) : original;
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i != 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  final fraction = parts.length > 1 ? parts[1].replaceFirst(RegExp(r'0+$'), '') : '';
  return '${negative ? '-' : ''}${buffer.toString()}${fraction.isEmpty ? '' : '.$fraction'}원';
}
