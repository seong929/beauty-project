import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../vm/operations/workspace_notifier.dart';
import '../../../vm/auth/auth_notifier.dart';
import '../../../vm/admin/approval_notifier.dart';
import '../../../vm/admin/purchase_order_notifier.dart';
import '../../../vm/admin/outbound_notifier.dart';
import '../../operations/operations_theme.dart';
import '../../operations/operations_widgets.dart';
import 'inventory_page.dart';
import 'orders_page.dart';
import 'approval_page.dart';
import 'purchase_order_page.dart';
import 'manufacturer_page.dart';
import 'inbound_orders_page.dart';
import 'outbound_page.dart';
import 'delivery_page.dart';
import 'returns_page.dart';

extension OperationsSectionPresentation on OperationsSection {
  String get label => switch (this) {
    OperationsSection.overview => '대시보드',
    OperationsSection.inventory => '상품·재고',
    OperationsSection.orders => '주문 관리',
    OperationsSection.approvals => '품의 결재',
    OperationsSection.purchases => '발주 관리',
    OperationsSection.manufacturers => '발주처 관리',
    OperationsSection.inbound => '입고 관리',
    OperationsSection.outbound => '출고 관리',
    OperationsSection.deliveries => '배송 현황',
    OperationsSection.returns => '반품·환불',
  };
  IconData get icon => switch (this) {
    OperationsSection.overview => Icons.space_dashboard_outlined,
    OperationsSection.inventory => Icons.inventory_2_outlined,
    OperationsSection.orders => Icons.receipt_long_outlined,
    OperationsSection.approvals => Icons.fact_check_outlined,
    OperationsSection.purchases => Icons.shopping_bag_outlined,
    OperationsSection.manufacturers => Icons.factory_outlined,
    OperationsSection.inbound => Icons.move_to_inbox_outlined,
    OperationsSection.outbound => Icons.outbox_outlined,
    OperationsSection.deliveries => Icons.local_shipping_outlined,
    OperationsSection.returns => Icons.assignment_return_outlined,
  };
}

