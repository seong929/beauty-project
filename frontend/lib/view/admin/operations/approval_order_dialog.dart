// Admin-only presentation. Shared STAFF/CUSTOMER views and business providers stay unchanged.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../model/admin/approval.dart';
import '../../../vm/admin/manufacturer_vm.dart';

typedef ApprovalOrderDetails = ({
  String manufacturerId,
  int quantity,
  String price,
});

class OperationsApprovalOrderDialog extends ConsumerStatefulWidget {
  const OperationsApprovalOrderDialog({super.key, required this.approval});
  final Approval approval;
  @override
  ConsumerState<OperationsApprovalOrderDialog> createState() =>
      _OperationsApprovalOrderDialogState();
}

class _OperationsApprovalOrderDialogState
    extends ConsumerState<OperationsApprovalOrderDialog> {
  final form = GlobalKey<FormState>();
  late final TextEditingController quantity;
  final price = TextEditingController();
  String? manufacturer;
  @override
  void initState() {
    super.initState();
    quantity = TextEditingController(
      text: widget.approval.requestedQuantity.toString(),
    );
  }

  @override
  void dispose() {
    quantity.dispose();
    price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final suppliers = ref.watch(manufacturersProvider);
    return AlertDialog(
      title: const Text('품의 승인 및 발주'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${widget.approval.cosmeticName} · ${widget.approval.volumeText ?? widget.approval.cosmeticId}',
                ),
                const SizedBox(height: 16),
                suppliers.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (error, _) => Text('발주처 조회 실패: $error'),
                  data: (items) {
                    final eligible = items
                        .where((m) => m.id == widget.approval.manufacturerId)
                        .toList();
                    if (eligible.isEmpty) {
                      return const Text('상품에 등록된 발주처를 찾을 수 없습니다.');
                    }
                    return DropdownButtonFormField<String>(
                      initialValue: manufacturer,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: '발주처 선택',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final m in eligible)
                          DropdownMenuItem(value: m.id, child: Text(m.name)),
                      ],
                      onChanged: (value) =>
                          setState(() => manufacturer = value),
                      validator: (value) =>
                          value == null ? '발주처를 선택해 주세요.' : null,
                    );
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: quantity,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '발주 수량',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final n = int.tryParse(value ?? '');
                    return n == null || n <= 0 || n > 4294967295
                        ? '1 이상의 수량을 입력해 주세요.'
                        : null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: price,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: '개당 공급 단가',
                    suffixText: '원',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      !RegExp(
                            r'^\d{1,10}(\.\d{1,2})?$',
                          ).hasMatch(value ?? '') ||
                          (double.tryParse(value ?? '') ?? 0) <= 0
                      ? '0보다 큰 금액을 소수 둘째 자리까지 입력해 주세요.'
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () {
            if (manufacturer != null && form.currentState!.validate()) {
              Navigator.pop(context, (
                manufacturerId: manufacturer!,
                quantity: int.parse(quantity.text),
                price: price.text,
              ));
            }
          },
          child: const Text('승인 및 발주'),
        ),
      ],
    );
  }
}
