import 'package:flutter/material.dart';
import '../view/customer/login/customer_auth_widgets.dart';
import '../view/customer/login/customer_login_screen.dart';

class CustomerApp extends StatelessWidget {
  const CustomerApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '하나',
    debugShowCheckedModeBanner: false,
    theme: SodamStyle.theme,
    home: const CustomerLoginScreen(),
  );
}

// 변경 내용(2026-10-30): 고객 로그인·가입·홈만 사용하는 고객 전용 앱 진입 화면이다.
