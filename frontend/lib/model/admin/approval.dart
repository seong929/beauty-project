class Approval {
  final String approvalId;
  final String cosmeticId;
  final String cosmeticName;
  final int approvalSeq;
  final int targetStockSnapshot;
  final int currentStockSnapshot;
  final int requestedQuantity;
  final String approvalContent;
  final DateTime requestedOn;
  final String? approvalStatus;
  final String? decisionId;
  final String? decisionStatus;
  final String? employeeId;
  final DateTime? decidedAt;
  final String? manufacturerId;
  final String? manufacturerName;
  final String? categoryId;
  final int? cosmeticNameSeq;
  final String? volumeText;
  final String? unitCost;
  final String? purchaseOrderId;
  final int? orderQuantity;

  const Approval({
    required this.approvalId,
    required this.cosmeticId,
    required this.cosmeticName,
    required this.approvalSeq,
    required this.targetStockSnapshot,
    required this.currentStockSnapshot,
    required this.requestedQuantity,
    required this.approvalContent,
    required this.requestedOn,
    this.approvalStatus,
    this.decisionId,
    this.decisionStatus,
    this.employeeId,
    this.decidedAt,
    this.manufacturerId,
    this.manufacturerName,
    this.categoryId,
    this.cosmeticNameSeq,
    this.volumeText,
    this.unitCost,
    this.purchaseOrderId,
    this.orderQuantity,
  });

  factory Approval.fromJson(Map<String, dynamic> json) {
    return Approval(
      approvalId: json['approval_id'] as String,
      cosmeticId: json['cosmetic_id'] as String,
      cosmeticName: json['cosmetic_name'] as String,
      approvalSeq: json['approval_seq'] as int,
      targetStockSnapshot: json['target_stock_snapshot'] as int,
      currentStockSnapshot: json['current_stock_snapshot'] as int,
      requestedQuantity: json['requested_quantity'] as int,
      approvalContent: json['approval_content'] as String,
      requestedOn: DateTime.parse(json['requested_on'] as String),
      approvalStatus: json['approval_status'] as String?,
      decisionId: json['decision_id'] as String?,
      decisionStatus: json['decision_status'] as String?,
      employeeId: json['employee_id'] as String?,
      decidedAt: json['decided_at'] == null
          ? null
          : DateTime.parse(json['decided_at'] as String),
      manufacturerId: json['manufacturer_id'] as String?,
      manufacturerName: json['manufacturer_name'] as String?,
      categoryId: json['category_id'] as String?,
      cosmeticNameSeq: json['cosmetic_name_seq'] as int?,
      volumeText: json['volume_text'] as String?,
      unitCost: json['unit_cost']?.toString(),
      purchaseOrderId: json['purchase_order_id'] as String?,
      orderQuantity: json['order_quantity'] as int?,
    );
  }
}
