import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../view/admin/approval_page.dart';
import '../view/admin/delivery_page.dart';
import '../view/admin/manufacturer_page.dart';
import '../view/admin/outbound_page.dart';
import '../view/admin/purchase_order_page.dart';
import '../view/admin/return_management_page.dart';
import '../view/admin/staff_purchase_order_page.dart';
import '../view/staff/staff_inventory_view.dart';
import '../view/staff/staff_order_view.dart';
import '../vm/admin/approval_notifier.dart';
import '../vm/admin/outbound_notifier.dart';
import '../vm/admin/purchase_order_notifier.dart';
import '../vm/auth/auth_notifier.dart';
import 'sodam_theme.dart';

enum _Page {
  dashboard('대시보드', Icons.space_dashboard_outlined, '워크스페이스'),
  inventory('화장품·재고 관리', Icons.spa_outlined, '상품·물류'),
  inbound('입고 관리', Icons.move_to_inbox_outlined, '상품·물류'),
  outbound('출고 관리', Icons.outbox_outlined, '상품·물류'),
  order('주문 관리', Icons.receipt_long_outlined, '주문·고객'),
  delivery('배송 관리', Icons.local_shipping_outlined, '주문·고객'),
  returns('반품 관리', Icons.assignment_return_outlined, '주문·고객'),
  approval('품의 관리', Icons.fact_check_outlined, '관리자 업무', admin: true),
  purchase('발주 관리', Icons.shopping_bag_outlined, '관리자 업무', admin: true),
  manufacturer('발주처 관리', Icons.factory_outlined, '관리자 업무', admin: true);

  const _Page(this.title, this.icon, this.group, {this.admin = false});
  final String title;
  final IconData icon;
  final String group;
  final bool admin;
}

class SodamShell extends ConsumerStatefulWidget {
  const SodamShell({super.key});

  @override
  ConsumerState<SodamShell> createState() => _SodamShellState();
}

class _SodamShellState extends ConsumerState<SodamShell> {
  _Page selected = _Page.dashboard;

  void select(_Page page) {
    if (page.admin && !ref.read(authProvider).isAdmin) return;
    setState(() => selected = page);
  }

  Widget content() => switch (selected) {
    _Page.dashboard => _Overview(onSelect: select),
    _Page.inventory => const StaffInventoryView(),
    _Page.inbound => const StaffPurchaseOrderPage(),
    _Page.outbound => const _OutboundEntry(),
    _Page.order => const StaffOrderView(),
    _Page.delivery => const DeliveryPage(),
    _Page.returns => const ReturnManagementPage(),
    _Page.approval => const ApprovalPage(embedded: true),
    _Page.purchase => const PurchaseOrderPage(),
    _Page.manufacturer => const ManufacturerPage(),
  };

