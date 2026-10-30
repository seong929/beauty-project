import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beauty_project/vm/customer/checkout_points_handler.dart';
import 'package:beauty_project/vm/customer/point_handler.dart';
import 'checkout_widgets.dart';

class CheckoutPointsSection extends ConsumerStatefulWidget {
  const CheckoutPointsSection({super.key});

  @override
  ConsumerState<CheckoutPointsSection> createState() =>
      _CheckoutPointsSectionState();
}

class _CheckoutPointsSectionState extends ConsumerState<CheckoutPointsSection> {
  final _input = TextEditingController();

  @override
  void initState() {
    super.initState();
    _sync(ref.read(checkoutPointSummaryProvider).used);
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  // Function: 전액 사용·잔액·상품 금액 변경 결과를 입력창과 일치시킨다.
  void _sync(int amount) {
    final text = amount.toString();
    if (_input.text != text) {
      _input.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
  }

  void _edit(String text) {
    ref.read(checkoutPointsProvider.notifier).edit(int.tryParse(text) ?? 0);
    _sync(ref.read(checkoutPointSummaryProvider).used);
  }

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(checkoutPointSummaryProvider);
    final selection = ref.watch(checkoutPointsProvider);
    final account = ref.watch(customerPointsProvider);
    ref.listen(
      checkoutPointSummaryProvider.select((value) => value.used),
      (_, next) => _sync(next),
    );
    return CheckoutSection(
      title: '하나 포인트',
      children: [
        TextFormField(
          key: const Key('checkout-points'),
          controller: _input,
          enabled: summary.ready && summary.maximum > 0,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
          onChanged: _edit,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            filled: true,
            fillColor: CheckoutStyle.field,
            suffixText: '최대 ${summary.maximum}P',
            suffixStyle: const TextStyle(
              fontSize: 12,
              color: CheckoutStyle.muted,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        Row(
          children: [
            Checkbox(
              key: const Key('checkout-use-all-points'),
              value: selection.useAll,
              onChanged:
                  selection.useAll || (summary.ready && summary.maximum > 0)
                  ? (value) => ref
                        .read(checkoutPointsProvider.notifier)
                        .useAll(value ?? false)
                  : null,
            ),
            Expanded(
              child: Text(
                '전액 사용 · 보유 ${summary.balance}P',
                style: const TextStyle(
                  fontSize: 12,
                  color: CheckoutStyle.muted,
                ),
              ),
            ),
          ],
        ),
        if (account.isLoading)
          const Text(
            '포인트 잔액을 확인하고 있어요.',
            style: TextStyle(fontSize: 11, color: CheckoutStyle.muted),
          ),
        if (account.hasError)
          TextButton(
            onPressed: () => ref.invalidate(customerPointsProvider),
            child: const Text('포인트를 불러오지 못했어요. 다시 조회'),
          ),
        if (selection.useAll || selection.amount > 0)
          TextButton(
            key: const Key('checkout-clear-points'),
            onPressed: () => ref.read(checkoutPointsProvider.notifier).edit(0),
            child: const Text('포인트 사용 취소'),
          ),
        const Text(
          '1P = 1원 · 보유 포인트와 상품 금액까지만 사용할 수 있습니다.',
          style: TextStyle(fontSize: 11, color: CheckoutStyle.muted),
        ),
      ],
    );
  }
}
