
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../vm/auth/carrier_auth_notifier.dart';
import '../delivery/delivery_page.dart';

class CarrierLoginPage extends ConsumerStatefulWidget {
  const CarrierLoginPage({super.key});

  @override
  ConsumerState<CarrierLoginPage> createState() =>
      _CarrierLoginPageState();
}

class _CarrierLoginPageState
    extends ConsumerState<CarrierLoginPage> {
  final TextEditingController _loginIdController =
      TextEditingController();

  final TextEditingController _passwordController =
      TextEditingController();

  final GlobalKey<FormState> _formKey =
      GlobalKey<FormState>();

  bool _obscurePassword = true;

  @override
  void dispose() {
    _loginIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final success = await ref
        .read(carrierAuthProvider.notifier)
        .login(
          loginId: _loginIdController.text.trim(),
          password: _passwordController.text,
        );

    if (!mounted) {
      return;
    }

    if (success) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const DeliveryPage(),
        ),
      );
    } else {
      final errorMessage =
          ref.read(carrierAuthProvider).errorMessage ??
              '로그인에 실패했습니다.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(carrierAuthProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('배송업체 로그인'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: '직원·관리자 로그인으로 돌아가기',
          onPressed: authState.isLoading
              ? null
              : () {
              Navigator.pop(context);
          },
        ),
      ),
      backgroundColor: const Color(0xFFF5F7FA),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 420,
            ),
            child: Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment:
                        CrossAxisAlignment.stretch,
                    children: [
                      const Icon(
                        Icons.local_shipping_outlined,
                        size: 64,
                        color: Colors.blue,
                      ),

                      const SizedBox(height: 16),

                      const Text(
                        '배송업체 로그인',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 8),

                      const Text(
                        '배송업체 담당자 계정으로 로그인하세요.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey,
                        ),
                      ),

                      const SizedBox(height: 32),

                      // 아이디 입력
                      TextFormField(
                        controller: _loginIdController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: '아이디',
                          prefixIcon:
                              Icon(Icons.person_outline),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null ||
                              value.trim().isEmpty) {
                            return '아이디를 입력해 주세요.';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // 비밀번호 입력
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) {
                          if (!authState.isLoading) {
                            _login();
                          }
                        },
                        decoration: InputDecoration(
                          labelText: '비밀번호',
                          prefixIcon:
                              const Icon(Icons.lock_outline),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() {
                                _obscurePassword =
                                    !_obscurePassword;
                              });
                            },
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '비밀번호를 입력해 주세요.';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 24),

                      // 로그인 버튼
                      SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed:
                              authState.isLoading ? null : _login,
                          child: authState.isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child:
                                      CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  '로그인',
                                  style: TextStyle(
                                    fontSize: 16,
                                  ),
                                ),
                        ),
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
