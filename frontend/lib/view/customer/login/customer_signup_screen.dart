import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:beauty_project/model/customer/customers.dart';
import 'package:beauty_project/vm/customer/customer_auth_validation.dart';
import 'package:beauty_project/vm/customer/auth/customer_registration_model.dart';

import 'customer_auth_widgets.dart';

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
  final _birthYear = TextEditingController();
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
      _birthYear,
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
      (CustomerAuthValidation.address(_address.text), _addressFocus),
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
    final registration = Customers(
      loginId: _loginId.text,
      password: _password.text,
      name: _name.text,
      email: _email.text,
      address: _address.text,
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
                '소담과 함께해요',
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
                    flex: 3,
                    child: Semantics(
                      label: '고객 아이디',
                      child: TextFormField(
                        key: _idKey,
                        controller: _loginId,
                        focusNode: _loginIdFocus,
                        onChanged: _clearError,
                        onFieldSubmitted: (_) => _nameFocus.requestFocus(),
                        enabled: !isBusy,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        validator: CustomerAuthValidation.loginId,
                        autocorrect: false,
                        autofillHints: const [AutofillHints.newUsername],
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 7,
                    child: SizedBox(
                      height: 44,
                      child: Center(
                        child: SizedBox(
                          width: double.infinity,
                          height: 28,
                          child: OutlinedButton(
                            key: const Key('check-login-id'),
                            onPressed: null,
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.zero,
                              foregroundColor: SodamStyle.ink,
                              side: const BorderSide(color: SodamStyle.border),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text(
                              '중복 확인 · 준비 중',
                              style: TextStyle(
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
                validator: CustomerAuthValidation.address,
                autofillHints: const [AutofillHints.fullStreetAddress],
              ),
              const SizedBox(height: 16),
              CustomerField(
                label: '출생연도 (선택·통계용)',
                fieldKey: const Key('signup-birth-year'),
                controller: _birthYear,
                hint: '예: 1997',
                enabled: false,
                suffix: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  child: Text(
                    '준비 중',
                    style: TextStyle(fontSize: 10, color: SodamStyle.muted),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const CustomerFieldLabel('성별 (선택·통계용)'),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                key: const Key('signup-gender'),
                initialValue: 'UNDISCLOSED',
                disabledHint: const Center(child: Text('미입력 · 준비 중')),
                isExpanded: true,
                icon: const SizedBox.shrink(),
                alignment: Alignment.center,
                style: const TextStyle(
                  fontFamily: 'NotoSansKR',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: SodamStyle.ink,
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'UNDISCLOSED',
                    child: Center(child: Text('미입력 · 준비 중')),
                  ),
                ],
                onChanged: null,
              ),
              const SizedBox(height: 14),
              const Text(
                '출생연도·성별 입력은 준비 중이며 회원가입에 필요하지 않아요.\n아이디·이메일 중복은 가입 시 확인됩니다.',
                style: TextStyle(
                  fontSize: 11,
                  height: 1.7,
                  color: SodamStyle.muted,
                ),
              ),
              const SizedBox(height: 24),
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
