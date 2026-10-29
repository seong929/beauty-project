
class InboundCreateRequest {
  final String purchaseOrderId;
  final String employeeId;
  final int inboundQuantity;
  final DateTime inboundOn;
  final DateTime? expiresOn;

  const InboundCreateRequest({
    required this.purchaseOrderId,
    required this.employeeId,
    required this.inboundQuantity,
    required this.inboundOn,
    this.expiresOn,
  });

  Map<String, dynamic> toJson() {
    return {
      'purchase_order_id': purchaseOrderId,
      'employee_id': employeeId,
      'inbound_quantity': inboundQuantity,
      'inbound_on': _formatDate(inboundOn),
      'expires_on': expiresOn == null
          ? null
          : _formatDate(expiresOn!),
    };
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }
}

class InboundCreateResponse {
  final String inboundId;
  final String inventoryId;
  final String purchaseOrderId;
  final int inboundSeq;
  final int inboundQuantity;
  final int totalReceivedQuantity;
  final int remainingQuantity;
  final String purchaseStatus;
  final String message;

  const InboundCreateResponse({
    required this.inboundId,
    required this.inventoryId,
    required this.purchaseOrderId,
    required this.inboundSeq,
    required this.inboundQuantity,
    required this.totalReceivedQuantity,
    required this.remainingQuantity,
    required this.purchaseStatus,
    required this.message,
  });

  factory InboundCreateResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    return InboundCreateResponse(
      inboundId: json['inbound_id'] as String,
      inventoryId: json['inventory_id'] as String,
      purchaseOrderId: json['purchase_order_id'] as String,
      inboundSeq: json['inbound_seq'] as int,
      inboundQuantity: json['inbound_quantity'] as int,
      totalReceivedQuantity:
          json['total_received_quantity'] as int,
      remainingQuantity:
          json['remaining_quantity'] as int,
      purchaseStatus: json['purchase_status'] as String,
      message: json['message'] as String,
    );
  }
}
