import 'package:beauty_project/model/admin/approval.dart';
import 'package:beauty_project/view/admin/approval_order_dialog.dart';
import 'package:beauty_project/view/admin/operations/approval_order_dialog.dart'
    as operations;
import 'package:beauty_project/vm/admin/manufacturer_vm.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final useOperations in [false, true]) {
    for (final scenario in [
      (cost: '500.25', overridePrice: null),
      (cost: '500.25', overridePrice: '120.50'),
      (cost: null, overridePrice: '120.50'),
    ]) {
      testWidgets(
        '승인 창 operations=$useOperations 원가=${scenario.cost} 변경=${scenario.overridePrice}',
        (tester) async {
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
            unitCost: scenario.cost,
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
                          builder: (_) => useOperations
                              ? operations.OperationsApprovalOrderDialog(
                                  approval: approval,
                                )
                              : ApprovalOrderDialog(approval: approval),
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
          final priceField = find.widgetWithText(TextFormField, '개당 공급 단가');
          expect(
            tester.widget<TextFormField>(priceField).controller!.text,
            scenario.cost ?? '',
          );
          if (scenario.cost == null) {
            expect(find.text('등록된 원가가 없습니다. 공급 단가를 입력해 주세요.'), findsOneWidget);
          }
          await tester.tap(find.text('발주처 선택'));
          await tester.pumpAndSettle();
          expect(find.text('다른 제조사'), findsNothing);
          await tester.tap(find.text('등록 제조사').last);
          await tester.pumpAndSettle();
          await tester.enterText(
            find.widgetWithText(TextFormField, '발주 수량'),
            '37',
          );
          if (scenario.overridePrice != null) {
            await tester.enterText(priceField, scenario.overridePrice!);
          }
          await tester.tap(find.text('승인 및 발주').last);
          await tester.pumpAndSettle();
          expect(result, (
            manufacturerId: 'm1',
            quantity: 37,
            price: scenario.overridePrice ?? scenario.cost!,
          ));
        },
      );
    }
  }

  test('품의 원가는 API의 문자열·숫자·누락 응답을 처리한다', () {
    final json = <String, dynamic>{
      'approval_id': 'a1',
      'cosmetic_id': 'c1',
      'cosmetic_name': '크림',
      'approval_seq': 1,
      'target_stock_snapshot': 100,
      'current_stock_snapshot': 20,
      'requested_quantity': 80,
      'approval_content': '부족',
      'requested_on': '2026-10-30',
    };
    expect(Approval.fromJson(json).unitCost, isNull);
    for (final cost in ['500.25', 500.25]) {
      expect(
        Approval.fromJson({...json, 'unit_cost': cost}).unitCost,
        '500.25',
      );
    }
  });
}
