// 발주 목록 및 상세 정보
class PurchaseOrder {
  final String purchaseOrderId;
  final String approvalId;
  final int purchaseOrderSeq;
  final String manufacturerId;
  final String manufacturerName;
  final String cosmeticId;
  final String cosmeticName;
  final DateTime orderedOn;
  final int orderQuantity;
  final String purchaseStatus;
  final double unitSupplyPrice;
  final double orderTotalAmount;

  const PurchaseOrder({
    required this.purchaseOrderId,
    required this.approvalId,
    required this.purchaseOrderSeq,
    required this.manufacturerId,
    required this.manufacturerName,
    required this.cosmeticId,
    required this.cosmeticName,
    required this.orderedOn,
    required this.orderQuantity,
    required this.purchaseStatus,
    required this.unitSupplyPrice,
    required this.orderTotalAmount,
  });

  factory PurchaseOrder.fromJson(Map<String, dynamic> json) {
    return PurchaseOrder(
      purchaseOrderId: json['purchase_order_id'] as String,
      approvalId: json['approval_id'] as String,
      purchaseOrderSeq: json['purchase_order_seq'] as int,
      manufacturerId: json['manufacturer_id'] as String,
      manufacturerName: json['manufacturer_name'] as String,
      cosmeticId: json['cosmetic_id'] as String,
      cosmeticName: json['cosmetic_name'] as String,
      orderedOn: DateTime.parse(json['ordered_on'] as String),
      orderQuantity: json['order_quantity'] as int,
      purchaseStatus: json['purchase_status'] as String,
      unitSupplyPrice: double.parse(
        json['unit_supply_price'].toString(),
      ),
      orderTotalAmount: double.parse(
        json['order_total_amount'].toString(),
      ),
    );
  }
  // STAFF가 입고할 수 있는 발주인지 확인
  bool get canInbound {
    return purchaseStatus == 'ORDERED' ||
        purchaseStatus == 'PARTIALLY_RECEIVED';
  }
}

// 발주 등록 요청
class PurchaseOrderCreateRequest {
  final String approvalId;
  final String manufacturerId;
  final String unitSupplyPrice;

  const PurchaseOrderCreateRequest({
    required this.approvalId,
    required this.manufacturerId,
    required this.unitSupplyPrice,
  });

  Map<String, dynamic> toJson() {
    return {
      'approval_id': approvalId,
      'manufacturer_id': manufacturerId,
      'unit_supply_price': unitSupplyPrice,
    };
  }
}

// 발주 등록 응답
class PurchaseOrderCreateResponse {
  final String purchaseOrderId;
  final String approvalId;
  final int purchaseOrderSeq;
  final String manufacturerId;
  final int orderQuantity;
  final double unitSupplyPrice;
  final double orderTotalAmount;
  final String purchaseStatus;
  final String message;

  const PurchaseOrderCreateResponse({
    required this.purchaseOrderId,
    required this.approvalId,
    required this.purchaseOrderSeq,
    required this.manufacturerId,
    required this.orderQuantity,
    required this.unitSupplyPrice,
    required this.orderTotalAmount,
    required this.purchaseStatus,
    required this.message,
  });

  factory PurchaseOrderCreateResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    return PurchaseOrderCreateResponse(
      purchaseOrderId: json['purchase_order_id'] as String,
      approvalId: json['approval_id'] as String,
      purchaseOrderSeq: json['purchase_order_seq'] as int,
      manufacturerId: json['manufacturer_id'] as String,
      orderQuantity: json['order_quantity'] as int,
      unitSupplyPrice: double.parse(
        json['unit_supply_price'].toString(),
      ),
      orderTotalAmount: double.parse(
        json['order_total_amount'].toString(),
      ),
      purchaseStatus: json['purchase_status'] as String,
      message: json['message'] as String,
    );
  }
}