class DeliveryOrder {
  const DeliveryOrder({
    required this.orderId,
    required this.status,
    required this.address,
    required this.hasDelivery,
  });

  final String orderId;
  final String status;
  final String address;
  final bool hasDelivery;

  bool get canChangeAddress =>
      !hasDelivery && const {'PENDING', 'PAID', 'PREPARING'}.contains(status);

  String get statusLabel => switch (status) {
    'PENDING' => '결제 대기',
    'PAID' => '결제 완료',
    'PREPARING' => '상품 준비 중',
    'SHIPPED' => '출고 완료',
    'DELIVERED' => '배송 완료',
    'CANCELLED' => '주문 취소',
    'RETURNED' => '반품 완료',
    _ => status,
  };
}
