import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../vm/admin/management_vm.dart';

class CosmeticCreatePage extends ConsumerStatefulWidget {
  const CosmeticCreatePage({super.key});

  @override
  ConsumerState<CosmeticCreatePage> createState() => _CosmeticCreatePageState();
}

class _CosmeticCreatePageState extends ConsumerState<CosmeticCreatePage> {
  final _formKey = GlobalKey<FormState>();
  final _fields = <String, TextEditingController>{
    for (final key in [
      'cosmetic_name',
      'manufacturer_id',
      'category_id',
      'sale_price',
      'unit_cost',
      'volume_text',
      'min_stock_qty',
      'target_stock_qty',
    ])
      key: TextEditingController(),
  };
  String _saleStatus = 'ON_SALE';

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Widget _field(
    String key,
    String label, {
    bool integer = false,
    bool money = false,
    int? maxLength,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: _fields[key],
        maxLength: maxLength,
        keyboardType: integer || money
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: (value) {
          final text = value?.trim() ?? '';
          if (text.isEmpty) return '필수 항목입니다.';
          if (integer) {
            final number = int.tryParse(text);
            if (number == null || number < 0 || number > 4294967295) {
              return '0 이상의 정수를 입력해 주세요.';
            }
          }
          if (money && (!RegExp(r'^\d{1,10}(\.\d{1,2})?$').hasMatch(text))) {
            return '0 이상의 금액을 소수 둘째 자리까지 입력해 주세요.';
          }
          return null;
        },
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final data = <String, dynamic>{
      for (final entry in _fields.entries) entry.key: entry.value.text.trim(),
      'sale_status': _saleStatus,
    };
    data['min_stock_qty'] = int.parse(data['min_stock_qty'] as String);
    data['target_stock_qty'] = int.parse(data['target_stock_qty'] as String);
    try {
      final result = await ref
          .read(managementActionsProvider.notifier)
          .createCosmetic(data);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('상품 ${result['cosmetic_id']} 등록 완료')),
      );
      for (final controller in _fields.values) {
        controller.clear();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(managementActionsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('상품 등록')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _field('cosmetic_name', '상품명', maxLength: 200),
                _field('manufacturer_id', '제조사 ID', maxLength: 48),
                _field('category_id', '카테고리 ID', maxLength: 48),
                _field('volume_text', '용량 (예: 50ml)', maxLength: 50),
                _field('sale_price', '판매 가격', money: true),
                _field('unit_cost', '상품 원가', money: true),
                _field('min_stock_qty', '최소 재고 수량', integer: true),
                _field('target_stock_qty', '목표 재고 수량', integer: true),
                DropdownButtonFormField<String>(
                  initialValue: _saleStatus,
                  decoration: const InputDecoration(
                    labelText: '판매 상태',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'ON_SALE', child: Text('판매 중')),
                    DropdownMenuItem(
                      value: 'DISCONTINUED',
                      child: Text('판매 중단'),
                    ),
                  ],
                  onChanged: (value) => setState(() => _saleStatus = value!),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: busy ? null : _submit,
                  child: Text(busy ? '등록 중...' : '상품 등록'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
