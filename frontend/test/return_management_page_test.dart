import 'package:beauty_project/view/admin/return_management_page.dart';
import 'package:beauty_project/vm/admin/management_vm.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('반품 상태에 맞는 업무만 제공한다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          returnListProvider.overrideWith(
            (ref) async => [
              {
                'return_id': 'R1',
                'order_id': 'O1',
                'order_item_id': 'I1',
                'customer_id': 'C1',
                'return_status': 'REQUESTED',
                'pickup_status': 'WAITING',
                'return_quantity': 1,
                'return_reason': '불량',
                'requested_on': '2026-01-01',
                'refund_status': 'WAITING',
              },
            ],
          ),
        ],
        child: const MaterialApp(home: ReturnManagementPage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('반품 R1 · REQUESTED'));
    await tester.pumpAndSettle();
    expect(find.text('승인'), findsOneWidget);
    expect(find.text('반려'), findsOneWidget);
    expect(find.text('회수 요청'), findsNothing);
    expect(find.text('검수 완료'), findsNothing);
  });
}
