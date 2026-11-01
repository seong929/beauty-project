// 기능: 포인트 잔액과 적립·사용·복원 내역.
// 데이터 모델 계층: Riverpod 의존성을 넣지 않고 데이터와 변환·계산만 제공한다.

class CustomerPointEntry {
  const CustomerPointEntry({
    required this.id,
    required this.orderId,
    required this.type,
    required this.delta,
    required this.balanceAfter,
    required this.createdAt,
  });
  final String id;
  final String orderId;
  final String type;
  final int delta;
  final int balanceAfter;
  final DateTime createdAt;
}

class CustomerPointAccount {
  const CustomerPointAccount({required this.balance, required this.history});
  final int balance;
  final List<CustomerPointEntry> history;
}
