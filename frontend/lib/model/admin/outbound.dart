
class OutboundOrder {
  final String orderId;
  final String customerId;
  final String orderStatus;
  final DateTime orderedAt;
  final String shippingAddress;

  const OutboundOrder({
    required this.orderId,
    required this.customerId,
    required this.orderStatus,
    required this.orderedAt,
    required this.shippingAddress,
  });

  factory OutboundOrder.fromJson(Map<String, dynamic> json) {
    return OutboundOrder(
      orderId: json['order_id'] as String,
      customerId: json['customer_id'] as String,
      orderStatus: json['order_status'] as String,
      orderedAt: DateTime.parse(json['ordered_at'] as String),
      shippingAddress: json['shipping_address'] as String,
    );
  }
}

class OutboundResult {
  final String deliveryId;
  final String orderId;
  final int deliverySeq;
  final String carrierId;
  final String orderStatus;
  final String deliveryStatus;
  final String message;

  const OutboundResult({
    required this.deliveryId,
    required this.orderId,
    required this.deliverySeq,
    required this.carrierId,
    required this.orderStatus,
    required this.deliveryStatus,
    required this.message,
  });

  factory OutboundResult.fromJson(Map<String, dynamic> json) {
    return OutboundResult(
      deliveryId: json['delivery_id'] as String,
      orderId: json['order_id'] as String,
      deliverySeq: json['delivery_seq'] as int,
      carrierId: json['carrier_id'] as String,
      orderStatus: json['order_status'] as String,
      deliveryStatus: json['delivery_status'] as String,
      message: json['message'] as String,
    );
  }
}
