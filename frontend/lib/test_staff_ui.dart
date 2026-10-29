import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'service/staff/staff_inventory_service.dart';
import 'view/staff/staff_inventory_view.dart';
import 'vm/staff/staff_inventory_vm.dart';

// ===================== 테스트 실행 설정 =====================
// true : POST /tmp/staff-auth-grant 임시 직원 인증 (개발 환경에서만 사용)
// false: 임시 인증을 사용하지 않고 로그인 JWT로 직원 인증
const bool enableTemporaryStaffAuth = true;

// 이후 실제 로그인 화면에서 발급받은 JWT를 전달할 위치.
// 임시 인증 OFF 시 반드시 실제 직원 로그인 JWT로 교체하세요.
const String loginStaffAccessToken = '';

// Flutter Web의 HttpOnly 임시 쿠키와 SameSite=Strict 호환을 위해
// 웹 주소도 반드시 127.0.0.1로 실행하세요. (예: --web-hostname 127.0.0.1)
// Flutter를 실행하는 컴퓨터와 FastAPI 서버가 같을 때 사용할 주소.
const String apiBaseUrl = 'http://10.0.2.2:8000';
// ===========================================================

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final service = StaffInventoryService(
    baseUrl: apiBaseUrl,
    enableTemporaryAuth: enableTemporaryStaffAuth,
    accessToken: enableTemporaryStaffAuth ? null : loginStaffAccessToken,
  );

  runApp(
    ProviderScope(
      overrides: [
        staffInventoryServiceProvider.overrideWithValue(service),
      ],
      child: StaffInventoryTestApp(service: service),
    ),
  );
}

class StaffInventoryTestApp extends StatefulWidget {
  const StaffInventoryTestApp({super.key, required this.service});

  final StaffInventoryService service;

  @override
  State<StaffInventoryTestApp> createState() => _StaffInventoryTestAppState();
}

class _StaffInventoryTestAppState extends State<StaffInventoryTestApp> {
  late Future<void> _authFuture;
  String _stage = '시작 대기';

  void _reportStage(String stage) {
    debugPrint('[STAFF TEST] $stage');
    if (mounted) {
      setState(() => _stage = stage);
    }
  }

  Future<void> _runConnectionTest() async {
    debugPrint('[STAFF TEST] test_ui.dart active');
    debugPrint('[STAFF TEST] API base: $apiBaseUrl');
    if (kIsWeb) {
      debugPrint('[STAFF TEST] Flutter Web origin: ${Uri.base.origin}');
      if (Uri.base.scheme == 'https') {
        throw const StaffInventoryApiException(
          'Flutter Web이 HTTPS로 실행 중이므로 HTTP API가 브라우저에서 차단될 수 있습니다. '
          '개발 서버를 HTTP로 실행하거나 API도 HTTPS로 설정하세요.',
        );
      }
      final apiHost = Uri.parse(apiBaseUrl).host;
      if (Uri.base.host != apiHost) {
        throw StaffInventoryApiException(
          'Flutter Web 호스트(${Uri.base.host})와 API 호스트($apiHost)가 다릅니다. '
          '임시 쿠키 SameSite=Strict 사용 시 두 호스트를 일치시켜야 합니다. '
          'flutter run --web-hostname 127.0.0.1 --web-port 5300 옵션을 사용하세요.',
        );
      }
    }
    _reportStage('1/3 FastAPI /health 연결 중...');
    await widget.service.checkServerHealth();
    _reportStage('2/3 직원 인증 중...');
    await widget.service.initializeAuthentication();
    _reportStage('3/3 인증 성공, 재고 조회 화면 열기');
  }

  @override
  void initState() {
    super.initState();
    _authFuture = Future<void>.microtask(_runConnectionTest);
  }

  void _retryAuthentication() {
    setState(() {
      _stage = '재시도 시작';
      _authFuture = Future<void>.microtask(_runConnectionTest);
    });
  }

  @override
  void dispose() {
    widget.service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '직원 재고 관리 테스트',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: FutureBuilder<void>(
        future: _authFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(_stage),
                  ],
                ),
              ),
            );
          }

          if (snapshot.hasError) {
            return Scaffold(
              appBar: AppBar(title: const Text('직원 인증 실패')),
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 42),
                      const SizedBox(height: 12),
                      Text('진행 단계: $_stage', textAlign: TextAlign.center),
                      const SizedBox(height: 8),
                      SelectableText('${snapshot.error}', textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _retryAuthentication,
                        child: const Text('인증 재시도'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return const StaffInventoryView();
        },
      ),
    );
  }
}