  Widget menu(bool drawer) {
    final auth = ref.watch(authProvider);
    final pages = _Page.values.where((page) => !page.admin || auth.isAdmin);
    return Material(
      color: Colors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(26, 30, 24, 28),
              child: Row(
                children: [
                  _BrandMark(),
                  SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '소담',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 3,
                        ),
                      ),
                      Text(
                        'HEAD OFFICE',
                        style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 2,
                          color: sodamGreen,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
                children: [
                  for (final group in pages.map((p) => p.group).toSet()) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 24, 12, 10),
                      child: Text(
                        group,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF7C857C),
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    for (final page in pages.where((p) => p.group == group))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: ListTile(
                          dense: true,
                          minVerticalPadding: 13,
                          leading: Icon(page.icon, size: 21),
                          title: Text(
                            page.title,
                            style: TextStyle(
                              fontWeight: selected == page
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                          ),
                          selected: selected == page,
                          trailing: selected == page
                              ? const Icon(Icons.chevron_right, size: 18)
                              : null,
                          onTap: () {
                            if (drawer) Navigator.of(context).pop();
                            select(page);
                          },
                        ),
                      ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: const Color(0xFFE7EEE4),
                    child: Icon(
                      auth.isAdmin
                          ? Icons.admin_panel_settings_outlined
                          : Icons.badge_outlined,
                      color: sodamGreen,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          auth.isAdmin ? '본사 관리자' : '본사 직원',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          auth.employee?.employeeId ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.black45,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: '로그아웃',
                    onPressed: () => ref.read(authProvider.notifier).logout(),
                    icon: const Icon(Icons.logout, size: 18),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    if (!auth.isAdmin && selected.admin) selected = _Page.dashboard;
    return LayoutBuilder(
      builder: (context, bounds) {
        final wide = bounds.maxWidth >= 960;
        return Scaffold(
          drawer: wide ? null : Drawer(child: menu(true)),
          body: Row(
            children: [
              if (wide) ...[
                SizedBox(width: 256, child: menu(false)),
                const VerticalDivider(width: 1, color: sodamBorder),
              ],
              Expanded(
                child: Column(
                  children: [
                    Container(
                      height: 76,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(bottom: BorderSide(color: sodamBorder)),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: wide ? 32 : 16),
                      child: Row(
                        children: [
                          if (!wide)
                            Builder(
                              builder: (context) => IconButton(
                                tooltip: '메뉴 열기',
                                icon: const Icon(Icons.menu),
                                onPressed: () =>
                                    Scaffold.of(context).openDrawer(),
                              ),
                            ),
                          if (wide)
                            const Text(
                              '본사 관리',
                              style: TextStyle(
                                color: Color(0xFF7C857C),
                                fontSize: 13,
                              ),
                            ),
                          if (wide)
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 14),
                              child: Icon(
                                Icons.chevron_right,
                                size: 16,
                                color: Colors.black26,
                              ),
                            ),
                          Expanded(
                            child: Text(
                              selected.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF3EB),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Text(
                              auth.isAdmin ? '관리자' : '직원',
                              style: const TextStyle(
                                color: sodamGreen,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: KeyedSubtree(
                        key: ValueKey(selected),
                        child: content(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();
  @override
  Widget build(BuildContext context) => Container(
    width: 42,
    height: 46,
    decoration: BoxDecoration(
      color: sodamGreen,
      borderRadius: BorderRadius.circular(15),
    ),
    child: const Icon(Icons.spa_outlined, color: Color(0xFFF0F2DE), size: 27),
  );
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
  Widget build(BuildContext context) => const OutboundPage();
}

class _Overview extends ConsumerStatefulWidget {
  const _Overview({required this.onSelect});
  final ValueChanged<_Page> onSelect;
  @override
  ConsumerState<_Overview> createState() => _OverviewState();
}

class _OverviewState extends ConsumerState<_Overview> {
  @override
  void initState() {
    super.initState();
    Future.microtask(refresh);
  }

  void refresh() {
    if (!mounted || !ref.read(authProvider).isAdmin) return;
    ref.read(approvalProvider.notifier).getApprovalList();
    ref.read(purchaseOrderProvider.notifier).getPurchaseOrderList();
  }

  @override
  Widget build(BuildContext context) {
    final admin = ref.watch(authProvider).isAdmin;
    final approvals = admin ? ref.watch(approvalProvider) : null;
    final purchases = admin ? ref.watch(purchaseOrderProvider) : null;
    final now = DateTime.now();
    return LayoutBuilder(
      builder: (context, bounds) {
        final roomy = bounds.maxWidth >= 760;
        final gap = roomy ? 24.0 : 16.0;
        final padding = roomy ? 36.0 : 20.0;
        final cardWidth = (bounds.maxWidth - padding * 2 - gap) / 2;
        return ListView(
          padding: EdgeInsets.all(padding),
          children: [
            Text(
              'WORKSPACE  /  OVERVIEW',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 2,
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '오늘의 소담',
                        style: TextStyle(
                          fontSize: roomy ? 32 : 27,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 9),
                      Text(
                        admin
                            ? '운영 흐름을 살피고, 필요한 결정을 한곳에서.'
                            : '상품부터 배송까지, 오늘의 업무를 차근차근.',
                        style: const TextStyle(
                          color: Color(0xFF788177),
                          height: 1.6,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                if (roomy)
                  Text(
                    '${now.year}.${now.month.toString().padLeft(2, '0')}.${now.day.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                      color: Color(0xFF788177),
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 28),
            Container(
              padding: EdgeInsets.all(roomy ? 28 : 22),
              decoration: BoxDecoration(
                color: sodamGreen,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'SODAM OPERATIONS',
                          style: TextStyle(
                            color: Color(0xFFCCD8BC),
                            fontSize: 10,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          admin
                              ? '작은 확인이 만드는\n빈틈없는 운영'
                              : '정확한 재고에서 시작하는\n기분 좋은 하루',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: roomy ? 27 : 23,
                            height: 1.45,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFEDF0DF),
                            foregroundColor: sodamGreen,
                          ),
                          onPressed: () => widget.onSelect(
                            admin ? _Page.approval : _Page.inventory,
                          ),
                          icon: const Icon(Icons.arrow_forward, size: 17),
                          label: Text(admin ? '품의 확인하기' : '재고 확인하기'),
                        ),
                      ],
                    ),
                  ),
                  if (roomy)
                    const Padding(
                      padding: EdgeInsets.only(right: 22),
                      child: Icon(
                        Icons.spa_outlined,
                        size: 120,
                        color: Color(0xFF829879),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            if (admin) ...[
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '확인이 필요한 업무',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '현황 새로고침',
                    onPressed: refresh,
                    icon: const Icon(Icons.refresh, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  SizedBox(
                    width: roomy ? cardWidth : bounds.maxWidth - padding * 2,
                    child: _Metric(
                      title: '결재 대기 품의',
                      icon: Icons.fact_check_outlined,
                      value: approvals!.isLoading
                          ? '조회 중'
                          : approvals.errorMessage != null
                          ? '조회 실패'
                          : '${approvals.approvals.where((a) => a.approvalStatus == 'REQUESTED' && a.decisionStatus == 'PENDING').length}건',
                      detail: approvals.errorMessage != null
                          ? '연결 상태를 확인하고 다시 조회해 주세요.'
                          : '승인을 기다리는 품의를 확인하세요.',
                      onTap: () => widget.onSelect(_Page.approval),
                    ),
                  ),
                  SizedBox(
                    width: roomy ? cardWidth : bounds.maxWidth - padding * 2,
                    child: _Metric(
                      title: '입고 진행 중 발주',
                      icon: Icons.move_to_inbox_outlined,
                      value: purchases!.isLoading
                          ? '조회 중'
                          : purchases.errorMessage != null
                          ? '조회 실패'
                          : '${purchases.purchaseOrders.where((p) => p.canInbound).length}건',
                      detail: purchases.errorMessage != null
                          ? '연결 상태를 확인하고 다시 조회해 주세요.'
                          : '진행 중인 발주의 입고 상태를 살펴보세요.',
                      onTap: () => widget.onSelect(_Page.purchase),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
            const Text(
              '업무 바로가기',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
            ),
            const SizedBox(height: 8),
            const Text(
              '자주 사용하는 업무를 빠르게 시작하세요.',
              style: TextStyle(color: Color(0xFF788177), fontSize: 12),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final entry in const [
                  (_Page.inventory, '상품 옵션과 보유 재고를 확인해요.'),
                  (_Page.order, '접수된 주문과 처리 내역을 살펴봐요.'),
                  (_Page.inbound, '발주 상품의 입고를 처리해요.'),
                  (_Page.outbound, '준비된 주문의 출고를 진행해요.'),
                  (_Page.delivery, '배송 진행 상태를 확인해요.'),
                  (_Page.returns, '반품 접수부터 검수까지 관리해요.'),
                ])
                  SizedBox(
                    width: roomy ? cardWidth : bounds.maxWidth - padding * 2,
                    child: Card(
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => widget.onSelect(entry.$1),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0F3EB),
                                  borderRadius: BorderRadius.circular(13),
                                ),
                                child: Icon(
                                  entry.$1.icon,
                                  color: sodamGreen,
                                  size: 23,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      entry.$1.title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      entry.$2,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF788177),
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.north_east,
                                size: 17,
                                color: Color(0xFF7C857C),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 36),
            const Text(
              '소담  ·  일상을 채우는 차분한 관리',
              style: TextStyle(color: Color(0xFF8A9185), fontSize: 11),
            ),
          ],
        );
      },
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.title,
    required this.icon,
    required this.value,
    required this.detail,
    required this.onTap,
  });
  final String title, value, detail;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 21, color: sodamGreen),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(title, style: const TextStyle(fontSize: 13)),
                ),
                const Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: Colors.black38,
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              value,
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              detail,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF788177),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