class OperationsWorkspace extends ConsumerWidget {
  const OperationsWorkspace({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(operationsWorkspaceProvider).section;
    final auth = ref.watch(authProvider);
    if (!auth.isAdmin) return const OperationsEmpty(title: '관리자 인증이 필요합니다.');
    void select(OperationsSection section) =>
        ref.read(operationsWorkspaceProvider.notifier).select(section);
    Widget menu(bool drawer) => Material(
      color: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(22, 28, 20, 24),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Color(0xFFE8F2ED),
                    child: Icon(Icons.spa_outlined, color: operationsGreen),
                  ),
                  SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '소담',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '본사 관리자',
                        style: TextStyle(fontSize: 11, color: operationsMuted),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  for (final section in OperationsSection.values)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        selected: section == selected,
                        leading: Icon(section.icon, size: 20),
                        title: Text(section.label),
                        onTap: () {
                          if (drawer) Navigator.pop(context);
                          select(section);
                        },
                      ),
                    ),
                ],
              ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(12),
              child: ListTile(
                leading: const Icon(Icons.logout, size: 20),
                title: const Text('로그아웃'),
                subtitle: Text(
                  auth.employee!.employeeId,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => ref.read(authProvider.notifier).logout(),
              ),
            ),
          ],
        ),
      ),
    );
    final page = switch (selected) {
      OperationsSection.overview => const _Overview(),
      OperationsSection.inventory => const OperationsInventoryPage(),
      OperationsSection.orders => const OperationsOrdersPage(),
      OperationsSection.approvals => const OperationsApprovalPage(
        embedded: true,
      ),
      OperationsSection.purchases => const OperationsPurchaseOrderPage(),
      OperationsSection.manufacturers => const OperationsManufacturerPage(),
      OperationsSection.inbound => const OperationsInboundOrdersPage(),
      OperationsSection.outbound => const _OutboundEntry(),
      OperationsSection.deliveries => const OperationsDeliveryPage(),
      OperationsSection.returns => const OperationsReturnsPage(),
    };
    return LayoutBuilder(
      builder: (context, bounds) {
        final wide = bounds.maxWidth >= 1000;
        return Scaffold(
          appBar: wide
              ? null
              : AppBar(title: const Text('소담 · 관리자 업무'), toolbarHeight: 52),
          drawer: wide ? null : Drawer(child: menu(true)),
          body: Row(
            children: [
              if (wide) ...[
                SizedBox(width: 232, child: menu(false)),
                const VerticalDivider(width: 1),
              ],
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(wide ? 20 : 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: KeyedSubtree(key: ValueKey(selected), child: page),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Overview extends ConsumerStatefulWidget {
  const _Overview();
  @override
  ConsumerState<_Overview> createState() => _OverviewState();
}

class _OverviewState extends ConsumerState<_Overview> {
  @override
  void initState() {
    super.initState();
    Future.microtask(_refresh);
  }

  void _refresh() {
    if (!mounted) return;
    ref.read(approvalProvider.notifier).getApprovalList();
    ref.read(purchaseOrderProvider.notifier).getPurchaseOrderList();
  }

  @override
  Widget build(BuildContext context) {
    final approvals = ref.watch(approvalProvider);
    final purchases = ref.watch(purchaseOrderProvider);
    void select(OperationsSection section) =>
        ref.read(operationsWorkspaceProvider.notifier).select(section);
    return Scaffold(
      appBar: AppBar(
        title: const Text('운영 대시보드'),
        actions: [
          IconButton(
            tooltip: '운영 현황 새로고침',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: OperationsStatus('본사 운영'),
          ),
          const SizedBox(height: 18),
          Text('오늘 확인할 업무', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text(
            '결재할 품의와 진행 중인 발주를 확인하고 업무를 이어가세요.',
            style: TextStyle(color: operationsMuted),
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, bounds) {
              final columns = bounds.maxWidth >= 650 ? 2 : 1;
              final width = (bounds.maxWidth - (columns - 1) * 16) / columns;
              return Wrap(
                spacing: 16,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: width,
                    child: OperationsMetric(
                      label: '결재 대기 품의',
                      value: approvals.isLoading
                          ? '조회 중'
                          : approvals.errorMessage != null
                          ? '조회 실패'
                          : '${approvals.approvals.where((a) => a.approvalStatus == 'REQUESTED' && a.decisionStatus == 'PENDING').length}건',
                      icon: Icons.fact_check_outlined,
                      detail: approvals.errorMessage == null
                          ? '품의 확인 및 승인·발주'
                          : '조회에 실패했습니다. 새로고침해 주세요.',
                      onTap: () => select(OperationsSection.approvals),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: OperationsMetric(
                      label: '입고 진행 발주',
                      value: purchases.isLoading
                          ? '조회 중'
                          : purchases.errorMessage != null
                          ? '조회 실패'
                          : '${purchases.purchaseOrders.where((p) => p.canInbound).length}건',
                      icon: Icons.move_to_inbox_outlined,
                      detail: purchases.errorMessage == null
                          ? '발주 확인 및 입고 등록'
                          : '조회에 실패했습니다. 새로고침해 주세요.',
                      onTap: () => select(OperationsSection.inbound),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 28),
          Text('업무 바로가기', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          for (final section in [
            OperationsSection.inventory,
            OperationsSection.orders,
            OperationsSection.outbound,
            OperationsSection.deliveries,
            OperationsSection.returns,
          ])
            Card(
              child: ListTile(
                leading: Icon(section.icon, color: operationsGreen),
                title: Text(section.label),
                trailing: const Icon(Icons.arrow_forward, size: 18),
                onTap: () => select(section),
              ),
            ),
        ],
      ),
    );
  }
}

class _OutboundEntry extends ConsumerStatefulWidget {
  const _OutboundEntry();
  @override
  ConsumerState<_OutboundEntry> createState() => _OutboundEntryState();
}

class _OutboundEntryState extends ConsumerState<_OutboundEntry> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) ref.read(outboundProvider.notifier).fetchPreparingOrders();
    });
  }

  @override
  Widget build(BuildContext context) => const OperationsOutboundPage();
}
