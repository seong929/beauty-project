import 'dart:async';
import 'dart:convert';

import 'package:beauty_project/model/auth/employee_login.dart';
import 'package:beauty_project/service/admin/management_service.dart';
import 'package:beauty_project/view/admin/return_management_page.dart';
import 'package:beauty_project/vm/admin/management_vm.dart';
import 'package:beauty_project/vm/admin/return_management_state.dart';
import 'package:beauty_project/vm/auth/auth_notifier.dart';
import 'package:beauty_project/vm/auth/auth_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _Admin extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
    employee: EmployeeLogin(
      accessToken: 'admin-token',
      tokenType: 'bearer',
      expiresIn: 3600,
      employeeId: 'emp_admin',
      employeeRole: 'ADMIN',
    ),
  );
}

class _Staff extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
    employee: EmployeeLogin(
      accessToken: 'staff-token',
      tokenType: 'bearer',
      expiresIn: 3600,
      employeeId: 'emp_staff',
      employeeRole: 'STAFF',
    ),
  );
}

class _Server {
  String status = 'COMPLETED';
  String pickup = 'COLLECTED';
  String refund = 'PENDING';
  String? received = '2026-10-30';
  String? inspection = 'Inspected';
  int writes = 0;
  int reads = 0;
  bool reject = false;
  bool failReload = false;
  Completer<void>? hold;
  Map<String, dynamic>? lastBody;

  Map<String, dynamic> get row => {
    'return_id': 'ret_1',
    'order_id': 'ord_1',
    'order_item_id': 'oi_1',
    'customer_id': 'cus_1',
    'return_status': status,
    'pickup_status': pickup,
    'return_quantity': 1,
    'return_reason': 'Damaged',
    'requested_on': '2026-10-29',
    'refund_status': refund,
    'headquarters_received_on': received,
    'inspection_result': inspection,
  };

  http.Response json(Object body, [int code = 200]) => http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    code,
    headers: {'content-type': 'application/json'},
  );

  late final service = ManagementService(
    MockClient((request) async {
      if (request.method == 'GET') {
        reads++;
        if (failReload && writes > 0) {
          return json({'detail': 'reload failed'}, 503);
        }
        return json([row]);
      }
      expect(request.method, 'PATCH');
      expect(request.url.path, '/admin/returns/ret_1/refund-status');
      writes++;
      lastBody = jsonDecode(request.body) as Map<String, dynamic>;
      expect(lastBody!['employee_id'], 'emp_admin');
      if (hold != null) await hold!.future;
      if (reject) return json({'detail': 'status conflict'}, 409);
      expect(lastBody!['expected_refund_status'], refund);
      refund = lastBody!['refund_status'] as String;
      return json({
        'refund_status': refund,
        'external_refund_performed': false,
        'message': 'Internal status saved; no payment cancellation performed.',
      });
    }),
  );
}

