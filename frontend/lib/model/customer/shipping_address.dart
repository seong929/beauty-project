class ShippingAddress {
  const ShippingAddress({
    required this.recipient,
    required this.phone,
    required this.address,
  });
  final String recipient;
  final String phone;
  final String address;

  bool get isComplete =>
      recipient.trim().isNotEmpty &&
      phone.trim().isNotEmpty &&
      address.trim().isNotEmpty;
}
