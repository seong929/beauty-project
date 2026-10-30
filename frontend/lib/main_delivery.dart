import 'package:flutter/material.dart';
import 'app/bootstrap.dart';
import 'view/auth/carrier_login_page.dart';

Future<void> main() => launchApp(
  const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: CarrierLoginPage(),
  ),
);

// 기존 배송업체 로그인은 전용 진입점으로 유지한다: flutter run -t lib/main_delivery.dart
