// 기능: 배송 정보 변경 가능 여부와 주문 배송 데이터.
// 데이터 모델 계층: Riverpod 의존성을 넣지 않고 데이터와 변환·계산만 제공한다.

class DeliveryOrder {
  const DeliveryOrder({
    required this.orderId,
    required this.status,
    required this.address,
    required this.hasDelivery,
    this.recipient = '',
    this.phone = '',
    this.deliveryRequest = '',
  });

  final String orderId;
  final String status;
  final String address;
  final bool hasDelivery;
  final String recipient;
  final String phone;
  final String deliveryRequest;

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
