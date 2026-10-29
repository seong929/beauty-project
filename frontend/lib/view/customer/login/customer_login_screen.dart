import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:beauty_project/vm/customer/customer_auth_validation.dart';
import 'package:beauty_project/vm/customer/customer_handler.dart';
import 'package:beauty_project/vm/customer/auth/customer_registration_model.dart';

import 'customer_auth_widgets.dart';
import 'customer_signup_screen.dart';
import '../home_screen.dart';

class CustomerLoginScreen extends ConsumerStatefulWidget {
  const CustomerLoginScreen({super.key});
  @override
  ConsumerState<CustomerLoginScreen> createState() =>
      _CustomerLoginScreenState();
}

class _CustomerLoginScreenState extends ConsumerState<CustomerLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _loginId = TextEditingController();
  final _password = TextEditingController();
  final _loginIdFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool _showPassword = false;
  bool _openingSignup = false;

  Future<void> _login() async {
    if (_openingSignup || ref.read(customerHandlerProvider).isLoading) return;
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final success = await ref
        .read(customerHandlerProvider.notifier)
        .login(loginId: _loginId.text, password: _password.text);
    if (!mounted || !success) return;
    _password.clear();
    Navigator.of(context).pushReplacement<void, void>(
      MaterialPageRoute(builder: (_) => const CustomerHomeScreen()),
    );
  }

  @override
  void dispose() {
    _loginId.dispose();
    _password.dispose();
    _loginIdFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _openSignup() async {
    if (_openingSignup || ref.read(customerHandlerProvider).isLoading) return;
    FocusScope.of(context).unfocus();
    setState(() => _openingSignup = true);
    ref.read(customerHandlerProvider.notifier).clearError();
    ref.read(customerRegistrationProvider.notifier).reset();
    try {
      final loginId = await Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (_) => const CustomerSignupScreen()),
      );
      if (!mounted) return;
      ref.read(customerHandlerProvider.notifier).clearError();
      if (loginId == null) return;
      _loginId.text = loginId;
      _password.clear();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('회원가입이 완료되었습니다.')));
    } finally {
      if (mounted) setState(() => _openingSignup = false);
    }
  }

  void _showNotice(String title, String message) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(customerHandlerProvider);
    final isBusy = auth.isLoading;
    final error = auth.hasError ? auth.error.toString() : '';
    return CustomerAuthLayout(
      title: '소담',
      padding: const EdgeInsets.fromLTRB(26, 54, 26, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '소담',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 48,
              height: 1.35,
              color: SodamStyle.green,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '나에게 맞는 아름다움, 소담하게.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: SodamStyle.muted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            '다시 만나 반가워요',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              height: 1.4,
              color: SodamStyle.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '로그인하고 나만의 뷰티 루틴을 찾아보세요.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: SodamStyle.muted,
            ),
          ),
          const SizedBox(height: 26),
          ...[
            CustomerAuthError(error.isEmpty ? null : error),
            AutofillGroup(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CustomerField(
                      label: '고객 아이디',
                      fieldKey: const Key('login-id'),
                      controller: _loginId,
                      focusNode: _loginIdFocus,
                      onSubmitted: (_) => _passwordFocus.requestFocus(),
                      hint: '아이디를 입력해 주세요',
                      validator: CustomerAuthValidation.loginId,
                      enabled: !isBusy,
                      autofillHints: const [AutofillHints.username],
                    ),
                    const SizedBox(height: 18),
                    CustomerField(
                      label: '비밀번호',
                      fieldKey: const Key('login-password'),
                      controller: _password,
                      focusNode: _passwordFocus,
                      isPassword: true,
                      validator: CustomerAuthValidation.password,
                      obscureText: !_showPassword,
                      enabled: !isBusy,
                      autofillHints: const [AutofillHints.password],
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _login(),
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
                    ),
                    const SizedBox(height: 14),
                    CustomerSubmitButton(
                      key: const Key('login-submit'),
                      label: '로그인',
                      height: 26,
                      isLoading: isBusy,
                      onPressed: isBusy || _openingSignup ? null : _login,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                TextButton(
                  key: const Key('open-signup'),
                  onPressed: isBusy || _openingSignup ? null : _openSignup,
                  child: const Text('처음이신가요? 회원가입'),
                ),
                TextButton(
                  onPressed: isBusy
                      ? null
                      : () => _showNotice(
                            '비밀번호 찾기',
                            '비밀번호 찾기는 준비 중입니다.',
                          ),
                  child: const Text('비밀번호 찾기'),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFEBEDF0)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              '나만의 뷰티 루틴을 소담과 함께 시작해 보세요.\n처음이신가요? 회원가입 후 로그인할 수 있습니다.',
              style: TextStyle(
                fontSize: 11,
                height: 1.6,
                color: Color(0xFF8B9096),
              ),
            ),
          ),
          SizedBox(
            height: 28,
            child: TextButton(
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              onPressed: () => _showNotice('배송·반품 안내', '배송·반품 안내는 준비 중입니다.'),
              child: const Text('배송·반품 안내 보기'),
            ),
          ),
        ],
      ),
    );
  }
}
