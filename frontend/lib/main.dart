
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';

import 'view/customer/login/customer_auth_widgets.dart';
import 'view/customer/login/customer_login_screen.dart';

import 'view/admin/admin_dashboard_page.dart';
import 'view/auth/login_page.dart';

import 'vm/auth/auth_notifier.dart';
import 'vm/admin/approval_notifier.dart';
import 'vm/admin/delivery_notifier.dart' as admin_delivery;
import 'vm/admin/inbound_notifier.dart';
import 'vm/admin/outbound_notifier.dart';
import 'vm/admin/purchase_order_notifier.dart';
import 'vm/admin/staff_purchase_order_notifier.dart';
import 'vm/staff/staff_inventory_vm.dart';
import 'vm/staff/staff_order_vm.dart';
import 'vm/admin/management_vm.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    ref.listen(authProvider, (previous, next) {
      if (previous?.isLoggedIn == true && !next.isLoggedIn) {
        _navigatorKey.currentState?.popUntil(
          (route) => route.isFirst,
        );
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
      title: '화장품 판매 및 유통 관리 시스템',
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

    return const _LoginSelectionPage();
  }
}

class _LoginSelectionPage extends StatelessWidget {
  const _LoginSelectionPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('소담'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '로그인 유형 선택',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CustomerLoginScreen(),
                      ),
                    );
                  },
                  child: const Text('고객 로그인'),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LoginPage(),
                      ),
                    );
                  },
                  child: const Text('본사 직원 / 관리자 로그인'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
