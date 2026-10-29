class CustomerOrderLine {
  const CustomerOrderLine({
    required this.id,
    required this.productId,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    this.saleOption = 'NORMAL',
    this.deliveryId,
  });
  final String id;
  final String productId;
  final String name;
  final int quantity;
  final double unitPrice;
  final String saleOption;
  final String? deliveryId;
  String get saleLabel => saleOption == 'NEAR_EXPIRY' ? '임박' : '일반';
  double get total => unitPrice * quantity;
}

class CustomerOrder {
  const CustomerOrder({
    required this.id,
    required this.customerId,
    required this.status,
    required this.address,
    required this.total,
    required this.items,
    this.orderedAt,
  });
  final String id;
  final String customerId;
  final String status;
  final String address;
  final double total;
  final DateTime? orderedAt;
  final List<CustomerOrderLine> items;
  int get quantity => items.fold(0, (sum, item) => sum + item.quantity);
  List<CustomerOrderLine> get displayItems {
    final grouped = <(String, double, String, String?), CustomerOrderLine>{};
    for (final item in items) {
      final key = (
        item.productId,
        item.unitPrice,
        item.saleOption,
        item.deliveryId,
      );
      grouped[key] = CustomerOrderLine(
        id: grouped[key]?.id ?? item.id,
        productId: item.productId,
        name: item.name,
        quantity: (grouped[key]?.quantity ?? 0) + item.quantity,
        unitPrice: item.unitPrice,
        saleOption: item.saleOption,
        deliveryId: item.deliveryId,
      );
    }
    return List.unmodifiable(grouped.values);
  }

  String get statusLabel => switch (status) {
    'PENDING' => '결제 대기',
    'PAID' => '결제 완료',
    'PREPARING' => '상품 준비 중',
    'SHIPPED' => '배송 중',
    'DELIVERED' => '배송 완료',
    'CANCELLED' => '주문 취소',
    'RETURNED' => '반품 완료',
    _ => status,
  };
}
