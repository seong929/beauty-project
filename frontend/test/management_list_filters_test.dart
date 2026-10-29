import 'package:beauty_project/model/admin/approval.dart';
import 'package:beauty_project/model/admin/purchase_order.dart';
import 'package:beauty_project/view/admin/approval_page.dart';
import 'package:beauty_project/view/admin/purchase_order_page.dart';
import 'package:beauty_project/view/admin/management_list_controls.dart';
import 'package:beauty_project/vm/admin/approval_notifier.dart';
import 'package:beauty_project/vm/admin/approval_state.dart';
import 'package:beauty_project/vm/admin/purchase_order_notifier.dart';
import 'package:beauty_project/vm/admin/purchase_order_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Approval _approval(String id, String status, {String? decision}) => Approval(
  approvalId: id,
  cosmeticId: 'c$id',
  cosmeticName: '크림',
  approvalSeq: 1,
  targetStockSnapshot: 100,
  currentStockSnapshot: 10,
  requestedQuantity: 90,
  approvalContent: '재고 부족',
  requestedOn: DateTime(2026),
  approvalStatus: status,
  decisionStatus: decision,
  manufacturerId: 'm1',
  categoryId: 'cat1',
  cosmeticNameSeq: 1,
  volumeText: '$id ml',
);

class _Approvals extends ApprovalNotifier {
  @override
  ApprovalState build() => ApprovalState(
    approvals: [
      _approval('a1', 'REQUESTED', decision: 'PENDING'),
      _approval('a2', 'APPROVED', decision: 'APPROVED'),
      _approval('a3', 'CANCELLED', decision: 'APPROVED'),
    ],
  );
  @override
  Future<void> getApprovalList() async {}
}

PurchaseOrder _order(String id, String status) => PurchaseOrder(
  purchaseOrderId: id,
  approvalId: 'a$id',
  purchaseOrderSeq: 1,
  manufacturerId: 'm1',
  manufacturerName: '제조사',
  cosmeticId: 'c$id',
  cosmeticName: '크림',
  orderedOn: DateTime(2026),
  orderQuantity: 10,
  purchaseStatus: status,
  unitSupplyPrice: 1000,
  orderTotalAmount: 10000,
  categoryId: 'cat1',
  cosmeticNameSeq: 1,
  volumeText: '$id ml',
);

class _Orders extends PurchaseOrderNotifier {
  @override
  PurchaseOrderState build() => PurchaseOrderState(
    purchaseOrders: [
      _order('o1', 'ORDERED'),
      _order('o2', 'PARTIALLY_RECEIVED'),
    ],
  );
  @override
  Future<void> getPurchaseOrderList() async {}
}

Future<void> _choose(WidgetTester tester, Finder dropdown, String label) async {
  await tester.tap(dropdown);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('품의 개별 표시와 상태 필터는 목록과 상세 모두에 적용된다', (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [approvalProvider.overrideWith(_Approvals.new)],
        child: const MaterialApp(home: ApprovalPage(embedded: true)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ExpansionTile), findsOneWidget);
    await _choose(
      tester,
      find.byType(DropdownButtonFormField<ManagementListMode>),
      '개별 목록',
    );
    expect(find.byType(ExpansionTile), findsNothing);
    for (final id in ['a1', 'a2', 'a3']) {
      expect(find.byKey(ValueKey(id)), findsOneWidget);
    }
    await tester.tap(find.byKey(const ValueKey('a2')));
    await tester.pumpAndSettle();
    expect(find.text('품의 상세 정보'), findsOneWidget);
    await _choose(
      tester,
      find.byType(DropdownButtonFormField<String>),
      '승인 대기',
    );
    expect(find.byKey(const ValueKey('a1')), findsOneWidget);
    expect(find.byKey(const ValueKey('a2')), findsNothing);
    expect(find.text('품의 상세 정보'), findsNothing);
    await _choose(tester, find.byType(DropdownButtonFormField<String>), '취소');
    expect(find.byKey(const ValueKey('a3')), findsOneWidget);
    expect(find.byKey(const ValueKey('a2')), findsNothing);
    await _choose(
      tester,
      find.byType(DropdownButtonFormField<ManagementListMode>),
      '상품별 묶음',
    );
    expect(find.byType(ExpansionTile), findsOneWidget);
    await tester.tap(find.text('크림'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('a3')), findsOneWidget);
    expect(find.byKey(const ValueKey('a1')), findsNothing);
  });

  testWidgets('발주 개별 표시와 부분 입고 필터를 함께 적용한다', (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [purchaseOrderProvider.overrideWith(_Orders.new)],
        child: const MaterialApp(home: PurchaseOrderPage()),
      ),
    );
    await tester.pumpAndSettle();
    await _choose(
      tester,
      find.byType(DropdownButtonFormField<ManagementListMode>),
      '개별 목록',
    );
    expect(find.byKey(const ValueKey('o1')), findsOneWidget);
    expect(find.byKey(const ValueKey('o2')), findsOneWidget);
    await _choose(
      tester,
      find.byType(DropdownButtonFormField<String>),
      '부분 입고',
    );
    expect(find.byKey(const ValueKey('o1')), findsNothing);
    expect(find.byKey(const ValueKey('o2')), findsOneWidget);
    await _choose(
      tester,
      find.byType(DropdownButtonFormField<String>),
      '입고 완료',
    );
    expect(find.text('선택한 상태의 발주가 없습니다.'), findsOneWidget);
  });
}
