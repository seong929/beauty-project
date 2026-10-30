import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:beauty_project/app/operations_app.dart';
import 'package:beauty_project/model/auth/employee_login.dart';
import 'package:beauty_project/model/auth/carrier_login.dart';
import 'package:beauty_project/model/delivery/delivery.dart' as carrier;
import 'package:beauty_project/model/delivery/return_pickup.dart';
import 'package:beauty_project/service/delivery/delivery_service.dart';
import 'package:beauty_project/view/admin/operations/workspace.dart';
import 'package:beauty_project/view/admin/operations/returns_page.dart';
import 'package:beauty_project/view/admin/operations/approval_page.dart';
import 'package:beauty_project/view/admin/operations/product_create_page.dart';
import 'package:beauty_project/view/delivery/delivery_page.dart';
import 'package:beauty_project/view/delivery/return_pickup_page.dart';
import 'package:beauty_project/view/operations/operations_theme.dart';
import 'package:beauty_project/vm/auth/api_client_provider.dart';
import 'package:beauty_project/vm/auth/auth_notifier.dart';
import 'package:beauty_project/vm/auth/auth_state.dart';
import 'package:beauty_project/vm/auth/carrier_auth_notifier.dart';
import 'package:beauty_project/vm/auth/carrier_auth_state.dart';
import 'package:beauty_project/vm/delivery/delivery_notifier.dart';
import 'package:beauty_project/vm/operations/workspace_notifier.dart';
import 'package:beauty_project/vm/operations/return_filters_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _Admin extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
    employee: EmployeeLogin(
      accessToken: 'test',
      tokenType: 'bearer',
      expiresIn: 3600,
      employeeId: 'E_admin',
      employeeRole: 'ADMIN',
    ),
  );
}

class _Staff extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
    employee: EmployeeLogin(
      accessToken: 'test',
      tokenType: 'bearer',
      expiresIn: 3600,
      employeeId: 'E_staff',
      employeeRole: 'STAFF',
    ),
  );
}

class _Carrier extends CarrierAuthNotifier {
  @override
  CarrierAuthState build() => const CarrierAuthState(
    carrier: CarrierLogin(
      accessToken: 'test',
      tokenType: 'bearer',
      expiresIn: 3600,
      accountId: 'ca_test',
      carrierId: 'car_test',
    ),
  );
}

