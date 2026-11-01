// 기능: 회원 기본 정보·성별·주소 수정과 오류 표시.
// 표시 계층: ref.watch로 상태를 구독하고 사용자 동작은 Notifier·서비스에 전달한다.

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beauty_project/vm/customer/state/customer_screen_handler.dart';
import 'package:beauty_project/vm/customer/customer_handler.dart';
import 'package:beauty_project/vm/customer/customer_auth_validation.dart';
import 'package:beauty_project/vm/customer/customer_profile_photo_handler.dart';
import 'package:beauty_project/model/customer/shipping_address.dart';
import '../delivery/shipping_address_sheet.dart';
import '../login/customer_auth_widgets.dart';

class CustomerProfileEditScreen extends ConsumerStatefulWidget {
  const CustomerProfileEditScreen({super.key, this.addressOnly = false});
  final bool addressOnly;

  @override
  ConsumerState<CustomerProfileEditScreen> createState() =>
      _CustomerProfileEditScreenState();
}

class _CustomerProfileEditScreenState
    extends ConsumerState<CustomerProfileEditScreen> {
  final _form = GlobalKey<FormState>();
  late final _customer = ref.read(customerHandlerProvider).value;
  late final _name = TextEditingController(text: _customer?.name ?? '');
  late final _email = TextEditingController(text: _customer?.email ?? '');
  late final _phone = TextEditingController(text: _customer?.phone ?? '');
  late final _address = TextEditingController(text: _customer?.address ?? '');
  late final _operationProvider = customerOperationProvider((
    screen: this,
    action: 'profile-save',
  ));
  CustomerOperationHandler get _operation =>
      ref.read(_operationProvider.notifier);
  bool get _busy => ref.read(_operationProvider).isLoading;
  String? get _error => ref.read(_operationProvider).error?.toString();
  late final _genderProvider = customerGenderProvider((
    screen: this,
    initial: _customer?.gender ?? 'UNDISCLOSED',
  ));
  String get _gender => ref.read(_genderProvider).value;
  late final _photoDraftProvider = customerProfilePhotoDraftProvider(this);
  late final _photoPickerOperationProvider = customerOperationProvider((
    screen: this,
    action: 'profile-photo-picker',
  ));
  bool get _picking => ref.read(_photoPickerOperationProvider).isLoading;

  /// Function: 갤러리 사진을 미리보기로만 선택한다. 저장 버튼 전에는 기존 사진을 바꾸지 않는다.
  Future<void> _pickPhoto() async {
    if (_busy || _picking) return;
    final operation = ref.read(_photoPickerOperationProvider.notifier);
    operation.begin();
    try {
      final bytes = await ref.read(customerProfilePhotoPickerProvider)();
      if (!mounted || bytes == null) return;
      ref.read(_photoDraftProvider.notifier).select((bytes: bytes));
    } catch (error) {
      if (!mounted) return;
      final message = error is PlatformException
          ? '사진을 선택할 수 없습니다. 휴대폰 설정에서 사진 접근 권한을 확인해 주세요.'
          : error is FormatException
          ? error.message
          : '사진을 읽을 수 없습니다. 다른 사진을 선택해 주세요.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) operation.finish();
    }
  }

  /// Function: 입력·포커스·스크롤 등 화면이 소유한 자원을 해제한다. Provider는 autoDispose 규칙을 따른다.
  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final result = await showShippingAddressSheet(
      context,
      ShippingAddress(
        recipient: _name.text,
        phone: _phone.text,
        address: _address.text,
      ),
      includeRecipient: false,
    );
    if (mounted && result != null) _address.text = result.address;
  }

  Future<void> _save() async {
    if (_busy || _picking || !_form.currentState!.validate()) return;
    if (_customer == null ||
        ref.read(customerHandlerProvider).value?.customerId !=
            _customer.customerId) {
      return;
    }
    _operation.begin();
    try {
      await ref
          .read(customerHandlerProvider.notifier)
          .updateProfile(
            name: _name.text,
            email: _email.text,
            phone: _phone.text,
            address: _address.text,
            gender: _gender,
            updateDemographics: !widget.addressOnly,
          );
      if (!mounted ||
          ref.read(customerHandlerProvider).value?.customerId !=
              _customer.customerId) {
        return;
      }
      // 회원 정보 수정이 성공했을 때만 고객별 기기 저장 사진도 갱신한다.
      final draft = ref.read(_photoDraftProvider).value;
      if (!widget.addressOnly && draft != null) {
        try {
          await ref
              .read(customerProfilePhotoProvider(_customer.customerId).notifier)
              .save(draft.bytes);
        } catch (_) {
          throw Exception('회원 정보는 저장되었지만 사진을 저장하지 못했습니다. 다시 저장해 주세요.');
        }
        if (!mounted ||
            ref.read(customerHandlerProvider).value?.customerId !=
                _customer.customerId) {
          return;
        }
      }
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) _operation.fail(error);
    } finally {
      if (mounted) _operation.finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(_operationProvider);
    ref.watch(_genderProvider);
    ref.watch(_photoPickerOperationProvider);
    final draft = ref.watch(_photoDraftProvider).value;
    final photo = _customer == null || widget.addressOnly
        ? const AsyncData<Uint8List?>(null)
        : ref.watch(customerProfilePhotoProvider(_customer.customerId));
    final photoBytes = draft == null ? photo.value : draft.bytes;
    return PopScope(
      canPop: !_busy && !_picking,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.addressOnly ? '배송 주소 관리' : '개인정보 수정'),
        ),
        body: _customer == null
            ? const Center(child: Text('로그인이 필요합니다.'))
            : AbsorbPointer(
                absorbing: _busy || _picking,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        Form(
                          key: _form,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (!widget.addressOnly) ...[
                                // 프로필 사진: 갤러리 선택·미리보기·기본 사진 복원
                                Center(
                                  child: Column(
                                    children: [
                                      buildCustomerProfileAvatar(
                                        bytes: photoBytes,
                                        radius: 44,
                                        key: const Key('profile-photo-preview'),
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        alignment: WrapAlignment.center,
                                        children: [
                                          TextButton.icon(
                                            key: const Key(
                                              'profile-photo-pick',
                                            ),
                                            onPressed: photo.isLoading
                                                ? null
                                                : _pickPhoto,
                                            icon: const Icon(
                                              Icons.photo_library_outlined,
                                            ),
                                            label: Text(
                                              _picking ? '사진 선택 중…' : '사진 변경',
                                            ),
                                          ),
                                          if (photoBytes != null)
                                            TextButton(
                                              key: const Key(
                                                'profile-photo-reset',
                                              ),
                                              onPressed: () => ref
                                                  .read(
                                                    _photoDraftProvider
                                                        .notifier,
                                                  )
                                                  .select((bytes: null)),
                                              child: const Text('기본 사진'),
                                            ),
                                        ],
                                      ),
                                      if (photo.isLoading || _picking)
                                        const LinearProgressIndicator(),
                                      if (photo.hasError && draft == null)
                                        TextButton(
                                          onPressed: () => ref.invalidate(
                                            customerProfilePhotoProvider(
                                              _customer.customerId,
                                            ),
                                          ),
                                          child: const Text(
                                            '저장된 사진을 불러오지 못했어요. 다시 조회',
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),
                                TextFormField(
                                  key: const Key('profile-name'),
                                  controller: _name,
                                  decoration: const InputDecoration(
                                    labelText: '이름',
                                  ),
                                  validator: CustomerAuthValidation.name,
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  key: const Key('profile-email'),
                                  controller: _email,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: const InputDecoration(
                                    labelText: '이메일',
                                  ),
                                  validator: CustomerAuthValidation.email,
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  key: const Key('profile-phone'),
                                  controller: _phone,
                                  keyboardType: TextInputType.phone,
                                  decoration: const InputDecoration(
                                    labelText: '연락처',
                                  ),
                                  validator: CustomerAuthValidation.phone,
                                ),
                                const SizedBox(height: 16),
                              ],
                              if (!widget.addressOnly) ...[
                                DropdownButtonFormField<String>(
                                  key: const Key('profile-gender'),
                                  initialValue: _gender,
                                  decoration: const InputDecoration(
                                    labelText: '성별 (선택)',
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'UNDISCLOSED',
                                      child: Text('미입력'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'M',
                                      child: Text('남성'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'F',
                                      child: Text('여성'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'OTHER',
                                      child: Text('기타'),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    if (value != null) {
                                      ref
                                          .read(_genderProvider.notifier)
                                          .select(value);
                                    }
                                  },
                                ),
                                const SizedBox(height: 16),
                              ],
                              OutlinedButton.icon(
                                onPressed: _search,
                                icon: const Icon(Icons.search),
                                label: const Text('주소 검색'),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                key: const Key('profile-address'),
                                controller: _address,
                                maxLines: 3,
                                maxLength: 500,
                                decoration: const InputDecoration(
                                  labelText: '기본 배송 주소',
                                ),
                                validator: (value) =>
                                    value == null ||
                                        value.trim().isEmpty ||
                                        value.trim().length > 500
                                    ? '주소를 1~500자로 입력해 주세요.'
                                    : null,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                '다음 주문에 사용할 기본 주소입니다. 이미 주문한 상품의 배송지는 구매 내역에서 변경해 주세요.',
                                style: TextStyle(fontSize: 12, height: 1.7),
                              ),
                              if (_error != null)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  child: Text(
                                    _error!,
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.error,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 20),
                              FilledButton(
                                key: const Key('profile-save'),
                                onPressed: _busy || _picking || photo.isLoading
                                    ? null
                                    : _save,
                                child: Text(_busy ? '저장 중…' : '저장'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

/// Function: 마이페이지와 편집 화면의 원형 사진·기본 표시·이미지 오류 표시를 통일한다.
Widget buildCustomerProfileAvatar({
  required Uint8List? bytes,
  required double radius,
  Key? key,
}) {
  const fallback = Text(
    '하나',
    style: TextStyle(fontSize: 16, color: SodamStyle.green),
  );
  return CircleAvatar(
    key: key,
    radius: radius,
    backgroundColor: const Color(0xFFD6F4F6),
    child: bytes == null
        ? fallback
        : ClipOval(
            child: Image.memory(
              bytes,
              width: radius * 2,
              height: radius * 2,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              semanticLabel: '고객 프로필 사진',
              errorBuilder: (_, _, _) => const Center(child: fallback),
            ),
          ),
  );
}

// 변경 내용(2026-10-30): 개인정보에서 성별을 수정하고 주소만 변경할 때는 기존 성별을 보존한다.
// 출생연도 입력과 관련 전송·검증을 제거했다.
