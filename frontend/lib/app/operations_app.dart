import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../view/admin/operations/login_page.dart';
import '../view/admin/operations/workspace.dart';
import '../view/operations/operations_theme.dart';
import '../vm/auth/auth_notifier.dart';
import '../vm/auth/auth_state.dart';

/// Separate entry and per-session container: no changes to the customer/staff app.
class OperationsApp extends ConsumerStatefulWidget {
  const OperationsApp({super.key});
  @override
  ConsumerState<OperationsApp> createState() => _OperationsAppState();
}

class _OperationsAppState extends ConsumerState<OperationsApp> {
  final _navigator = GlobalKey<NavigatorState>();
  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    ref.listen(authProvider, (previous, next) {
      if (previous?.employee != next.employee) {
        _navigator.currentState?.popUntil((route) => route.isFirst);
      }
    });
    return MaterialApp(
      navigatorKey: _navigator,
      title: '소담 · 관리자 업무',
      debugShowCheckedModeBanner: false,
      theme: operationsTheme(),
      home: auth.isAdmin
          ? _OperationsSession(
              key: ValueKey(auth.employee),
              auth: auth,
              onLogout: () => ref.read(authProvider.notifier).logout(),
              onExpire: () => ref.read(authProvider.notifier).expireSession(),
            )
          : auth.isStaff
          ? Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.admin_panel_settings_outlined, size: 40),
                      const SizedBox(height: 16),
                      const Text(
                        '관리자 전용 업무 공간입니다. 직원 화면은 기존 실행 경로를 이용해 주세요.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: () =>
                            ref.read(authProvider.notifier).logout(),
                        child: const Text('다른 계정으로 로그인'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : const OperationsLoginPage(),
    );
  }
}

class _OperationsSession extends StatefulWidget {
  const _OperationsSession({
    super.key,
    required this.auth,
    required this.onLogout,
    required this.onExpire,
  });
  final AuthState auth;
  final VoidCallback onLogout, onExpire;
  @override
  State<_OperationsSession> createState() => _OperationsSessionState();
}

class _OperationsSessionState extends State<_OperationsSession> {
  late final ProviderContainer _container = ProviderContainer(
    overrides: [
      authProvider.overrideWith(
        () => _SessionAuth(widget.auth, widget.onLogout, widget.onExpire),
      ),
    ],
  );
  @override
  void dispose() {
    _container.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => UncontrolledProviderScope(
    container: _container,
    child: HeroControllerScope.none(
      child: Navigator(
        onGenerateRoute: (_) => MaterialPageRoute<void>(
          builder: (_) => const OperationsWorkspace(),
        ),
      ),
    ),
  );
}

class _SessionAuth extends AuthNotifier {
  _SessionAuth(this.auth, this.onLogout, this.onExpire);
  final AuthState auth;
  final VoidCallback onLogout, onExpire;
  @override
  AuthState build() => auth;
  @override
  void logout() => onLogout();
  @override
  void expireSession() => onExpire();
}
