class CustomerDelivery {
  const CustomerDelivery({
    required this.orderId,
    required this.orderStatus,
    required this.address,
    this.id,
    this.status,
    this.orderedAt,
    this.shippedAt,
    this.arrivedAt,
    this.carrierName,
    this.carrierPhone,
  });

  final String orderId;
  final String orderStatus;
  final String address;
  final String? id;
  final String? status;
  final DateTime? orderedAt;
  final DateTime? shippedAt;
  final DateTime? arrivedAt;
  final String? carrierName;
  final String? carrierPhone;

  factory CustomerDelivery.fromJson(Map<String, dynamic> json) =>
      CustomerDelivery(
        orderId: json['order_id'] as String,
        orderStatus: json['order_status'] as String,
        address: json['shipping_address'] as String,
        id: json['delivery_id'] as String?,
        status: json['delivery_status'] as String?,
        orderedAt: DateTime.tryParse(json['ordered_at']?.toString() ?? ''),
        shippedAt: DateTime.tryParse(json['shipped_at']?.toString() ?? ''),
        arrivedAt: DateTime.tryParse(json['arrived_at']?.toString() ?? ''),
        carrierName: json['carrier_name'] as String?,
        carrierPhone: json['carrier_phone'] as String?,
      );

  String get statusLabel {
    if (status == 'FAILED') return '배송 실패';
    if (status == 'RETURNING') return '반송 중';
    if (orderStatus == 'CANCELLED') return '주문 취소';
    if (orderStatus == 'RETURNED') return '반품 완료';
    if (status == 'DELIVERED') return '수령 완료';
    if (status == 'IN_TRANSIT') return '배송 중';
    if (status == 'READY') return '배송 준비';
    return switch (orderStatus) {
      'DELIVERED' => '수령 완료',
      'SHIPPED' => '출고 완료',
      'PAID' || 'PREPARING' => '배송 준비',
      'PENDING' => '결제 대기',
      _ => '배송 정보 확인 중',
    };
  }

  DateTime? get updatedAt {
    final dates = [
      orderedAt,
      shippedAt,
      arrivedAt,
    ].whereType<DateTime>().toList()..sort();
    return dates.isEmpty ? null : dates.last;
  }

  bool get received =>
      status == 'DELIVERED' ||
      arrivedAt != null ||
      (status == null && orderStatus == 'DELIVERED');
  bool get departed =>
      shippedAt != null ||
      const {'IN_TRANSIT', 'DELIVERED'}.contains(status) ||
      received;
}
