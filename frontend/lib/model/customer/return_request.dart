class CustomerReturnRequest {
  const CustomerReturnRequest({
    required this.id,
    required this.itemId,
    required this.customerId,
    required this.reason,
    required this.quantity,
    required this.status,
    required this.refundStatus,
    required this.pickupStatus,
    this.requestedOn,
    this.pickupRequestedOn,
    this.pickupCompletedOn,
    this.receivedOn,
    this.inspectionResult,
  });
  final String id;
  final String itemId;
  final String customerId;
  final String reason;
  final int quantity;
  final String status;
  final String refundStatus;
  final String pickupStatus;
  final DateTime? requestedOn;
  final DateTime? pickupRequestedOn;
  final DateTime? pickupCompletedOn;
  final DateTime? receivedOn;
  final String? inspectionResult;

  factory CustomerReturnRequest.fromJson(Map<String, dynamic> json) =>
      CustomerReturnRequest(
        id: json['return_id'] as String,
        itemId: json['order_item_id'] as String,
        customerId: json['customer_id'] as String,
        reason: json['return_reason'] as String,
        quantity: int.parse(json['return_quantity'].toString()),
        status: json['return_status'] as String,
        refundStatus: json['refund_status'] as String,
        pickupStatus: json['pickup_status'] as String,
        requestedOn: DateTime.tryParse(json['requested_on']?.toString() ?? ''),
        pickupRequestedOn: DateTime.tryParse(
          json['pickup_requested_on']?.toString() ?? '',
        ),
        pickupCompletedOn: DateTime.tryParse(
          json['pickup_completed_on']?.toString() ?? '',
        ),
        receivedOn: DateTime.tryParse(
          json['headquarters_received_on']?.toString() ?? '',
        ),
        inspectionResult: json['inspection_result']?.toString(),
      );

  String get statusLabel => switch (status) {
    'REQUESTED' => '접수 완료',
    'APPROVED' => '반품 승인',
    'REJECTED' => '반품 반려',
    'COLLECTING' => '회수 진행 중',
    'INSPECTING' => '검수 중',
    'COMPLETED' => '처리 완료',
    _ => '상태 확인 중',
  };
  String get refundLabel => switch (refundStatus) {
    'PENDING' => '환불 대기',
    'PROCESSING' => '환불 처리 중',
    'COMPLETED' => '환불 완료',
    'FAILED' => '환불 처리 실패',
    _ => '확인 중',
  };
  bool get approved => const {
    'APPROVED',
    'COLLECTING',
    'INSPECTING',
    'COMPLETED',
  }.contains(status);
  bool get pickupRequested =>
      pickupRequestedOn != null ||
      const {'SCHEDULED', 'COLLECTED'}.contains(pickupStatus);
  bool get collected =>
      pickupCompletedOn != null || pickupStatus == 'COLLECTED';
}
