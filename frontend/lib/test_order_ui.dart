import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'service/staff/staff_inventory_service.dart';
import 'view/staff/staff_order_view.dart';
import 'vm/staff/staff_inventory_vm.dart';

// Android Studio 기본 에뮬레이터 -> 호스트 PC FastAPI
const String apiBaseUrl = 'http://10.0.2.2:8000';

// 개발 전용 임시 직원 인증. 로그인 연동 뒤에는 false로 전환.
const bool enableTemporaryStaffAuth = true;
const String loginStaffAccessToken = '';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final service = StaffInventoryService(
    baseUrl: apiBaseUrl,
    enableTemporaryAuth: enableTemporaryStaffAuth,
    accessToken: enableTemporaryStaffAuth ? null : loginStaffAccessToken,
  );

  runApp(ProviderScope(
    overrides: [staffInventoryServiceProvider.overrideWithValue(service)],
    child: _OrderTestApp(service: service),
  ));
}

class _OrderTestApp extends StatefulWidget {
  const _OrderTestApp({required this.service});
  final StaffInventoryService service;

  @override
  State<_OrderTestApp> createState() => _OrderTestAppState();
}

class _OrderTestAppState extends State<_OrderTestApp> {
  late Future<void> _authentication;

  @override
  void initState() {
    super.initState();
    _authentication = widget.service.initializeAuthentication();
  }

  void _retry() {
    setState(() => _authentication = widget.service.initializeAuthentication());
  }

  @override
  void dispose() {
    widget.service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '직원 주문 조회',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      useMaterial3: true,
    ),
    home: FutureBuilder<void>(
      future: _authentication,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('직원 인증 중...'),
            ])),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('직원 인증 실패')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  SelectableText('인증 실패: ${snapshot.error}',
                      textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _retry, child: const Text('다시 인증')),
                ]),
              ),
            ),
          );
        }
        return const StaffOrderView();
      },
    ),
  );
}
