import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'design/sodam_shell.dart';
import 'design/sodam_theme.dart';
import 'view/auth/login_page.dart';
import 'vm/auth/auth_notifier.dart';
import 'vm/auth/auth_state.dart';

// Optional UI entry point. Existing main.dart and business code stay intact.
// Images use the authenticated backend API; this entry needs no Firebase SDK init.
void main() => runApp(const ProviderScope(child: SodamApp()));

class SodamApp extends ConsumerStatefulWidget {
  const SodamApp({super.key});

  @override
  ConsumerState<SodamApp> createState() => _SodamAppState();
}

class _SodamAppState extends ConsumerState<SodamApp> {
  final navigator = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    ref.listen(authProvider, (previous, next) {
      if (previous?.isLoggedIn == true && !next.isLoggedIn) {
        navigator.currentState?.popUntil((route) => route.isFirst);
      }
    });
    // A fresh provider scope for each session prevents cached business data
    // from being reused when a different employee logs in.
    return MaterialApp(
      navigatorKey: navigator,
      debugShowCheckedModeBanner: false,
      title: '소담 · 본사 관리',
      theme: sodamTheme(),
      home: auth.isAdmin || auth.isStaff
          ? _SodamSession(
              key: ValueKey(auth.employee),
              auth: auth,
              onLogout: () => ref.read(authProvider.notifier).logout(),
              onExpire: () => ref.read(authProvider.notifier).expireSession(),
            )
          : const LoginPage(),
    );
  }
}

class _SodamSession extends StatefulWidget {
  const _SodamSession({
    super.key,
    required this.auth,
    required this.onLogout,
    required this.onExpire,
  });
  final AuthState auth;
  final VoidCallback onLogout, onExpire;

  @override
  State<_SodamSession> createState() => _SodamSessionState();
}

class _SodamSessionState extends State<_SodamSession> {
  late final ProviderContainer container;

  @override
  void initState() {
    super.initState();
    container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(
          () => _SessionAuth(widget.auth, widget.onLogout, widget.onExpire),
        ),
      ],
    );
  }

  @override
  void dispose() {
    container.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => UncontrolledProviderScope(
    container: container,
    child: HeroControllerScope.none(
      child: Navigator(
        onGenerateRoute: (_) =>
            MaterialPageRoute<void>(builder: (_) => const SodamShell()),
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
