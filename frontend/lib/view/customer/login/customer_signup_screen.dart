// 기능: 회원가입 UI와 리소스·상태·검증·요청·화면 이동을 한 파일에서 관리한다.
// build()의 구간 주석 순서대로 입력 UI를 수정하고, 동작은 전용 함수에서 처리한다.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beauty_project/vm/customer/state/customer_screen_handler.dart';

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
  // 입력 리소스는 이 화면에서 생성하고 dispose한다.
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
  late final _formProvider = customerAuthFormProvider(this);
  CustomerAuthFormHandler get _formActions => ref.read(_formProvider.notifier);
  String get _gender => ref.read(_formProvider).gender;
  bool get _searching => ref.read(_formProvider).searchingAddress;
  final _loginIdFocus = FocusNode();
  final _nameFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmationFocus = FocusNode();
  final _addressFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _phoneFocus = FocusNode();
  bool get _showPassword => ref.read(_formProvider).showPassword;
  bool get _showConfirmation => ref.read(_formProvider).showConfirmation;
  bool get _attemptedSubmit => ref.read(_formProvider).attemptedSubmit;

  /// Function: 입력·포커스·스크롤 등 화면이 소유한 자원을 해제한다. Provider는 autoDispose 규칙을 따른다.
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

  /// Function: 주소 검색 창의 실행 상태와 취소·선택 결과를 처리한다.
  Future<void> _searchAddress() async {
    if (_searching) return;
    _formActions.searchingAddress(true);
    try {
      final result = await ref.read(addressSearchLauncherProvider)(context);
      if (!mounted || result == null) return;
      _address.text = result.formatted;
      _addressDetail.clear();
    } finally {
      if (mounted) _formActions.searchingAddress(false);
    }
  }

  /// Function: 아이디 변경 시 기존 중복 확인 결과와 가입 오류를 정리한다.
  void _loginEdited(String value) {
    ref.read(loginIdAvailabilityProvider.notifier).edit(value);
    _clearError(value);
  }

  /// Function: 입력 수정 후 기존 가입 실패 안내를 지운다.
  void _clearError(String _) {
    if (!ref.read(customerRegistrationProvider).hasError) return;
    ref.read(customerRegistrationProvider.notifier).clearError();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
  }

  /// Function: 제출 시 첫 번째 유효하지 않은 입력으로 포커스와 스크롤을 이동한다.
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

  /// Function: 가입 폼·아이디 중복 확인을 검증하고 회원가입 VM에 전달한다.
  Future<void> _register() async {
    if (ref.read(customerRegistrationProvider).isLoading) return;
    _formActions.attemptSubmit();
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

  /// Function: 비밀번호·비밀번호 확인의 같은 입력 UI와 표시 버튼을 재사용한다.
  Widget _buildPasswordField({
    required bool confirmation,
    required bool isBusy,
  }) {
    final visible = confirmation ? _showConfirmation : _showPassword;
    return CustomerField(
      label: confirmation ? '비밀번호 확인' : '비밀번호',
      fieldKey: confirmation
          ? const Key('signup-confirmation')
          : const Key('signup-password'),
      controller: confirmation ? _confirmation : _password,
      focusNode: confirmation ? _confirmationFocus : _passwordFocus,
      isPassword: true,
      onChanged: _clearError,
      onSubmitted: (_) =>
          (confirmation ? _addressFocus : _confirmationFocus).requestFocus(),
      enabled: !isBusy,
      validator: confirmation
          ? (value) =>
                CustomerAuthValidation.confirmPassword(value, _password.text)
          : CustomerAuthValidation.password,
      obscureText: !visible,
      suffix: CustomerPasswordToggle(
        visible: visible,
        onPressed: isBusy
            ? null
            : () => _togglePasswordVisibility(confirmation),
      ),
      autofillHints: const [AutofillHints.newPassword],
    );
  }

  /// Function: 비밀번호 표시 상태를 바꾸고 해당 입력의 포커스·커서 위치를 보존한다.
  void _togglePasswordVisibility(bool confirmation) {
    final controller = confirmation ? _confirmation : _password;
    final focus = confirmation ? _confirmationFocus : _passwordFocus;
    final selection = controller.selection;
    if (confirmation) {
      _formActions.toggleConfirmation();
    } else {
      _formActions.togglePassword();
    }
    focus.requestFocus();
    if (selection.isValid) controller.selection = selection;
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(_formProvider);
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
              // 안내 문구·가입 오류
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

              // 아이디: 입력·중복 확인·확인 결과 표시
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

              // 이름
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

              // 비밀번호·비밀번호 확인: 반복되는 입력 UI는 공통 함수 사용
              _buildPasswordField(confirmation: false, isBusy: isBusy),
              const SizedBox(height: 16),
              _buildPasswordField(confirmation: true, isBusy: isBusy),
              const SizedBox(height: 16),

              // 주소: 기본 주소·검색·상세주소
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

              // 성별: 선택 입력
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
                        if (value != null) _formActions.selectGender(value);
                      },
              ),
              const SizedBox(height: 16),

              // 연락처: 이메일·전화번호·마지막 입력에서 가입 실행
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

              // 가입 버튼: 요청 중 비활성화·로딩 표시·로그인 화면 복귀
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
