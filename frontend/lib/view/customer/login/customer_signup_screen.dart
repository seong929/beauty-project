import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:beauty_project/model/customer/customers.dart';
import 'package:beauty_project/vm/customer/customer_auth_validation.dart';
import 'package:beauty_project/vm/customer/auth/customer_registration_model.dart';

import 'customer_auth_widgets.dart';
import '../delivery/address_search_screen.dart';
import 'package:beauty_project/vm/customer/auth/login_id_availability.dart';

class CustomerSignupScreen extends ConsumerStatefulWidget {
  const CustomerSignupScreen({super.key});
  @override
  ConsumerState<CustomerSignupScreen> createState() =>
      _CustomerSignupScreenState();
}

class _CustomerSignupScreenState extends ConsumerState<CustomerSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _idKey = GlobalKey<FormFieldState<String>>();
  final _loginId = TextEditingController();
  final _name = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  final _address = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _addressDetail = TextEditingController();
  String _gender = 'UNDISCLOSED';
  bool _searching = false;
  final _loginIdFocus = FocusNode();
  final _nameFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmationFocus = FocusNode();
  final _addressFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _phoneFocus = FocusNode();
  bool _showPassword = false;
  bool _showConfirmation = false;
  bool _attemptedSubmit = false;

  @override
  void dispose() {
    for (final controller in [
      _loginId,
      _name,
      _password,
      _confirmation,
      _address,
      _email,
      _phone,
      _addressDetail,
    ]) {
      controller.dispose();
    }
    for (final node in [
      _loginIdFocus,
      _nameFocus,
      _passwordFocus,
      _confirmationFocus,
      _addressFocus,
      _emailFocus,
      _phoneFocus,
    ]) {
      node.dispose();
    }
    super.dispose();
  }

  String get _fullAddress => [
    _address.text.trim(),
    _addressDetail.text.trim(),
  ].where((part) => part.isNotEmpty).join(' ');

  Future<void> _searchAddress() async {
    if (_searching) return;
    setState(() => _searching = true);
    try {
      final result = await ref.read(addressSearchLauncherProvider)(context);
      if (!mounted || result == null) return;
      _address.text = result.formatted;
      _addressDetail.clear();
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _loginEdited(String value) {
    ref.read(loginIdAvailabilityProvider.notifier).edit(value);
    _clearError(value);
  }

  void _clearError(String _) {
    if (!ref.read(customerRegistrationProvider).hasError) return;
    ref.read(customerRegistrationProvider.notifier).clearError();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
  }

  void _focusFirstInvalidField() {
    final fields = <(String?, FocusNode)>[
      (CustomerAuthValidation.loginId(_loginId.text), _loginIdFocus),
      (CustomerAuthValidation.name(_name.text), _nameFocus),
      (CustomerAuthValidation.password(_password.text), _passwordFocus),
      (
        CustomerAuthValidation.confirmPassword(
          _confirmation.text,
          _password.text,
        ),
        _confirmationFocus,
      ),
      (CustomerAuthValidation.address(_fullAddress), _addressFocus),
      (CustomerAuthValidation.email(_email.text), _emailFocus),
      (CustomerAuthValidation.phone(_phone.text), _phoneFocus),
    ];
    for (final (error, node) in fields) {
      if (error == null) continue;
      node.requestFocus();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || node.context == null) return;
        Scrollable.ensureVisible(
          node.context!,
          alignment: 0.2,
          duration: const Duration(milliseconds: 200),
        );
      });
      return;
    }
  }

  Future<void> _register() async {
    if (ref.read(customerRegistrationProvider).isLoading) return;
    setState(() => _attemptedSubmit = true);
    if (!_formKey.currentState!.validate()) {
      _focusFirstInvalidField();
      return;
    }
    FocusScope.of(context).unfocus();
    if (!ref.read(loginIdAvailabilityProvider).confirmed(_loginId.text)) {
      _loginIdFocus.requestFocus();
      return;
    }
    final registration = Customers(
      loginId: _loginId.text,
      password: _password.text,
      name: _name.text,
      email: _email.text,
      address: _fullAddress,
      gender: _gender,
      phone: _phone.text,
    );
    final success = await ref
        .read(customerRegistrationProvider.notifier)
        .register(registration);
    if (!mounted) return;
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ref.read(customerRegistrationProvider).error?.toString() ??
                '회원가입을 다시 시도해 주세요.',
          ),
        ),
      );
      return;
    }
    Navigator.of(context).pop(registration.loginId.trim());
  }

  @override
  Widget build(BuildContext context) {
    final registration = ref.watch(customerRegistrationProvider);
    final isBusy = registration.isLoading;
    final availability = ref.watch(loginIdAvailabilityProvider);
    final error = registration.hasError ? registration.error.toString() : '';
    return CustomerAuthLayout(
      title: '회원가입',
      showBack: true,
      canPop: !isBusy,
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 32),
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          autovalidateMode: _attemptedSubmit
              ? AutovalidateMode.onUserInteraction
              : AutovalidateMode.disabled,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '하나와 함께해요',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  height: 1.4,
                  fontWeight: FontWeight.w700,
                  color: SodamStyle.ink,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                '쇼핑에 필요한 기본 정보만 입력해주세요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: SodamStyle.muted,
                ),
              ),
              const SizedBox(height: 24),
              CustomerAuthError(error.isEmpty ? null : error),
              const Padding(
                padding: EdgeInsets.only(left: 20),
                child: CustomerFieldLabel('고객 아이디', textAlign: TextAlign.left),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: Semantics(
                      label: '고객 아이디',
                      child: TextFormField(
                        key: _idKey,
                        controller: _loginId,
                        focusNode: _loginIdFocus,
                        onChanged: _loginEdited,
                        onFieldSubmitted: (_) => _nameFocus.requestFocus(),
                        enabled: !isBusy,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        validator: (value) =>
                            CustomerAuthValidation.loginId(value) ??
                            (_attemptedSubmit &&
                                    !availability.confirmed(value ?? '')
                                ? '아이디 중복 확인을 완료해 주세요.'
                                : null),
                        autocorrect: false,
                        autofillHints: const [AutofillHints.newUsername],
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 1,
                    child: SizedBox(
                      height: 44,
                      child: Center(
                        child: SizedBox(
                          width: double.infinity,
                          height: 28,
                          child: OutlinedButton(
                            key: const Key('check-login-id'),
                            onPressed: isBusy || availability.checking
                                ? null
                                : () => ref
                                      .read(
                                        loginIdAvailabilityProvider.notifier,
                                      )
                                      .check(_loginId.text),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.zero,
                              foregroundColor: SodamStyle.ink,
                              side: const BorderSide(color: SodamStyle.border),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              availability.checking ? '확인 중…' : '중복 확인',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (availability.checking ||
                  availability.available != null ||
                  availability.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    availability.error ??
                        (availability.checking
                            ? '아이디를 확인하고 있어요.'
                            : availability.available == true
                            ? '사용 가능한 아이디입니다.'
                            : '이미 사용 중인 아이디입니다.'),
                    key: const Key('login-id-availability'),
                    style: TextStyle(
                      fontSize: 11,
                      color:
                          availability.available == false ||
                              availability.error != null
                          ? Theme.of(context).colorScheme.error
                          : SodamStyle.ink,
                    ),
                  ),
                ),
              CustomerField(
                label: '이름',
                fieldKey: const Key('signup-name'),
                controller: _name,
                focusNode: _nameFocus,
                onChanged: _clearError,
                onSubmitted: (_) => _passwordFocus.requestFocus(),
                enabled: !isBusy,
                validator: CustomerAuthValidation.name,
                autofillHints: const [AutofillHints.name],
              ),
              const SizedBox(height: 16),
              CustomerField(
                label: '비밀번호',
                fieldKey: const Key('signup-password'),
                controller: _password,
                focusNode: _passwordFocus,
                isPassword: true,
                onChanged: _clearError,
                onSubmitted: (_) => _confirmationFocus.requestFocus(),
                enabled: !isBusy,
                validator: CustomerAuthValidation.password,
                obscureText: !_showPassword,
                suffix: CustomerPasswordToggle(
                  visible: _showPassword,
                  onPressed: isBusy
                      ? null
                      : () {
                          final selection = _password.selection;
                          setState(() => _showPassword = !_showPassword);
                          _passwordFocus.requestFocus();
                          if (selection.isValid) {
                            _password.selection = selection;
                          }
                        },
                ),
                autofillHints: const [AutofillHints.newPassword],
              ),
              const SizedBox(height: 16),
              CustomerField(
                label: '비밀번호 확인',
                fieldKey: const Key('signup-confirmation'),
                controller: _confirmation,
                focusNode: _confirmationFocus,
                isPassword: true,
                onChanged: _clearError,
                onSubmitted: (_) => _addressFocus.requestFocus(),
                enabled: !isBusy,
                validator: (value) => CustomerAuthValidation.confirmPassword(
                  value,
                  _password.text,
                ),
                obscureText: !_showConfirmation,
                suffix: CustomerPasswordToggle(
                  visible: _showConfirmation,
                  onPressed: isBusy
                      ? null
                      : () {
                          final selection = _confirmation.selection;
                          setState(
                            () => _showConfirmation = !_showConfirmation,
                          );
                          _confirmationFocus.requestFocus();
                          if (selection.isValid) {
                            _confirmation.selection = selection;
                          }
                        },
                ),
                autofillHints: const [AutofillHints.newPassword],
              ),
              const SizedBox(height: 16),
              CustomerField(
                label: '기본 주소',
                fieldKey: const Key('signup-address'),
                controller: _address,
                focusNode: _addressFocus,
                onChanged: _clearError,
                onSubmitted: (_) => _emailFocus.requestFocus(),
                enabled: !isBusy,
                validator: (_) => CustomerAuthValidation.address(_fullAddress),
                autofillHints: const [AutofillHints.fullStreetAddress],
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                key: const Key('signup-search-address'),
                onPressed: isBusy || _searching ? null : _searchAddress,
                icon: const Icon(Icons.search, size: 18),
                label: Text(_searching ? '주소 검색 중…' : '우편번호 · 주소 검색'),
              ),
              const SizedBox(height: 12),
              CustomerField(
                label: '상세주소 (동·호수 등)',
                fieldKey: const Key('signup-address-detail'),
                controller: _addressDetail,
                enabled: !isBusy,
                onChanged: _clearError,
                validator: (_) => _fullAddress.length > 500
                    ? '주소는 상세주소를 포함해 500자 이내로 입력해 주세요.'
                    : null,
              ),
              const SizedBox(height: 16),
              const CustomerFieldLabel('성별 (선택)'),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                key: const Key('signup-gender'),
                initialValue: _gender,
                isExpanded: true,
                style: const TextStyle(
                  fontFamily: 'NotoSansKR',
                  fontSize: 14,
                  color: SodamStyle.ink,
                ),
                items: const [
                  DropdownMenuItem(value: 'UNDISCLOSED', child: Text('미입력')),
                  DropdownMenuItem(value: 'M', child: Text('남성')),
                  DropdownMenuItem(value: 'F', child: Text('여성')),
                  DropdownMenuItem(value: 'OTHER', child: Text('기타')),
                ],
                onChanged: isBusy
                    ? null
                    : (value) {
                        if (value != null) setState(() => _gender = value);
                      },
              ),
              const SizedBox(height: 16),
              CustomerField(
                label: '이메일',
                fieldKey: const Key('signup-email'),
                controller: _email,
                focusNode: _emailFocus,
                onChanged: _clearError,
                onSubmitted: (_) => _phoneFocus.requestFocus(),
                hint: 'example@email.com',
                enabled: !isBusy,
                validator: CustomerAuthValidation.email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
              ),
              const SizedBox(height: 16),
              CustomerField(
                label: '전화번호',
                fieldKey: const Key('signup-phone'),
                controller: _phone,
                focusNode: _phoneFocus,
                onChanged: _clearError,
                hint: '010-1234-5678',
                enabled: !isBusy,
                validator: CustomerAuthValidation.phone,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.telephoneNumber],
                onSubmitted: (_) {
                  if (!isBusy) _register();
                },
              ),
              const SizedBox(height: 24),
              CustomerSubmitButton(
                key: const Key('signup-submit'),
                label: '가입하기',
                isLoading: isBusy,
                onPressed: isBusy ? null : _register,
              ),
              const SizedBox(height: 14),
              TextButton(
                onPressed: isBusy ? null : () => Navigator.pop(context),
                child: const Text('이미 계정이 있으신가요? 로그인'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 변경 내용(2026-10-30): 실제 아이디 중복 확인, Daum 주소 검색·상세주소, 선택 성별 저장을 연결한다.
// 출생연도 입력과 관련 전송·검증을 제거했다.
// 아이디를 수정하면 기존 확인 결과가 취소되며, 중복 확인을 완료해야 가입할 수 있다.