void main() {
  test(
    'immutable state copy retains filter and clears processing/messages',
    () {
      const initial = ReturnManagementState(selectedStatus: 'COMPLETED');
      final processing = initial.copyWith(
        processingReturnId: 'ret_1',
        errorMessage: 'error',
      );
      expect(initial.isProcessing, false);
      expect(processing.isProcessing, true);
      final cleared = processing.copyWith(
        clearProcessing: true,
        clearMessages: true,
      );
      expect(cleared.selectedStatus, 'COMPLETED');
      expect(cleared.errorMessage, isNull);
      expect(cleared.isProcessing, false);
    },
  );

  test(
    'notifier sends expected state, blocks duplicate clicks and reloads',
    () async {
      final server = _Server()..hold = Completer<void>();
      final container = ProviderContainer(
        overrides: [
          managementServiceProvider.overrideWithValue(server.service),
          authProvider.overrideWith(_Admin.new),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        returnManagementProvider,
        (_, next) {},
      );
      addTearDown(subscription.close);
      final listSubscription = container.listen(
        returnListProvider,
        (_, next) {},
      );
      addTearDown(listSubscription.close);
      await container.read(returnListProvider.future);
      final notifier = container.read(returnManagementProvider.notifier);
      notifier.changeStatus('COMPLETED');
      final first = notifier.updateRefundStatus(
        returnId: 'ret_1',
        expectedStatus: 'PENDING',
        refundStatus: 'PROCESSING',
      );
      await Future<void>.delayed(Duration.zero);
      expect(container.read(returnManagementProvider).isProcessing, true);
      await notifier.updateRefundStatus(
        returnId: 'ret_1',
        expectedStatus: 'PENDING',
        refundStatus: 'PROCESSING',
      );
      expect(server.writes, 1);
      server.hold!.complete();
      await first;
      expect(server.lastBody, {
        'employee_id': 'emp_admin',
        'expected_refund_status': 'PENDING',
        'refund_status': 'PROCESSING',
      });
      expect(server.reads, 2);
      expect(
        container.read(returnListProvider).requireValue.single['refund_status'],
        'PROCESSING',
      );
      expect(
        container.read(returnManagementProvider).selectedStatus,
        'COMPLETED',
      );
      expect(container.read(returnManagementProvider).isProcessing, false);
      expect(container.read(returnManagementProvider).errorMessage, isNull);
    },
  );

  for (final failReload in [false, true]) {
    test(
      'notifier reports ${failReload ? 'saved but reload failed' : 'API conflict'} without retrying',
      () async {
        final server = _Server()
          ..reject = !failReload
          ..failReload = failReload;
        final container = ProviderContainer(
          overrides: [
            managementServiceProvider.overrideWithValue(server.service),
            authProvider.overrideWith(_Admin.new),
          ],
        );
        addTearDown(container.dispose);
        final subscription = container.listen(
          returnManagementProvider,
          (_, next) {},
        );
        addTearDown(subscription.close);
        final listSubscription = container.listen(
          returnListProvider,
          (_, next) {},
        );
        addTearDown(listSubscription.close);
        await container.read(returnListProvider.future);
        await container
            .read(returnManagementProvider.notifier)
            .updateRefundStatus(
              returnId: 'ret_1',
              expectedStatus: 'PENDING',
              refundStatus: 'PROCESSING',
            );
        final state = container.read(returnManagementProvider);
        expect(state.isProcessing, false);
        expect(state.successMessage, isNull);
        expect(
          state.errorMessage,
          contains(failReload ? '저장되었으나' : 'status conflict'),
        );
        expect(server.writes, 1);
      },
    );
  }

  test('staff cannot invoke refund mutation through notifier', () async {
    final server = _Server();
    final container = ProviderContainer(
      overrides: [
        managementServiceProvider.overrideWithValue(server.service),
        authProvider.overrideWith(_Staff.new),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      returnManagementProvider,
      (_, next) {},
    );
    addTearDown(subscription.close);
    await container
        .read(returnManagementProvider.notifier)
        .updateRefundStatus(
          returnId: 'ret_1',
          expectedStatus: 'PENDING',
          refundStatus: 'PROCESSING',
        );
    expect(server.writes, 0);
    expect(
      container.read(returnManagementProvider).errorMessage,
      contains('관리자'),
    );
  });

  Future<void> pumpPage(
    WidgetTester tester,
    _Server server, {
    bool staff = false,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          managementServiceProvider.overrideWithValue(server.service),
          authProvider.overrideWith(staff ? _Staff.new : _Admin.new),
        ],
        child: const MaterialApp(home: ReturnManagementPage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('반품 ret_1 · ${server.status}'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'inspection-complete refund confirms internal-only operation and refreshes',
    (tester) async {
      final server = _Server();
      await pumpPage(tester, server);
      expect(find.text('내부 환불 처리 접수'), findsOneWidget);
      expect(find.text('환불 완료'), findsNothing);
      await tester.ensureVisible(find.text('내부 환불 처리 접수'));
      await tester.tap(find.text('내부 환불 처리 접수'));
      await tester.pumpAndSettle();
      expect(
        find.text('내부 환불 업무 상태만 변경합니다. 외부 결제 취소·실제 금액 반환은 수행되지 않습니다.'),
        findsOneWidget,
      );
      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();
      expect(server.writes, 1);
      expect(server.refund, 'PROCESSING');
      // A reload may recreate the expanded detail; reopen if necessary.
      if (find.text('내부 환불 처리 실패 기록').evaluate().isEmpty) {
        await tester.tap(find.text('반품 ret_1 · COMPLETED'));
        await tester.pumpAndSettle();
      }
      expect(find.textContaining('환불 처리 중 (내부 접수)'), findsOneWidget);
      expect(find.text('내부 환불 처리 실패 기록'), findsOneWidget);
      expect(find.text('내부 환불 처리 접수'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('pending inspection does not offer refund actions', (
    tester,
  ) async {
    final server = _Server()..status = 'INSPECTING';
    await pumpPage(tester, server);
    expect(find.text('내부 환불 처리 접수'), findsNothing);
    expect(find.text('검수 완료'), findsOneWidget);
  });

  testWidgets('staff cannot see refund actions', (tester) async {
    await pumpPage(tester, _Server(), staff: true);
    expect(find.text('내부 환불 처리 접수'), findsNothing);
  });

  testWidgets('failed internal task offers retry; completed offers no action', (
    tester,
  ) async {
    final server = _Server()..refund = 'FAILED';
    await pumpPage(tester, server);
    expect(find.text('내부 환불 재접수'), findsOneWidget);
    expect(find.text('내부 환불 처리 접수'), findsNothing);
    server.refund = 'COMPLETED';
    await tester.tap(find.byTooltip('새로고침'));
    await tester.pumpAndSettle();
    if (find.textContaining('환불: 환불 완료').evaluate().isEmpty) {
      await tester.tap(find.text('반품 ret_1 · COMPLETED'));
      await tester.pumpAndSettle();
    }
    expect(find.textContaining('환불: 환불 완료'), findsOneWidget);
    expect(find.text('내부 환불 재접수'), findsNothing);
    expect(find.text('내부 환불 처리 실패 기록'), findsNothing);
  });

  testWidgets('loading disables refund action and error is displayed', (
    tester,
  ) async {
    final server = _Server()
      ..hold = Completer<void>()
      ..reject = true;
    await pumpPage(tester, server);
    await tester.ensureVisible(find.text('내부 환불 처리 접수'));
    await tester.tap(find.text('내부 환불 처리 접수'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('확인'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '내부 환불 처리 접수'),
    );
    expect(button.onPressed, isNull);
    server.hold!.complete();
    await tester.pumpAndSettle();
    expect(find.textContaining('status conflict'), findsOneWidget);
    expect(server.writes, 1);
  });
}
