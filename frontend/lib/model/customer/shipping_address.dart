// 기능: 수령인·연락처·주소·배송 요청사항.
// 데이터 모델 계층: Riverpod 의존성을 넣지 않고 데이터와 변환·계산만 제공한다.

class ShippingAddress {
  const ShippingAddress({
    required this.recipient,
    required this.phone,
    required this.address,
    this.deliveryRequest = '',
  });
  final String recipient;
  final String phone;
  final String address;
  final String deliveryRequest;

  bool get isComplete =>
      recipient.trim().isNotEmpty &&
      phone.trim().isNotEmpty &&
      address.trim().isNotEmpty;
}
