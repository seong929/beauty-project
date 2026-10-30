import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../vm/auth/auth_notifier.dart';
import '../../operations/operations_theme.dart';

class OperationsLoginPage extends ConsumerStatefulWidget {
  const OperationsLoginPage({super.key});
  @override
  ConsumerState<OperationsLoginPage> createState() =>
      _OperationsLoginPageState();
}

class _OperationsLoginPageState extends ConsumerState<OperationsLoginPage> {
  final _form = GlobalKey<FormState>();
  final _login = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  @override
  void dispose() {
    _login.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (ref.read(authProvider).isLoading || !_form.currentState!.validate()) {
      return;
    }
    await ref
        .read(authProvider.notifier)
        .login(loginId: _login.text.trim(), password: _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: CircleAvatar(
                          backgroundColor: Color(0xFFE8F2ED),
                          radius: 27,
                          child: Icon(
                            Icons.spa_outlined,
                            color: operationsGreen,
                            size: 28,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        '소담 본사 관리',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      const Text('관리자 계정으로 업무 공간에 로그인하세요.'),
                      const SizedBox(height: 28),
                      TextFormField(
                        controller: _login,
                        enabled: !auth.isLoading,
                        autofillHints: const [AutofillHints.username],
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: '로그인 아이디',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? '아이디를 입력해 주세요.'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _password,
                        enabled: !auth.isLoading,
                        obscureText: _obscure,
                        autofillHints: const [AutofillHints.password],
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: '비밀번호',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            tooltip: '비밀번호 표시 전환',
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: (value) => value == null || value.isEmpty
                            ? '비밀번호를 입력해 주세요.'
                            : null,
                      ),
                      if (auth.errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Text(
                            auth.errorMessage!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: auth.isLoading ? null : _submit,
                        child: Text(auth.isLoading ? '로그인 중…' : '관리자 로그인'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
