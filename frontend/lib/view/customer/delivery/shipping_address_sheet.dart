import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beauty_project/model/customer/shipping_address.dart';
import 'package:beauty_project/vm/customer/customer_auth_validation.dart';
import 'address_search_screen.dart';

Future<ShippingAddress?> showShippingAddressSheet(
  BuildContext context,
  ShippingAddress? initial, {
  bool includeRecipient = true,
}) => showModalBottomSheet<ShippingAddress>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => ShippingAddressSheet(
    initial: initial,
    includeRecipient: includeRecipient,
  ),
);

class ShippingAddressSheet extends ConsumerStatefulWidget {
  const ShippingAddressSheet({
    super.key,
    required this.initial,
    this.includeRecipient = true,
  });
  final ShippingAddress? initial;
  final bool includeRecipient;

  @override
  ConsumerState<ShippingAddressSheet> createState() =>
      ShippingAddressSheetState();
}

class ShippingAddressSheetState extends ConsumerState<ShippingAddressSheet> {
  final _form = GlobalKey<FormState>();
  late final _recipient = TextEditingController(
    text: widget.initial?.recipient ?? '',
  );
  late final _phone = TextEditingController(text: widget.initial?.phone ?? '');
  late final _address = TextEditingController(
    text: widget.initial?.address ?? '',
  );
  final _detail = TextEditingController();
  bool _searching = false;

  String get _fullAddress => [
    _address.text.trim(),
    _detail.text.trim(),
  ].where((part) => part.isNotEmpty).join(' ');

  Future<void> _search() async {
    if (_searching) return;
    setState(() => _searching = true);
    try {
      final result = await ref.read(addressSearchLauncherProvider)(context);
      if (!mounted || result == null) return;
      _address.text = result.formatted;
      _detail.clear();
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  void dispose() {
    _recipient.dispose();
    _phone.dispose();
    _address.dispose();
    _detail.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '배송지 변경',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            if (widget.includeRecipient) ...[
              TextFormField(
                key: const Key('shipping-recipient'),
                controller: _recipient,
                decoration: const InputDecoration(labelText: '받는 분'),
                validator: CustomerAuthValidation.name,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('shipping-phone'),
                controller: _phone,
                decoration: const InputDecoration(labelText: '연락처'),
                validator: CustomerAuthValidation.phone,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
            ],
            OutlinedButton.icon(
              key: const Key('search-shipping-address'),
              onPressed: _searching ? null : _search,
              icon: const Icon(Icons.search),
              label: const Text('우편번호 · 주소 검색'),
            ),
            const SizedBox(height: 8),
            TextFormField(
              key: const Key('shipping-address'),
              controller: _address,
              decoration: const InputDecoration(
                labelText: '배송 주소',
                helperText: '검색하거나 직접 입력해 주세요.',
              ),
              maxLines: 2,
              maxLength: 500,
              validator: (value) => value == null || value.trim().isEmpty
                  ? '배송 주소를 입력해 주세요.'
                  : _fullAddress.length > 500
                  ? '상세주소를 포함해 500자 이내로 입력해 주세요.'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('shipping-address-detail'),
              controller: _detail,
              decoration: const InputDecoration(labelText: '상세주소 (동·호수 등)'),
              maxLength: 200,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('save-shipping-address'),
              onPressed: () {
                if (!_form.currentState!.validate()) return;
                Navigator.pop(
                  context,
                  ShippingAddress(
                    recipient: _recipient.text.trim(),
                    phone: _phone.text.trim(),
                    address: _fullAddress,
                  ),
                );
              },
              child: const Text('배송지 저장'),
            ),
          ],
        ),
      ),
    ),
  );
}
