import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../view/customer/login/customer_auth_widgets.dart';
import '../view/customer/login/customer_login_screen.dart';

class CustomerApp extends StatelessWidget {
  const CustomerApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '하나',
    debugShowCheckedModeBanner: false,
    theme: SodamStyle.theme,
    // 기능: 고객 앱을 처음 열 때만 두 단계의 시작 화면을 거쳐 로그인으로 진입한다.
    home: TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 2800),
      builder: (context, progress, _) => progress >= 1
          ? const CustomerLoginScreen()
          : _buildLaunchScreen(context, progress),
    ),
  );

  /// Function: 흰색·청록 그라데이션에서 청록 배경과 브랜드 문구로 전환한다.
  /// 애니메이션 수명은 위젯이 관리하므로 화면 종료 후 실행되는 타이머가 없다.
  Widget _buildLaunchScreen(BuildContext context, double progress) {
    const turquoise = Color(0xFF47D6D3);
    final fill = (progress / 0.45).clamp(0.0, 1.0);
    final textOpacity = ((progress - 0.4) / 0.2).clamp(0.0, 1.0);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: turquoise,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        key: const Key('customer-launch-screen'),
        body: DecoratedBox(
          key: const Key('customer-launch-background'),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.lerp(Colors.white, turquoise, fill)!,
                Color.lerp(Colors.white, turquoise, 0.15 + fill * 0.85)!,
                turquoise,
              ],
              stops: const [0, 0.45, 1],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: Opacity(
                opacity: textOpacity,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Text(
                    '새로운 하나의\n발견',
                    key: const Key('customer-launch-message'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: MediaQuery.sizeOf(context).width < 360
                          ? 36
                          : 42,
                      fontWeight: FontWeight.w800,
                      height: 1.45,
                      letterSpacing: -1,
                      color: Colors.white,
                    ),
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

// 변경 내용(2026-10-30): 고객 로그인·가입·홈만 사용하는 고객 전용 앱 진입 화면이다.
