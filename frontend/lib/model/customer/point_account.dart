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
