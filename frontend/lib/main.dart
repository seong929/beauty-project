import 'package:flutter/material.dart';
import 'app/bootstrap.dart';
import 'app/customer_app.dart';

Future<void> main() => launchApp(const MyApp());

// 기본 실행은 고객 전용이다. 관리자는 main_admin.dart로 실행한다.
class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) => const CustomerApp();
}

// 변경 내용(2026-10-30): 고객 UI의 최초 화면은 고객 로그인만 표시한다.
