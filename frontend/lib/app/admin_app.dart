import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../view/customer/login/customer_auth_widgets.dart';

import '../view/admin/admin_dashboard_page.dart';
import '../view/auth/login_page.dart';

import '../vm/auth/auth_notifier.dart';
import '../vm/admin/approval_notifier.dart';
import '../vm/admin/delivery_notifier.dart' as admin_delivery;
import '../vm/admin/inbound_notifier.dart';
import '../vm/admin/outbound_notifier.dart';
import '../vm/admin/purchase_order_notifier.dart';
import '../vm/admin/staff_purchase_order_notifier.dart';
import '../vm/staff/staff_inventory_vm.dart';
import '../vm/staff/staff_order_vm.dart';
import '../vm/admin/management_vm.dart';

class AdminApp extends ConsumerStatefulWidget {
  const AdminApp({super.key});

  @override
  ConsumerState<AdminApp> createState() => _AdminAppState();
}

class _AdminAppState extends ConsumerState<AdminApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    ref.listen(authProvider, (previous, next) {
      if (previous?.isLoggedIn == true && !next.isLoggedIn) {
        _navigatorKey.currentState?.popUntil((route) => route.isFirst);
      }

      if (previous?.isLoggedIn != true && next.isLoggedIn) {
        ref.invalidate(approvalProvider);
        ref.invalidate(purchaseOrderProvider);
        ref.invalidate(staffPurchaseOrderProvider);
        ref.invalidate(inboundProvider);
        ref.invalidate(outboundProvider);
        ref.invalidate(admin_delivery.deliveryProvider);
        ref.invalidate(distinctCosmeticsPageProvider);
        ref.invalidate(cosmeticOptionsProvider);
        ref.invalidate(cosmeticInventoryProvider);
        ref.invalidate(inventoryStatusOverviewProvider);
        ref.invalidate(inventoryBatchDetailProvider);
        ref.invalidate(inventoryInboundHistoryProvider);
        ref.invalidate(inventoryOutboundHistoryProvider);
        ref.invalidate(staffOrdersPageProvider);
        ref.invalidate(staffOrderDetailProvider);
        ref.invalidate(staffOrderItemsProvider);
        ref.invalidate(cosmeticImageProvider);
      }
    });

    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: '소담 관리자',
      debugShowCheckedModeBanner: false,
      theme: SodamStyle.theme,
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends ConsumerWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);

    if (auth.isAdmin || auth.isStaff) {
      return const AdminDashboardPage();
    }

    return const LoginPage(showCarrierLogin: false);
  }
}

// 변경 내용(2026-10-30): 관리자·직원 로그인과 대시보드만 표시하며 고객 로그인 선택 화면은 사용하지 않는다.
