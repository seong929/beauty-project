import 'package:flutter/material.dart';

// 하단 탭은 메인 바로 위의 한 화면으로 유지한다. 뒤로가기는 이전 탭 대신 메인으로 돌아간다.
Future<void> openCustomerTab(
  BuildContext context, {
  required String name,
  required Widget screen,
}) async {
  if (!context.mounted || ModalRoute.of(context)?.settings.name == name) return;
  await Navigator.of(context).pushAndRemoveUntil<void>(
    MaterialPageRoute(
      settings: RouteSettings(name: name),
      builder: (_) => screen,
    ),
    (route) => route.isFirst,
  );
}

void returnToCustomerHome(BuildContext context) {
  if (context.mounted) Navigator.of(context).popUntil((route) => route.isFirst);
}

// 변경 내용(2026-10-30): 하단 탭을 이동할 때 쌓여 있던 이전 탭·상세 화면을 정리한다.
