
class Delivery {
  final String deliveryId;
  final String orderId;
  final int deliverySeq;
  final String carrierName;
  final String shippingAddress;
  final DateTime orderedAt;
  final String deliveryStatus;
  final DateTime? shippedAt;
  final DateTime? arrivedAt;

  const Delivery({
    required this.deliveryId,
    required this.orderId,
    required this.deliverySeq,
    required this.carrierName,
    required this.shippingAddress,
    required this.orderedAt,
    required this.deliveryStatus,
    this.shippedAt,
    this.arrivedAt,
  });

  factory Delivery.fromJson(Map<String, dynamic> json) {
    return Delivery(
      deliveryId: json['delivery_id'] as String,
      orderId: json['order_id'] as String,
      deliverySeq: json['delivery_seq'] as int,
      carrierName: json['carrier_name'] as String,
      shippingAddress: json['shipping_address'] as String,
      orderedAt: DateTime.parse(
        json['ordered_at'] as String,
      ),
      deliveryStatus: json['delivery_status'] as String,
      shippedAt: json['shipped_at'] == null
          ? null
          : DateTime.parse(json['shipped_at'] as String),
      arrivedAt: json['arrived_at'] == null
          ? null
          : DateTime.parse(json['arrived_at'] as String),
    );
  }

  String get statusText {
    switch (deliveryStatus) {
      case 'READY':
        return '배송 준비';
      case 'IN_TRANSIT':
        return '배송 중';
      case 'DELIVERED':
        return '배송 완료';
      default:
        return deliveryStatus;
    }
  }
}

// 배송 상태 변경 API 응답 모델
class DeliveryStatusResult {
  final String deliveryId;
  final String previousStatus;
  final String deliveryStatus;
  final String message;

  const DeliveryStatusResult({
    required this.deliveryId,
    required this.previousStatus,
    required this.deliveryStatus,
    required this.message,
  });

  factory DeliveryStatusResult.fromJson(
    Map<String, dynamic> json,
  ) {
    return DeliveryStatusResult(
      deliveryId: json['delivery_id'] as String,
      previousStatus: json['previous_status'] as String,
      deliveryStatus: json['delivery_status'] as String,
      message: json['message'] as String,
    );
  }
}