class _Api {
  final paths = <String>[];
  final patches = <Map<String, dynamic>>[];
  String refund = 'PROCESSING';
  bool failReturns = false;
  late final client = MockClient((request) async {
    paths.add(request.url.path);
    final path = request.url.path;
    Object result = [];
    if (request.method == 'PATCH') {
      patches.add(jsonDecode(request.body) as Map<String, dynamic>);
      if (path.endsWith('/refund-status')) {
        refund = patches.last['refund_status'] as String;
      }
      result = {
        'message': '내부 업무 상태를 저장했습니다. 실제 금액 반환은 수행되지 않았습니다.',
        'external_refund_performed': false,
      };
    } else if (path == '/admin/approvals') {
      result = [
        {
          'approval_id': 'apr_1',
          'cosmetic_id': 'cos_1',
          'cosmetic_name': '수분 진정 세럼',
          'approval_seq': 1,
          'target_stock_snapshot': 100,
          'current_stock_snapshot': 20,
          'requested_quantity': 80,
          'approval_content': '재고 보충',
          'requested_on': '2026-10-30',
          'approval_status': 'REQUESTED',
          'decision_status': 'PENDING',
          'manufacturer_id': 'mfr_1',
          'manufacturer_name': '소담 제조',
          'volume_text': '50ml',
        },
      ];
    } else if (path == '/admin/purchase-orders') {
      result = [
        {
          'purchase_order_id': 'po_1',
          'approval_id': 'apr_1',
          'purchase_order_seq': 1,
          'manufacturer_id': 'mfr_1',
          'manufacturer_name': '소담 제조',
          'cosmetic_id': 'cos_1',
          'cosmetic_name': '수분 진정 세럼',
          'ordered_on': '2026-10-30',
          'order_quantity': 80,
          'purchase_status': 'ORDERED',
          'unit_supply_price': 12000,
          'order_total_amount': 960000,
          'volume_text': '50ml',
        },
      ];
    } else if (path == '/admin/returns') {
      if (failReturns) return http.Response('{"detail":"조회 실패"}', 503);
      result = [
        {
          'return_id': 'ret_preview_1',
          'order_id': 'ord_preview',
          'order_item_id': 'item_1',
          'customer_id': 'customer_preview',
          'requested_on': '2026-10-25',
          'approved_on': '2026-10-26',
          'pickup_completed_on': '2026-10-27',
          'headquarters_received_on': '2026-10-28',
          'inspection_completed_on': '2026-10-29',
          'return_reason': '용기 파손',
          'inspection_result': '검수 완료',
          'return_quantity': 1,
          'return_status': 'COMPLETED',
          'pickup_status': 'COLLECTED',
          'refund_status': refund,
        },
      ];
    } else if (path == '/staff/order/available') {
      result = {'orders': []};
    } else if (path == '/admin/manufacturers') {
      result = [
        {
          'manufacturer_id': 'mfr_1',
          'manufacturer_name': '소담 제조',
          'manufacturer_phone': '0212345678',
        },
      ];
    } else if (path == '/admin/categories') {
      result = [
        {'category_id': 'cat_1', 'category_name': '스킨케어'},
      ];
    }
    return http.Response.bytes(
      utf8.encode(jsonEncode(result)),
      200,
      headers: {'content-type': 'application/json'},
    );
  });
}

class _CarrierApi extends DeliveryService {
  _CarrierApi() : super(baseUrl: 'http://test');
  String status = 'READY';
  String pickupStatus = 'SCHEDULED';
  int writes = 0;
  @override
  Future<List<carrier.Delivery>> fetchDeliveryList({
    required String accessToken,
  }) async => [
    carrier.Delivery(
      deliveryId: 'dlv_preview_1',
      orderId: 'ord_preview',
      deliverySeq: 1,
      carrierName: '소담 배송',
      shippingAddress: '서울시 마포구 월드컵북로 21',
      orderedAt: DateTime(2026, 10, 25),
      deliveryStatus: status,
      shippedAt: status == 'READY' ? null : DateTime(2026, 10, 26),
      arrivedAt: status == 'DELIVERED' ? DateTime(2026, 10, 27) : null,
    ),
  ];
  @override
  Future<carrier.DeliveryStatusResult> updateDeliveryStatus({
    required String accessToken,
    required String deliveryId,
    required String deliveryStatus,
  }) async {
    final previous = status;
    status = deliveryStatus;
    writes++;
    return carrier.DeliveryStatusResult(
      deliveryId: deliveryId,
      previousStatus: previous,
      deliveryStatus: status,
      message: '배송 상태가 저장되었습니다.',
    );
  }

  @override
  Future<List<ReturnPickup>> fetchReturnPickups({
    required String accessToken,
  }) async => [
    ReturnPickup(
      returnId: 'ret_pickup_1',
      orderId: 'ord_preview',
      orderItemId: 'item_1',
      shippingAddress: '서울시 마포구 월드컵북로 21',
      returnReason: '용기 파손',
      returnStatus: 'COLLECTING',
      pickupStatus: pickupStatus,
      returnQuantity: 1,
      requestedOn: DateTime(2026, 10, 25),
      pickupRequestedOn: DateTime(2026, 10, 26),
      pickupCompletedOn: pickupStatus == 'COLLECTED'
          ? DateTime(2026, 10, 27)
          : null,
    ),
  ];
  @override
  Future<void> completeReturnPickup({
    required String accessToken,
    required String returnId,
  }) async {
    writes++;
    pickupStatus = 'COLLECTED';
  }
}

