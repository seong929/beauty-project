// Admin-only presentation. Shared STAFF/CUSTOMER views and business providers stay unchanged.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../vm/admin/management_vm.dart';
import '../../../vm/common/storage_image_handler.dart';
import '../../../vm/auth/auth_notifier.dart';
import '../../common/cosmetic_image_picker.dart';
import '../../common/cosmetic_image.dart';

class OperationsProductDetailPage extends ConsumerWidget {
  const OperationsProductDetailPage({super.key, required this.cosmeticId});
  final String cosmeticId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(cosmeticDetailsProvider(cosmeticId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('화장품 옵션 상세'),
        actions: [
          IconButton(
            tooltip: '새로고침',
            onPressed: ref.watch(managementActionsProvider)
                ? null
                : () {
                    ref.invalidate(cosmeticDetailsProvider(cosmeticId));
                    ref.invalidate(cosmeticImageProvider(cosmeticId));
                    ref.invalidate(storageImagesProvider);
                    ref.read(cosmeticImagesRevisionProvider.notifier).refresh();
                  },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: result.when(
        skipLoadingOnRefresh: false,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('옵션 조회 실패: $error')),
        data: (data) => _OptionForm(cosmeticId: cosmeticId, data: data),
      ),
    );
  }
}

// 변경 내용(2026-10-30): 고객과 같은 상품 이미지와 새로고침 경로를 사용한다.

class _OptionForm extends ConsumerStatefulWidget {
  const _OptionForm({required this.cosmeticId, required this.data});
  final String cosmeticId;
  final Map<String, dynamic> data;
  @override
  ConsumerState<_OptionForm> createState() => _OptionFormState();
}

class _OptionFormState extends ConsumerState<_OptionForm> {
  final form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> fields;
  String? status;
  SelectedCosmeticImage? _image;
  bool _saving = false;
  static const labels = {
    'sale_price': '판매 가격',
    'unit_cost': '상품 원가',
    'min_stock_qty': '최소 재고 수량',
    'target_stock_qty': '목표 재고 수량',
    'volume_text': '용량',
  };
  @override
  void initState() {
    super.initState();
    fields = {
      for (final key in labels.keys)
        key: TextEditingController(text: widget.data[key]?.toString() ?? ''),
    };
    final value = widget.data['sale_status'];
    status = value == 'ON_SALE' || value == 'DISCONTINUED'
        ? value as String
        : null;
  }

  @override
  void dispose() {
    for (final controller in fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _validate(String key, String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return '필수 항목입니다.';
    if (key == 'sale_price' || key == 'unit_cost') {
      return RegExp(r'^\d{1,10}(\.\d{1,2})?$').hasMatch(text)
          ? null
          : '0 이상의 금액을 소수 둘째 자리까지 입력해 주세요.';
    }
    if (key == 'volume_text') {
      return text.length <= 50 ? null : '50자 이내로 입력해 주세요.';
    }
    final quantity = int.tryParse(text);
    if (quantity == null || quantity < 0 || quantity > 4294967295) {
      return '0 이상의 정수를 입력해 주세요.';
    }
    if (key == 'target_stock_qty' &&
        quantity <=
            (int.tryParse(fields['min_stock_qty']!.text.trim()) ?? -1)) {
      return '목표 재고는 최소 재고보다 커야 합니다.';
    }
    return null;
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!form.currentState!.validate()) return;
    final data = <String, dynamic>{
      for (final entry in fields.entries) entry.key: entry.value.text.trim(),
      'sale_status': status,
    };
    data['min_stock_qty'] = int.parse(fields['min_stock_qty']!.text.trim());
    data['target_stock_qty'] = int.parse(
      fields['target_stock_qty']!.text.trim(),
    );
    setState(() => _saving = true);
    bool infoSaved = false;
    try {
      await ref
          .read(managementActionsProvider.notifier)
          .updateCosmeticDetails(widget.cosmeticId, data);
      infoSaved = true;
      if (_image != null) {
        await ref
            .read(managementActionsProvider.notifier)
            .uploadCosmeticImage(
              widget.cosmeticId,
              _image!.bytes,
              _image!.filename,
            );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('옵션 정보를 저장했습니다.')));
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${infoSaved && _image != null ? '옵션 정보는 저장되었습니다. 이미지 업로드를 다시 시도해 주세요. ' : ''}${error.toString().replaceFirst('Exception: ', '')}',
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
    final isAdmin = ref.watch(authProvider).isAdmin;
    final busy = ref.watch(managementActionsProvider) || _saving;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Form(
          key: form,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                widget.data['cosmetic_name']?.toString() ?? widget.cosmeticId,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(widget.cosmeticId),
              const SizedBox(height: 24),
              if (isAdmin)
                CosmeticImagePicker(
                  cosmeticId: widget.cosmeticId,
                  cosmeticName: widget.data['cosmetic_name']?.toString() ?? '',
                  selected: _image,
                  enabled: !busy,
                  onChanged: (image) => setState(() => _image = image),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: CosmeticImage(
                    cosmeticIds: [widget.cosmeticId],
                    cosmeticName:
                        widget.data['cosmetic_name']?.toString() ?? '',
                    size: 180,
                  ),
                ),
              for (final entry in labels.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: isAdmin
                      ? TextFormField(
                          controller: fields[entry.key],
                          enabled: !busy,
                          keyboardType: entry.key == 'volume_text'
                              ? TextInputType.text
                              : const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                          decoration: InputDecoration(
                            labelText: entry.value,
                            border: const OutlineInputBorder(),
                          ),
                          validator: (value) => _validate(entry.key, value),
                        )
                      : ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(entry.value),
                          subtitle: Text(
                            widget.data[entry.key]?.toString() ?? '미등록',
                          ),
                        ),
                ),
              if (isAdmin)
                DropdownButtonFormField<String>(
                  initialValue: status,
                  isExpanded: true,
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
                  validator: (value) =>
                      value == null ? '판매 상태를 선택해 주세요.' : null,
                  onChanged: busy
                      ? null
                      : (value) => setState(() => status = value),
                )
              else
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('판매 상태'),
                  subtitle: Text(
                    status == 'ON_SALE'
                        ? '판매 중'
                        : status == 'DISCONTINUED'
                        ? '판매 중단'
                        : '미등록',
                  ),
                ),
              if (isAdmin) ...[
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: busy ? null : _save,
                  child: Text(busy ? '저장 중...' : '변경사항 저장'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
