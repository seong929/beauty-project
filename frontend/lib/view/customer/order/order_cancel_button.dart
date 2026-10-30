import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beauty_project/model/customer/order.dart';
import 'package:beauty_project/vm/customer/customer_handler.dart';
import 'package:beauty_project/vm/customer/order_cancellation_handler.dart';

class OrderCancelButton extends ConsumerStatefulWidget {
  const OrderCancelButton({
    super.key,
    required this.order,
    required this.canCancel,
  });
  final CustomerOrder order;
  final bool canCancel;

  @override
  ConsumerState<OrderCancelButton> createState() => _OrderCancelButtonState();
}

class _OrderCancelButtonState extends ConsumerState<OrderCancelButton> {
  bool _confirming = false;

  // Function: 주문 전체 취소 여부를 확인한 뒤 실제 취소 요청을 한 번 전송한다.
  Future<void> _cancel() async {
    if (_confirming || !widget.canCancel) return;
    final id = widget.order.customerId;
    setState(() => _confirming = true);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('주문 취소'),
          content: const Text(
            '이 주문의 모든 상품을 취소하시겠어요?\n사용한 포인트는 돌려드리고, 이 주문의 적립 포인트는 회수합니다.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('돌아가기'),
            ),
            TextButton(
              key: const Key('confirm-order-cancel'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('주문 취소하기'),
            ),
          ],
        ),
      );
      if (!mounted ||
          confirmed != true ||
          !widget.canCancel ||
          ref.read(customerHandlerProvider).value?.customerId != id) {
        return;
      }
      final success = await ref
          .read(customerCancellationProvider.notifier)
          .cancel(id, widget.order.id);
      if (!mounted ||
          !success ||
          ref.read(customerHandlerProvider).value?.customerId != id) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('주문이 취소되었습니다.')));
    } catch (error) {
      if (!mounted ||
          ref.read(customerHandlerProvider).value?.customerId != id) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cancellation = ref.watch(customerCancellationProvider);
    final cancelled =
        widget.order.status == 'CANCELLED' ||
        cancellation.value == widget.order.id;
    return OutlinedButton(
      key: const Key('order-detail-cancel'),
      onPressed:
          widget.canCancel &&
              !cancelled &&
              !_confirming &&
              !cancellation.isLoading
          ? _cancel
          : null,
      style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
      child: Text(
        cancelled
            ? '주문 취소 완료'
            : cancellation.isLoading
            ? '취소 처리 중…'
            : '주문 취소',
      ),
    );
  }
}
