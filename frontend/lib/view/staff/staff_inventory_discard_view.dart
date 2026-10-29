import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../model/staff/staff_product_inventory.dart';
import '../../vm/staff/staff_inventory_vm.dart';

/// 폐기 대상 재고를 클릭했을 때 열리는 별도 화면.
/// PATCH는 확인 대화상자에서 승인한 이후에만 전송합니다.
class StaffInventoryDiscardView extends ConsumerStatefulWidget {
  const StaffInventoryDiscardView({
    super.key,
    required this.batch,
    required this.cosmeticName,
  });

  final StaffProductInventory batch;
  final String cosmeticName;

  @override
  ConsumerState<StaffInventoryDiscardView> createState() =>
      _StaffInventoryDiscardViewState();
}

class _StaffInventoryDiscardViewState
    extends ConsumerState<StaffInventoryDiscardView> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _quantityController;
  bool _submitting = false;
  String? _failure;

  @override
  void initState() {
    super.initState();
    _quantityController = TextEditingController(
      text: widget.batch.stockQuantity.toString(),
    );
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _discard() async {
    if (_submitting || !_formKey.currentState!.validate()) return;
    final quantity = int.parse(_quantityController.text.trim());
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('재고 폐기 확인'),
        content: Text(
          '${widget.cosmeticName}\n'
          '재고: ${widget.batch.inventoryId}\n'
          '폐기 수량: $quantity개\n\n'
          '폐기 후 재고 수량이 차감됩니다. 진행하시겠습니까?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('폐기 확정'),
          ),
        ],
      ),
    );
    if (!mounted || approved != true) return;

    setState(() {
      _submitting = true;
      _failure = null;
    });
    try {
      final result = await ref.read(staffInventoryServiceProvider).discardInventory(
        inventoryId: widget.batch.inventoryId,
        quantity: quantity,
      );
      if (!mounted) return;
      final remaining = result['stock_quantity'];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$quantity개 폐기 완료 · 남은 수량 $remaining개')),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _failure = '$error');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final batch = widget.batch;
    final theme = Theme.of(context);
    final allowed = batch.inventoryStatus == InventoryStatus.DISCARD &&
        batch.stockQuantity > 0;
    return Scaffold(
      appBar: AppBar(title: const Text('재고 폐기 처리')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            children: [
              Text(
                widget.cosmeticName,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              _Detail(label: '옵션 ID', value: batch.cosmeticId),
              _Detail(label: '재고 ID', value: batch.inventoryId),
              _Detail(label: '재고 상태', value: batch.inventoryStatus.name),
              _Detail(label: '현재 수량', value: '${batch.stockQuantity}개'),
              const Divider(height: 36),
              if (!allowed)
                const Text('폐기는 수량이 남아 있는 DISCARD 재고만 가능합니다.'),
              if (allowed) ...[
                Form(
                  key: _formKey,
                  child: TextFormField(
                    controller: _quantityController,
                    enabled: !_submitting,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: '폐기 수량',
                      helperText: '현재 재고 수량 이내의 정수를 입력하세요.',
                      border: OutlineInputBorder(),
                    ),
                    validator: (input) {
                      final value = int.tryParse(input?.trim() ?? '');
                      if (value == null || value < 1) {
                        return '1 이상의 정수를 입력하세요.';
                      }
                      if (value > batch.stockQuantity) {
                        return '현재 재고 수량을 초과할 수 없습니다.';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 20),
                if (_failure != null) ...[
                  Text(
                    _failure!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                  const SizedBox(height: 12),
                ],
                FilledButton.icon(
                  onPressed: _submitting ? null : _discard,
                  icon: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_forever_outlined),
                  label: Text(_submitting ? '폐기 처리 중...' : '재고 폐기'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 90, child: Text(label)),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
