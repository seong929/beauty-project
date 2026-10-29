import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../vm/admin/management_vm.dart';
import '../../vm/admin/manufacturer_vm.dart';
import '../common/cosmetic_image_picker.dart';

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
  String? _manufacturerId;
  String? _categoryId;
  SelectedCosmeticImage? _image;
  String? _createdCosmeticId;
  bool _saving = false;

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
        enabled: !_saving && _createdCosmeticId == null,
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
    if (_saving) return;
    if (_createdCosmeticId == null && !_formKey.currentState!.validate())
      return;
    if (_image == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('상품 이미지를 선택해 주세요.')));
      return;
    }
    if (_manufacturerId == null || _categoryId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('등록된 발주처와 카테고리를 선택해 주세요.')));
      return;
    }
    final data = <String, dynamic>{
      for (final entry in _fields.entries) entry.key: entry.value.text.trim(),
      'sale_status': _saleStatus,
    };
    data['min_stock_qty'] = int.parse(data['min_stock_qty'] as String);
    data['target_stock_qty'] = int.parse(data['target_stock_qty'] as String);
    setState(() => _saving = true);
    try {
      if (_createdCosmeticId == null) {
        final result = await ref
            .read(managementActionsProvider.notifier)
            .createCosmetic(data);
        _createdCosmeticId = result['cosmetic_id'] as String;
      }
      await ref
          .read(managementActionsProvider.notifier)
          .uploadCosmeticImage(
            _createdCosmeticId!,
            _image!.bytes,
            _image!.filename,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('상품 $_createdCosmeticId 및 이미지 등록 완료')),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${_createdCosmeticId != null ? '상품은 등록되었습니다. 이미지를 다시 업로드해 주세요. ' : ''}${error.toString().replaceFirst('Exception: ', '')}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(managementActionsProvider) || _saving;
    final manufacturers = ref.watch(manufacturersProvider);
    final categories = ref.watch(categoryChoicesProvider);
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
                CosmeticImagePicker(
                  selected: _image,
                  enabled: !busy,
                  onChanged: (image) => setState(() => _image = image),
                ),
                if (_createdCosmeticId != null)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Text('상품 등록은 완료되었습니다. 이미지 업로드를 재시도해 주세요.'),
                  ),
                _field('cosmetic_name', '상품명', maxLength: 200),
                manufacturers.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (error, _) => Text('발주처 조회 실패: $error'),
                  data: (items) => DropdownButtonFormField<String>(
                    key: ValueKey(_manufacturerId),
                    initialValue: _manufacturerId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: '발주처',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final item in items)
                        DropdownMenuItem(
                          value: item.id,
                          child: Text(item.name),
                        ),
                    ],
                    validator: (value) =>
                        value == null ? '발주처를 선택해 주세요.' : null,
                    onChanged: busy || _createdCosmeticId != null
                        ? null
                        : (value) => setState(() {
                            _manufacturerId = value;
                            _fields['manufacturer_id']!.text = value ?? '';
                          }),
                  ),
                ),
                const SizedBox(height: 12),
                categories.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (error, _) => TextButton(
                    onPressed: () => ref.invalidate(categoryChoicesProvider),
                    child: const Text('카테고리 조회 실패 · 다시 시도'),
                  ),
                  data: (items) => DropdownButtonFormField<String>(
                    initialValue: _categoryId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: '카테고리 선택',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final item in items)
                        DropdownMenuItem(
                          value: item['category_id'] as String,
                          child: Text(item['category_name'] as String),
                        ),
                    ],
                    validator: (value) =>
                        value == null ? '카테고리를 선택해 주세요.' : null,
                    onChanged: busy || _createdCosmeticId != null
                        ? null
                        : (value) => setState(() {
                            _categoryId = value;
                            _fields['category_id']!.text = value ?? '';
                          }),
                  ),
                ),
                const SizedBox(height: 12),
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
                  onChanged: busy || _createdCosmeticId != null
                      ? null
                      : (value) => setState(() => _saleStatus = value!),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: busy ? null : _submit,
                  child: Text(
                    busy
                        ? '등록 중...'
                        : _createdCosmeticId == null
                        ? '상품 등록'
                        : '이미지 업로드 재시도',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
