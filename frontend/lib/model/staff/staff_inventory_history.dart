/// /staff/inventory/{inventory_id} 및 하위 입출고 이력 API의 DTO.
/// DB 관계: product_inventory 1 : 0..1 inbound_history,
/// product_inventory 1 : N stock_outbounds.
class StaffInventoryBatchDetail {
  const StaffInventoryBatchDetail({
    required this.inventoryId,
    required this.cosmeticId,
    required this.cosmeticName,
    required this.stockQuantity,
    required this.receivedOn,
    required this.expiresOn,
    required this.inventoryStatus,
    required this.saleOption,
  });

  final String inventoryId;
  final String cosmeticId;
  final String cosmeticName;
  final int stockQuantity;
  final String receivedOn;
  final String? expiresOn;
  final String inventoryStatus;
  final String saleOption;

  factory StaffInventoryBatchDetail.fromJson(Map<String, dynamic> json) =>
      StaffInventoryBatchDetail(
        inventoryId: _string(json, 'inventory_id'),
        cosmeticId: _string(json, 'cosmetic_id'),
        cosmeticName: _string(json, 'cosmetic_name'),
        stockQuantity: _integer(json, 'stock_quantity'),
        receivedOn: _string(json, 'received_on'),
        expiresOn: _optionalString(json['expires_on']),
        inventoryStatus: _string(json, 'inventory_status'),
        saleOption: _string(json, 'sale_option'),
      );
}

class StaffInventoryInbound {
  const StaffInventoryInbound({
    required this.inboundId,
    required this.purchaseOrderId,
    required this.inboundSeq,
    required this.inboundQuantity,
    required this.inboundOn,
  });

  final String inboundId;
  final String purchaseOrderId;
  final int inboundSeq;
  final int inboundQuantity;
  final String inboundOn;

  factory StaffInventoryInbound.fromJson(Map<String, dynamic> json) =>
      StaffInventoryInbound(
        inboundId: _string(json, 'inbound_id'),
        purchaseOrderId: _string(json, 'purchase_order_id'),
        inboundSeq: _integer(json, 'inbound_seq'),
        inboundQuantity: _integer(json, 'inbound_quantity'),
        inboundOn: _string(json, 'inbound_on'),
      );
}

class StaffInventoryOutbound {
  const StaffInventoryOutbound({
    required this.orderItemId,
    required this.orderId,
    required this.orderStatus,
    required this.deliveryId,
    required this.outboundQuantity,
    required this.outboundOn,
    required this.outboundStatus,
  });

  final String orderItemId;
  final String orderId;
  final String orderStatus;
  final String? deliveryId;
  final int outboundQuantity;
  final String? outboundOn;
  final String outboundStatus;

  bool get isReserved => outboundStatus == 'RESERVED';

  factory StaffInventoryOutbound.fromJson(Map<String, dynamic> json) =>
      StaffInventoryOutbound(
        orderItemId: _string(json, 'order_item_id'),
        orderId: _string(json, 'order_id'),
        orderStatus: _string(json, 'order_status'),
        deliveryId: _optionalString(json['delivery_id']),
        outboundQuantity: _integer(json, 'outbound_quantity'),
        outboundOn: _optionalString(json['outbound_on']),
        outboundStatus: _string(json, 'outbound_status'),
      );
}

class StaffInventoryOutboundPage {
  const StaffInventoryOutboundPage({
    required this.outbounds,
    required this.page,
    required this.count,
    required this.total,
    required this.totalPages,
    required this.reservedQuantity,
    required this.confirmedQuantity,
  });

  final List<StaffInventoryOutbound> outbounds;
  final int page;
  final int count;
  final int total;
  final int totalPages;
  final int reservedQuantity;
  final int confirmedQuantity;

  factory StaffInventoryOutboundPage.fromJson(Map<String, dynamic> json) {
    final pagination = _map(json['pagination'], 'pagination');
    final summary = _map(json['summary'], 'summary');
    final records = _list(json['outbounds'], 'outbounds');
    return StaffInventoryOutboundPage(
      outbounds: records.map(StaffInventoryOutbound.fromJson).toList(),
      page: _integer(pagination, 'page'),
      count: _integer(pagination, 'count'),
      total: _integer(pagination, 'total'),
      totalPages: _integer(pagination, 'total_pages'),
      reservedQuantity: _integer(summary, 'reserved_quantity'),
      confirmedQuantity: _integer(summary, 'confirmed_quantity'),
    );
  }
}

String _string(Map<String, dynamic> value, String key) {
  final result = value[key];
  if (result == null || result.toString().trim().isEmpty) {
    throw FormatException('API 응답에 $key 필드가 없습니다.');
  }
  return result.toString();
}

String? _optionalString(Object? value) => value?.toString();

int _integer(Map<String, dynamic> value, String key) {
  final result = value[key];
  if (result is int) return result;
  if (result is num) return result.toInt();
  final parsed = int.tryParse(result?.toString() ?? '');
  if (parsed == null) throw FormatException('API의 $key 값이 숫자가 아닙니다.');
  return parsed;
}

Map<String, dynamic> _map(Object? value, String key) {
  if (value is! Map) throw FormatException('API의 $key 항목이 객체가 아닙니다.');
  return Map<String, dynamic>.from(value);
}

List<Map<String, dynamic>> _list(Object? value, String key) {
  if (value is! List) throw FormatException('API의 $key 항목이 목록이 아닙니다.');
  return value.map((item) => _map(item, key)).toList();
}

List<StaffInventoryInbound> parseInventoryInbounds(Map<String, dynamic> json) =>
    _list(json['inbounds'], 'inbounds')
        .map(StaffInventoryInbound.fromJson)
        .toList();
