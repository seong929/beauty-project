import 'dart:io';
import 'dart:ui' as ui;

import 'package:beauty_project/design/sodam_shell.dart';
import 'package:beauty_project/design/sodam_theme.dart';
import 'package:beauty_project/main_sodam.dart';
import 'package:beauty_project/model/auth/employee_login.dart';
import 'package:beauty_project/service/auth/auth_service.dart';
import 'package:beauty_project/view/auth/login_page.dart';
import 'package:beauty_project/view/staff/staff_inventory_view.dart';
import 'package:beauty_project/vm/admin/approval_notifier.dart';
import 'package:beauty_project/vm/admin/approval_state.dart';
import 'package:beauty_project/vm/admin/purchase_order_notifier.dart';
import 'package:beauty_project/vm/admin/purchase_order_state.dart';
import 'package:beauty_project/vm/auth/auth_notifier.dart';
import 'package:beauty_project/vm/auth/auth_state.dart';
import 'package:beauty_project/vm/staff/staff_inventory_vm.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

EmployeeLogin employee(String role) => EmployeeLogin(
  accessToken: 'test-token',
  tokenType: 'bearer',
  expiresIn: 3600,
  employeeId: 'sodam_${role.toLowerCase()}',
  employeeRole: role,
);

class _Auth extends AuthNotifier {
  _Auth(this.role);
  final String role;
  @override
  AuthState build() => AuthState(employee: employee(role));
}

class _Approvals extends ApprovalNotifier {
  @override
  ApprovalState build() => const ApprovalState();
  @override
  Future<void> getApprovalList() async {}
}

class _Purchases extends PurchaseOrderNotifier {
  @override
  PurchaseOrderState build() => const PurchaseOrderState();
  @override
  Future<void> getPurchaseOrderList() async {}
}

class _Login extends AuthService {
  const _Login() : super(baseUrl: 'http://localhost');
  @override
  Future<EmployeeLogin> login({
    required String loginId,
    required String password,
  }) async => employee('STAFF');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    if (Platform.isWindows &&
        await File('C:/Windows/Fonts/malgun.ttf').exists()) {
      final loader = FontLoader('SodamPreview');
      loader.addFont(
        File(
          'C:/Windows/Fonts/malgun.ttf',
        ).readAsBytes().then((b) => ByteData.sublistView(b)),
      );
      await loader.load();
      final icons = FontLoader('MaterialIcons');
      icons.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
    }
  });
  for (final role in ['ADMIN', 'STAFF']) {
    for (final mobile in [false, true]) {
      testWidgets('$role ${mobile ? 'mobile' : 'desktop'} layout and access', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = mobile
            ? const Size(390, 844)
            : const Size(1440, 1160);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        final boundary = GlobalKey();
        final container = ProviderContainer(
          overrides: [
            authProvider.overrideWith(() => _Auth(role)),
            approvalProvider.overrideWith(_Approvals.new),
            purchaseOrderProvider.overrideWith(_Purchases.new),
            distinctCosmeticsPageProvider.overrideWith((ref, args) async => []),
          ],
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: RepaintBoundary(
              key: boundary,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: sodamTheme().copyWith(
                  textTheme: sodamTheme().textTheme.apply(
                    fontFamily: 'SodamPreview',
                  ),
                ),
                home: const SodamShell(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('오늘의 소담'), findsOneWidget);
        // Export the actual rendered Flutter widgets, with mocked counts of zero.
        await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File(
            '../output/sodam-design/${role.toLowerCase()}-${mobile ? 'mobile' : 'desktop'}.png',
          );
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
        if (mobile) {
          await tester.tap(find.byTooltip('메뉴 열기'));
          await tester.pumpAndSettle();
        }
        expect(
          find.text('관리자 업무'),
          role == 'ADMIN' ? findsOneWidget : findsNothing,
        );
        expect(
          find.text('품의 관리'),
          role == 'ADMIN' ? findsOneWidget : findsNothing,
        );
        await tester.tap(find.widgetWithText(ListTile, '화장품·재고 관리'));
        await tester.pumpAndSettle();
        expect(find.byType(StaffInventoryView), findsOneWidget);
        expect(
          find.byTooltip('상품 등록'),
          role == 'ADMIN' ? findsOneWidget : findsNothing,
        );
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('new entry logs in and disposes the work session on logout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authServiceProvider.overrideWithValue(const _Login())],
        child: const SodamApp(),
      ),
    );
    await tester.enterText(find.byType(TextField).at(0), 'staff');
    await tester.enterText(find.byType(TextField).at(1), 'password');
    await tester.tap(find.widgetWithText(ElevatedButton, '로그인'));
    await tester.pumpAndSettle();
    expect(find.byType(SodamShell), findsOneWidget);
    final shellContext = tester.element(find.byType(SodamShell));
    final sessionContainer = ProviderScope.containerOf(shellContext);
    ProviderContainer? detailContainer;
    Navigator.of(shellContext).push(
      MaterialPageRoute<void>(
        builder: (context) {
          detailContainer = ProviderScope.containerOf(context);
          return const Scaffold(body: Text('Session detail'));
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(identical(detailContainer, sessionContainer), isTrue);
    Navigator.of(tester.element(find.text('Session detail'))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('로그아웃'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.byType(SodamShell), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
