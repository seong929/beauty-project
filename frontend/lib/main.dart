import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'view/customer/login/customer_auth_widgets.dart';
import 'view/customer/login/customer_login_screen.dart';

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '소담',
    debugShowCheckedModeBanner: false,
    theme: SodamStyle.theme,
    home: const CustomerLoginScreen(),
    debugShowMaterialGrid: false,
  );
}
