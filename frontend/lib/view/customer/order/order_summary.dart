import 'package:flutter/material.dart';
import 'package:beauty_project/model/customer/order.dart';
import '../login/customer_auth_widgets.dart';
import '../product/product_widgets.dart';

String orderDateText(DateTime? date) => date == null
    ? '확인 중'
    : '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

class CustomerOrderSummary extends StatelessWidget {
  const CustomerOrderSummary({super.key, required this.order});
  final CustomerOrder order;

  List<CustomerOrderLine> get _displayItems {
    final grouped = <(String, double), CustomerOrderLine>{};
    for (final item in order.items) {
      final key = (item.productId, item.unitPrice);
      final previous = grouped[key];
      grouped[key] = CustomerOrderLine(
        id: item.id,
        productId: item.productId,
        name: item.name,
        quantity: (previous?.quantity ?? 0) + item.quantity,
        unitPrice: item.unitPrice,
      );
    }
    return grouped.values.toList();
  }

  Widget _row(String label, String value, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 96,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: SodamStyle.muted),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 12,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _row('주문번호', order.id),
      if (order.orderedAt != null) _row('주문일', orderDateText(order.orderedAt)),
      _row('주문 상태', order.statusLabel),
      _row('상품 금액', productPrice(order.total)),
      _row('배송비', '0원'),
      if (order.usedPoints > 0) _row('사용 포인트', '${order.usedPoints}P'),
      _row('총 결제 금액', productPrice(order.paymentAmount), bold: true),
      _row(
        order.status == 'CANCELLED' ? '취소된 적립 포인트' : '적립 포인트 (10%)',
        '${order.earnedPoints}P',
      ),
      _row('배송 주소', order.address),
      if (order.recipient.isNotEmpty) _row('수령인', order.recipient),
      if (order.phone.isNotEmpty) _row('연락처', order.phone),
      if (order.deliveryRequest.isNotEmpty)
        _row('배송 요청사항', order.deliveryRequest),
      const Divider(height: 30),
      Text(
        '구매 상품 ${order.quantity}개',
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 12),
      for (final item in _displayItems)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.shopping_bag_outlined,
                size: 22,
                color: SodamStyle.green,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name, style: const TextStyle(fontSize: 13)),
                    Text(
                      '${item.quantity}개 · ${productPrice(item.unitPrice)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: SodamStyle.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                productPrice(item.total),
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
    ],
  );
}
