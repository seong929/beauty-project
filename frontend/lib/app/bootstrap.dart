import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../firebase_options.dart';

Future<void> launchApp(Widget app) async {
  WidgetsFlutterBinding.ensureInitialized();
  // SDK 설정이 있는 플랫폼에서만 기본 앱을 초기화한다. 이미지 HTTP 조회는 동일한 버킷 설정을 공유한다.
  if ((kIsWeb || defaultTargetPlatform == TargetPlatform.android) &&
      Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  runApp(ProviderScope(child: app));
}

// 변경 내용(2026-10-30): 각 UI의 실행 진입점이 같은 Firebase 설정과 단일 초기화 절차를 사용한다.
