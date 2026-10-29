import 'package:beauty_project/model/auth/employee_login.dart';
import 'package:beauty_project/service/auth/auth_service.dart';
import 'package:beauty_project/view/admin/cosmetic_create_page.dart';
import 'package:beauty_project/view/staff/cosmetic_option_detail_view.dart';
import 'package:beauty_project/view/admin/outbound_page.dart';
import 'package:beauty_project/view/admin/return_management_page.dart';
import 'package:beauty_project/view/admin/staff_purchase_order_page.dart';
import 'package:beauty_project/view/staff/staff_inventory_view.dart';
import 'package:beauty_project/vm/admin/management_vm.dart';
import 'package:beauty_project/vm/admin/manufacturer_vm.dart';
import 'package:beauty_project/vm/admin/outbound_notifier.dart';
import 'package:beauty_project/vm/admin/outbound_state.dart';
import 'package:beauty_project/vm/admin/staff_purchase_order_notifier.dart';
import 'package:beauty_project/vm/admin/staff_purchase_order_state.dart';
import 'package:beauty_project/vm/auth/auth_notifier.dart';
import 'package:beauty_project/vm/auth/api_client_provider.dart';
import 'package:beauty_project/vm/staff/staff_inventory_vm.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _Auth extends AuthService {
  const _Auth(this.role) : super(baseUrl: 'http://localhost');
  final String role;
  @override
  Future<EmployeeLogin> login({
    required String loginId,
    required String password,
  }) async => EmployeeLogin(
    accessToken: 't',
    tokenType: 'bearer',
    expiresIn: 3600,
    employeeId: 'E1',
    employeeRole: role,
  );
}

class _Outbound extends OutboundNotifier {
  @override
  OutboundState build() => const OutboundState();
  @override
  Future<void> fetchPreparingOrders() async {}
}

class _Inbound extends StaffPurchaseOrderNotifier {
  @override
  StaffPurchaseOrderState build() => const StaffPurchaseOrderState();
  @override
  Future<void> getPurchaseOrderList() async {}
}

void main() {
  const details = {
    'cosmetic_id': 'c1',
    'cosmetic_name': '크림',
    'sale_price': '1200.50',
    'unit_cost': '500.25',
    'min_stock_qty': 10,
    'target_stock_qty': 100,
    'volume_text': '50ml',
    'sale_status': 'ON_SALE',
  };
  testWidgets('옵션 저장 실패 시 상세 화면과 입력을 유지한다', (tester) async {
    final container = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWith((ref) => const _Auth('ADMIN')),
        cosmeticDetailsProvider('c1').overrideWith((ref) async => details),
        cosmeticImageProvider('c1').overrideWith((ref) async => null),
        apiClientProvider.overrideWith(
          (ref) => MockClient(
            (request) async => http.Response('{"detail":"failed"}', 500),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container
        .read(authProvider.notifier)
        .login(loginId: 'u', password: 'p');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: CosmeticOptionDetailView(cosmeticId: 'c1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byType(DropdownButtonFormField<String>),
      200,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.ensureVisible(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('판매 중단').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('변경사항 저장'));
    await tester.tap(find.text('변경사항 저장'));
    await tester.pumpAndSettle();
    expect(find.byType(CosmeticOptionDetailView), findsOneWidget);
    expect(find.text('failed'), findsOneWidget);
    expect(
      container
          .read(cosmeticDetailsProvider('c1'))
          .asData!
          .value['sale_status'],
      'ON_SALE',
    );
  });
  testWidgets('출고는 등록 배송업체 이름을 선택하고 키를 저장한다', (tester) async {
    final container = ProviderContainer(
      overrides: [
        outboundProvider.overrideWith(_Outbound.new),
        carrierChoicesProvider.overrideWith(
          (ref) async => [
            {'carrier_id': 'car_1', 'carrier_name': '등록 배송업체'},
          ],
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: OutboundPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('배송업체 ID'), findsNothing);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('등록 배송업체').last);
    await tester.pumpAndSettle();
    expect(container.read(outboundProvider).selectedCarrierId, 'car_1');
  });

  testWidgets('입고 업무 화면에는 별도 로그아웃 버튼이 없다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [staffPurchaseOrderProvider.overrideWith(_Inbound.new)],
        child: const MaterialApp(home: StaffPurchaseOrderPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.logout), findsNothing);
  });

  testWidgets('반품 필터는 선택한 상태의 건만 표시한다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          returnListProvider.overrideWith(
            (ref) async => [
              {
                'return_id': 'R1',
                'return_status': 'REQUESTED',
                'pickup_status': 'WAITING',
              },
              {
                'return_id': 'R2',
                'return_status': 'COMPLETED',
                'pickup_status': 'COLLECTED',
              },
            ],
          ),
        ],
        child: const MaterialApp(home: ReturnManagementPage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('완료').last);
    await tester.pumpAndSettle();
    expect(find.text('반품 R1 · REQUESTED'), findsNothing);
    expect(find.text('반품 R2 · COMPLETED'), findsOneWidget);
  });

  testWidgets('상품 등록은 카테고리 이름 목록을 사용한다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          manufacturersProvider.overrideWith(
            (ref) async => [const Manufacturer('m1', '발주처', null)],
          ),
          categoryChoicesProvider.overrideWith(
            (ref) async => [
              {'category_id': 'cat_1', 'category_name': '스킨케어'},
            ],
          ),
        ],
        child: const MaterialApp(home: CosmeticCreatePage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('카테고리 ID'), findsNothing);
    await tester.tap(
      find.widgetWithText(DropdownButtonFormField<String>, '카테고리 선택'),
    );
    await tester.pumpAndSettle();
    expect(find.text('스킨케어'), findsWidgets);
  });

  for (final role in ['ADMIN', 'STAFF']) {
    testWidgets('$role 재고 화면의 상품 등록과 판매 상태 변경 권한', (tester) async {
      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWith((ref) => _Auth(role)),
          distinctCosmeticsPageProvider.overrideWith((ref, args) async => []),
          cosmeticDetailsProvider('c1').overrideWith((ref) async => details),
          cosmeticImageProvider('c1').overrideWith((ref) async => null),
        ],
      );
      addTearDown(container.dispose);
      await container
          .read(authProvider.notifier)
          .login(loginId: 'u', password: 'p');
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: StaffInventoryView()),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byTooltip('상품 등록'),
        role == 'ADMIN' ? findsOneWidget : findsNothing,
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: CosmeticOptionDetailView(cosmeticId: 'c1'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (role == 'ADMIN') {
        await tester.scrollUntilVisible(
          find.byType(DropdownButtonFormField<String>),
          200,
          scrollable: find
              .descendant(
                of: find.byType(ListView),
                matching: find.byType(Scrollable),
              )
              .first,
        );
      }
      expect(
        find.byType(DropdownButtonFormField<String>),
        role == 'ADMIN' ? findsOneWidget : findsNothing,
      );
    });
  }
}