void main() {
  setUpAll(() async {
    await (FontLoader(
      'NotoSansKR',
    )..addFont(rootBundle.load('assets/fonts/NotoSansKR.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  final captureKey = GlobalKey();
  Future<void> capture(WidgetTester tester, String name) async {
    final directory = Platform.environment['OPERATIONS_PREVIEW_DIR'];
    if (directory == null) return;
    await tester.runAsync(() async {
      final boundary =
          captureKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory(directory).create(recursive: true);
      await File(
        '$directory/$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  Future<ProviderContainer> pumpAdmin(
    WidgetTester tester,
    Widget home,
    _Api api,
    Size size,
  ) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_Admin.new),
          apiClientProvider.overrideWithValue(api.client),
        ],
        child: RepaintBoundary(
          key: captureKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: operationsTheme(),
            home: home,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(
      tester.element(find.byType(home.runtimeType)),
    );
  }

  Future<void> pumpCarrier(
    WidgetTester tester,
    Widget home,
    _CarrierApi api,
    Size size,
  ) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          carrierAuthProvider.overrideWith(_Carrier.new),
          deliveryServiceProvider.overrideWithValue(api),
        ],
        child: RepaintBoundary(
          key: captureKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: operationsTheme(),
            home: home,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  test('workspace and independent return filter states are immutable', () {
    const original = OperationsWorkspaceState();
    expect(
      original.copyWith(section: OperationsSection.returns).section,
      OperationsSection.returns,
    );
    expect(original.section, OperationsSection.overview);
    const filters = OperationsReturnFilters(
      pickup: 'COLLECTED',
      refund: 'PROCESSING',
      query: 'RET_1',
    );
    expect(
      filters.matches({
        'return_id': 'ret_1',
        'pickup_status': 'COLLECTED',
        'refund_status': 'PROCESSING',
      }),
      true,
    );
    expect(
      filters.matches({
        'return_id': 'ret_1',
        'pickup_status': 'COLLECTED',
        'refund_status': 'COMPLETED',
      }),
      false,
    );
    expect(filters.copyWith(query: 'other').query, 'other');
    expect(filters.query, 'RET_1');
  });
  for (final width in [320.0, 768.0, 1280.0]) {
    testWidgets('admin menus render without overflow at $width', (
      tester,
    ) async {
      final api = _Api();
      final container = await pumpAdmin(
        tester,
        const OperationsWorkspace(),
        api,
        Size(width, 900),
      );
      await capture(tester, 'dashboard_${width.toInt()}');
      for (final section in OperationsSection.values) {
        container.read(operationsWorkspaceProvider.notifier).select(section);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: section.name);
      }
      expect(api.paths.where((path) => path.startsWith('/customer')), isEmpty);
    });
    testWidgets(
      'delivery start and completion preserve the real status sequence at $width',
      (tester) async {
        final api = _CarrierApi();
        await pumpCarrier(tester, const DeliveryPage(), api, Size(width, 900));
        await tester.tap(find.text('dlv_preview_1'));
        await tester.pumpAndSettle();
        await capture(tester, 'delivery_${width.toInt()}');
        await tester.ensureVisible(
          find.widgetWithText(ElevatedButton, '배송 시작'),
        );
        await tester.tap(find.widgetWithText(ElevatedButton, '배송 시작'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('확인'));
        await tester.pumpAndSettle();
        expect(api.status, 'IN_TRANSIT');
        await tester.ensureVisible(
          find.widgetWithText(ElevatedButton, '배송 완료'),
        );
        await tester.tap(find.widgetWithText(ElevatedButton, '배송 완료'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('확인'));
        await tester.pumpAndSettle();
        expect(api.status, 'DELIVERED');
        expect(api.writes, 2);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('mobile approval opens a full detail and returns to the list', (
    tester,
  ) async {
    await pumpAdmin(
      tester,
      const OperationsApprovalPage(embedded: true),
      _Api(),
      const Size(390, 844),
    );
    await tester.tap(find.text('수분 진정 세럼').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('50ml').first);
    await tester.pumpAndSettle();
    expect(find.text('목록으로'), findsOneWidget);
    expect(find.text('승인 및 발주'), findsOneWidget);
    await tester.tap(find.text('목록으로'));
    await tester.pumpAndSettle();
    expect(find.text('목록으로'), findsNothing);
  });
  testWidgets('PR34 completion remains a confirmed terminal internal record', (
    tester,
  ) async {
    final api = _Api();
    await pumpAdmin(
      tester,
      const OperationsReturnsPage(),
      api,
      const Size(1280, 1000),
    );
    await tester.tap(find.text('ret_preview_1'));
    await tester.pumpAndSettle();
    await capture(tester, 'admin_returns');
    await tester.ensureVisible(find.text('환불 완료 기록'));
    await tester.tap(find.text('환불 완료 기록'));
    await tester.pumpAndSettle();
    expect(find.textContaining('실제 금액 반환은 수행되지 않습니다.'), findsOneWidget);
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    expect(api.patches.single, {
      'employee_id': 'E_admin',
      'expected_refund_status': 'PROCESSING',
      'refund_status': 'COMPLETED',
    });
    expect(api.refund, 'COMPLETED');
    expect(find.text('환불 완료 기록'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'return search hides only local results and errors can be retried',
    (tester) async {
      final api = _Api();
      await pumpAdmin(
        tester,
        const OperationsReturnsPage(),
        api,
        const Size(390, 844),
      );
      final before = api.paths.length;
      await tester.enterText(find.byType(TextField).first, 'missing');
      await tester.pumpAndSettle();
      expect(find.text('조건에 맞는 반품이 없습니다.'), findsOneWidget);
      expect(api.paths.length, before);
      await tester.enterText(find.byType(TextField).first, '');
      api.failReturns = true;
      await tester.tap(find.byTooltip('새로고침'));
      await tester.pumpAndSettle();
      expect(find.textContaining('반품 조회 실패'), findsOneWidget);
      api.failReturns = false;
      await tester.tap(find.byTooltip('새로고침'));
      await tester.pumpAndSettle();
      expect(find.text('ret_preview_1'), findsOneWidget);
    },
  );
  testWidgets('pickup search and confirmed collection refresh the list', (
    tester,
  ) async {
    final api = _CarrierApi();
    await pumpCarrier(
      tester,
      const ReturnPickupPage(),
      api,
      const Size(390, 844),
    );
    await tester.enterText(find.byType(TextField).first, 'missing');
    await tester.pumpAndSettle();
    expect(find.text('ret_pickup_1'), findsNothing);
    await tester.enterText(find.byType(TextField).first, '');
    await tester.pumpAndSettle();
    await tester.tap(find.text('ret_pickup_1'));
    await tester.pumpAndSettle();
    await capture(tester, 'pickup_mobile');
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(FilledButton, '수거 완료'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '수거 완료'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    expect(api.pickupStatus, 'COLLECTED');
    expect(api.writes, 1);
    expect(find.widgetWithText(FilledButton, '수거 완료'), findsNothing);
  });
  testWidgets(
    'product registration keeps section hierarchy and existing validation',
    (tester) async {
      final api = _Api();
      await pumpAdmin(
        tester,
        const OperationsProductCreatePage(),
        api,
        const Size(390, 844),
      );
      expect(find.text('상품 이미지'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('가격 및 재고 기준'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('가격 및 재고 기준'), findsOneWidget);
      expect(api.patches, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('dedicated entry blocks staff and logs out to admin login', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authProvider.overrideWith(_Staff.new)],
        child: const OperationsApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('관리자 전용 업무 공간'), findsOneWidget);
    await tester.tap(find.text('다른 계정으로 로그인'));
    await tester.pumpAndSettle();
    expect(find.text('관리자 로그인'), findsOneWidget);
  });
}
