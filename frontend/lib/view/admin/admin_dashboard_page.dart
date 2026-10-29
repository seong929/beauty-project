import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../vm/admin/approval_notifier.dart';
import '../../vm/admin/outbound_notifier.dart';
import '../../vm/admin/purchase_order_notifier.dart';
import '../../vm/auth/auth_notifier.dart';
import '../staff/staff_inventory_view.dart';
import '../staff/staff_order_view.dart';
import 'approval_page.dart';
import 'cosmetic_create_page.dart';
import 'delivery_page.dart';
import 'outbound_page.dart';
import 'purchase_order_page.dart';
import 'return_management_page.dart';
import 'staff_purchase_order_page.dart';

enum _Section {
  dashboard('대시보드', Icons.dashboard_outlined),
  cosmetic('상품 등록', Icons.add_box_outlined),
  inventory('재고 관리', Icons.inventory_2_outlined),
  order('주문 관리', Icons.receipt_long_outlined),
  approval('품의 관리', Icons.fact_check_outlined),
  purchase('발주 관리', Icons.shopping_cart_outlined),
  inbound('입고 관리', Icons.move_to_inbox_outlined),
  outbound('출고 관리', Icons.outbox_outlined),
  delivery('배송 관리', Icons.local_shipping_outlined),
  returns('반품 관리', Icons.assignment_return_outlined);

  const _Section(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// 기존 업무 화면을 선택할 때만 생성하여 해당 화면의 조회를 시작한다.
class AdminDashboardPage extends ConsumerStatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  ConsumerState<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends ConsumerState<AdminDashboardPage> {
  _Section _selected = _Section.dashboard;

  void _select(_Section section) {
    if (!_canAccess(section)) return;
    setState(() => _selected = section);
  }

  bool _canAccess(_Section section) =>
      ref.read(authProvider).isAdmin ||
      !{
        _Section.cosmetic,
        _Section.approval,
        _Section.purchase,
      }.contains(section);

  Widget _page() => switch (_selected) {
    _Section.dashboard => _DashboardOverview(onSelect: _select),
    _Section.cosmetic => const CosmeticCreatePage(),
    _Section.inventory => const StaffInventoryView(),
    _Section.order => const StaffOrderView(),
    _Section.approval => const ApprovalPage(embedded: true),
    _Section.purchase => const PurchaseOrderPage(),
    _Section.inbound => const StaffPurchaseOrderPage(),
    _Section.outbound => const _OutboundEntry(),
    _Section.delivery => const DeliveryPage(),
    _Section.returns => const ReturnManagementPage(),
  };

  Widget _menu({required bool drawer}) => ListView(
    padding: EdgeInsets.zero,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 16, 16),
        child: Text(
          ref.watch(authProvider).isAdmin ? '통합 관리자' : '통합 직원 업무',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
      if (ref.watch(authProvider).employee case final employee?)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 16, 12),
          child: Text('${employee.employeeId} · ${employee.employeeRole}'),
        ),
      for (final section in _Section.values.where(_canAccess))
        ListTile(
          leading: Icon(section.icon),
          title: Text(section.label),
          selected: _selected == section,
          onTap: () {
            if (drawer) Navigator.of(context).pop();
            _select(section);
          },
        ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final employee = ref.watch(authProvider).employee;
    final compact = MediaQuery.sizeOf(context).width < 800;
    return Scaffold(
      appBar: AppBar(
        title: Text(_selected.label),
        actions: [
          if (!compact && employee != null)
            Center(
              child: Text('${employee.employeeId} · ${employee.employeeRole}'),
            ),
          IconButton(
            tooltip: '로그아웃',
            onPressed: () => ref.read(authProvider.notifier).logout(),
            icon: const Icon(Icons.logout),
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: compact ? Drawer(child: _menu(drawer: true)) : null,
      body: Row(
        children: [
          if (!compact) ...[
            SizedBox(width: 210, child: _menu(drawer: false)),
            const VerticalDivider(width: 1),
          ],
          Expanded(child: _page()),
        ],
      ),
    );
  }
}

/// 기존 출고 화면은 자체 초기 조회가 없으므로 진입 시 한 번 조회한다.
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
  Widget build(BuildContext context) => const OutboundPage();
}

class _DashboardOverview extends ConsumerStatefulWidget {
  const _DashboardOverview({required this.onSelect});
  final ValueChanged<_Section> onSelect;

  @override
  ConsumerState<_DashboardOverview> createState() => _DashboardOverviewState();
}

class _DashboardOverviewState extends ConsumerState<_DashboardOverview> {
  @override
  void initState() {
    super.initState();
    Future.microtask(_refresh);
  }

  void _refresh() {
    if (!mounted) return;
    if (!ref.read(authProvider).isAdmin) return;
    ref.read(approvalProvider.notifier).getApprovalList();
    ref.read(purchaseOrderProvider.notifier).getPurchaseOrderList();
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(authProvider).isAdmin;
    final approvals = isAdmin ? ref.watch(approvalProvider) : null;
    final purchases = isAdmin ? ref.watch(purchaseOrderProvider) : null;
    final pendingApprovals =
        approvals?.approvals
            .where(
              (a) =>
                  a.approvalStatus == 'REQUESTED' &&
                  a.decisionStatus == 'PENDING',
            )
            .length ??
        0;
    final activePurchases =
        purchases?.purchaseOrders.where((p) => p.canInbound).length ?? 0;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '운영 현황',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            if (isAdmin)
              IconButton(
                onPressed: _refresh,
                tooltip: '새로고침',
                icon: const Icon(Icons.refresh),
              ),
          ],
        ),
        const SizedBox(height: 8),
        const Text('실제 목록을 기준으로 표시합니다. 다른 업무는 메뉴에서 바로 확인할 수 있습니다.'),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            if (approvals != null)
              _OverviewCard(
                label: '결재 대기 품의',
                icon: Icons.fact_check_outlined,
                value: approvals.isLoading
                    ? '조회 중'
                    : approvals.errorMessage != null
                    ? '조회 실패'
                    : '$pendingApprovals건',
                detail: approvals.errorMessage,
                onTap: () => widget.onSelect(_Section.approval),
              ),
            if (purchases != null)
              _OverviewCard(
                label: '입고 진행 중 발주',
                icon: Icons.shopping_cart_outlined,
                value: purchases.isLoading
                    ? '조회 중'
                    : purchases.errorMessage != null
                    ? '조회 실패'
                    : '$activePurchases건',
                detail: purchases.errorMessage,
                onTap: () => widget.onSelect(_Section.purchase),
              ),
            for (final section in [
              _Section.inventory,
              _Section.order,
              _Section.inbound,
              _Section.outbound,
              _Section.returns,
              _Section.delivery,
            ])
              _OverviewCard(
                label: section.label,
                icon: section.icon,
                value: '바로가기',
                onTap: () => widget.onSelect(section),
              ),
          ],
        ),
      ],
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.label,
    required this.icon,
    required this.value,
    required this.onTap,
    this.detail,
  });
  final String label;
  final IconData icon;
  final String value;
  final String? detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 245,
    child: Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon),
              const SizedBox(height: 12),
              Text(label),
              const SizedBox(height: 8),
              Text(value, style: Theme.of(context).textTheme.titleLarge),
              if (detail != null) ...[
                const SizedBox(height: 8),
                Text(
                  detail!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
