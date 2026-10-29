import 'package:beauty_project/model/admin/approval.dart';
import 'package:beauty_project/view/admin/approval_order_dialog.dart';
import 'package:beauty_project/vm/admin/manufacturer_vm.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('상품의 등록 발주처를 선택하고 관리자가 수량과 단가를 정한다', (tester) async {
    final approval = Approval(
      approvalId: 'a1',
      cosmeticId: 'c1',
      cosmeticName: '크림',
      approvalSeq: 1,
      targetStockSnapshot: 100,
      currentStockSnapshot: 20,
      requestedQuantity: 80,
      approvalContent: '부족',
      requestedOn: DateTime(2026),
      manufacturerId: 'm1',
      volumeText: '50ml',
    );
    ApprovalOrderDetails? result;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          manufacturersProvider.overrideWith(
            (ref) async => [
              const Manufacturer('m1', '등록 제조사', null),
              const Manufacturer('m2', '다른 제조사', null),
            ],
          ),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showDialog<ApprovalOrderDetails>(
                    context: context,
                    builder: (_) => ApprovalOrderDialog(approval: approval),
                  );
                },
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('발주처 선택'));
    await tester.pumpAndSettle();
    expect(find.text('다른 제조사'), findsNothing);
    await tester.tap(find.text('등록 제조사').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, '발주 수량'), '37');
    await tester.enterText(
      find.widgetWithText(TextFormField, '개당 공급 단가'),
      '120.50',
    );
    await tester.tap(find.text('승인 및 발주').last);
    await tester.pumpAndSettle();
    expect(result, (manufacturerId: 'm1', quantity: 37, price: '120.50'));
  });
}
