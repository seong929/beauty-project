class ReturnPickup {
  final String returnId,
      orderId,
      orderItemId,
      shippingAddress,
      returnReason,
      returnStatus,
      pickupStatus;
  final int returnQuantity;
  final DateTime requestedOn;
  final DateTime? pickupRequestedOn, pickupCompletedOn;
  const ReturnPickup({
    required this.returnId,
    required this.orderId,
    required this.orderItemId,
    required this.shippingAddress,
    required this.returnReason,
    required this.returnStatus,
    required this.pickupStatus,
    required this.returnQuantity,
    required this.requestedOn,
    this.pickupRequestedOn,
    this.pickupCompletedOn,
  });
  factory ReturnPickup.fromJson(Map<String, dynamic> json) => ReturnPickup(
    returnId: json['return_id'] as String,
    orderId: json['order_id'] as String,
    orderItemId: json['order_item_id'] as String,
    shippingAddress: json['shipping_address'] as String,
    returnReason: json['return_reason'] as String,
    returnStatus: json['return_status'] as String,
    pickupStatus: json['pickup_status'] as String,
    returnQuantity: (json['return_quantity'] as num).toInt(),
    requestedOn: DateTime.parse(json['requested_on'] as String),
    pickupRequestedOn: json['pickup_requested_on'] == null
        ? null
        : DateTime.parse(json['pickup_requested_on'] as String),
    pickupCompletedOn: json['pickup_completed_on'] == null
        ? null
        : DateTime.parse(json['pickup_completed_on'] as String),
  );
  bool get canComplete =>
      returnStatus == 'COLLECTING' && pickupStatus == 'SCHEDULED';
  String get statusText => switch (pickupStatus) {
    'SCHEDULED' => '회수 요청',
    'COLLECTED' => '수거 완료',
    'FAILED' => '수거 실패',
    _ => '수거 대기',
  };
}
