import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../model/staff/staff_order.dart';
import '../../model/staff/staff_order_date_range.dart';
import '../../vm/staff/staff_order_vm.dart';
import 'staff_order_detail_view.dart';

/// 직원 주문 목록: 조건 변경 시 해당 페이지만 GET, 상세는 행을 눌렀을 때 조회.
class StaffOrderView extends ConsumerStatefulWidget {
  const StaffOrderView({super.key});

  @override
  ConsumerState<StaffOrderView> createState() => _StaffOrderViewState();
}

class _StaffOrderViewState extends ConsumerState<StaffOrderView> {
  final TextEditingController _customerInput = TextEditingController();
  final List<TextEditingController> _starts = List.generate(5, (_) => TextEditingController());
  final List<TextEditingController> _ends = List.generate(5, (_) => TextEditingController());

  @override
  void dispose() {
    _customerInput.dispose();
    for (final c in [..._starts, ..._ends]) {
      c.dispose();
    }
    super.dispose();
  }

  void _applyCustomerSearch() {
    ref.read(staffOrderListVmProvider.notifier).setCustomerId(_customerInput.text);
    FocusScope.of(context).unfocus();
  }

  void _applyDateSearch() {
    try {
      final start = StaffOrderDateParts.parseFields(
        _starts.map((c) => c.text).toList(), '시작',
      );
      final end = StaffOrderDateParts.parseFields(
        _ends.map((c) => c.text).toList(), '종료',
      );
      StaffOrderDateParts.validateRange(start, end);
      ref.read(staffOrderListVmProvider.notifier).setDateRange(start, end);
      FocusScope.of(context).unfocus();
    } on FormatException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  void _clearDateSearch() {
    for (final c in [..._starts, ..._ends]) {
      c.clear();
    }
    ref.read(staffOrderListVmProvider.notifier).setDateRange(null, null);
    FocusScope.of(context).unfocus();
  }

  Widget _dateInputs(List<TextEditingController> controllers, String title, bool tablet) {
    const names = ['연', '월', '일', '시', '분'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: List.generate(5, (i) => SizedBox(
            width: i == 0 ? (tablet ? 100 : 84) : (tablet ? 76 : 63),
            child: TextField(
              controller: controllers[i],
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(i == 0 ? 4 : 2)],
              textInputAction: i == 4 ? TextInputAction.done : TextInputAction.next,
              onSubmitted: i == 4 ? (_) => _applyDateSearch() : null,
              decoration: InputDecoration(
                isDense: true,
                labelText: names[i],
                hintText: i == 0 ? '2026' : '—',
                border: const OutlineInputBorder(),
              ),
            ),
          )),
        ),
      ],
    );
  }

  void _openOrder(String orderId) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (context) => StaffOrderDetailView(orderId: orderId),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filters = ref.watch(staffOrderListVmProvider);
    final width = MediaQuery.sizeOf(context).width;
    final tablet = width >= 680;
    final queryKey = filters.queryKey;

    return Scaffold(
      appBar: AppBar(
        title: const Text('직원 주문 내역'),
        actions: [
          IconButton(
            tooltip: '현재 조건 다시 조회',
            onPressed: filters.isSelectionEmpty
                ? null
                : () => ref.invalidate(staffOrdersPageProvider(queryKey)),
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: tablet ? 26 : 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 10),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: tablet ? 355 : 285),
                  child: SingleChildScrollView(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _OrderSearchBar(
                  customerInput: _customerInput,
                  onSearch: _applyCustomerSearch,
                  onClear: () {
                    _customerInput.clear();
                    ref.read(staffOrderListVmProvider.notifier).setCustomerId('');
                  },
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ChoiceChip(
                      label: const Text('진행 중'),
                      selected: filters.scope == StaffOrderScope.active,
                      onSelected: (_) => ref.read(staffOrderListVmProvider.notifier)
                          .setScope(StaffOrderScope.active),
                    ),
                    ChoiceChip(
                      label: const Text('전체 상태'),
                      selected: filters.scope == StaffOrderScope.all,
                      onSelected: (_) => ref.read(staffOrderListVmProvider.notifier)
                          .setScope(StaffOrderScope.all),
                    ),
                    ChoiceChip(
                      label: const Text('상태 선택'),
                      selected: filters.scope == StaffOrderScope.selected,
                      onSelected: (_) => ref.read(staffOrderListVmProvider.notifier)
                          .setScope(StaffOrderScope.selected),
                    ),
                    ActionChip(
                      tooltip: '주문 번호(order_seq) 정렬',
                      avatar: Icon(filters.ascending
                          ? Icons.arrow_upward : Icons.arrow_downward, size: 17),
                      label: Text(filters.ascending ? '오래된 주문순' : '최신 주문순'),
                      onPressed: () => ref.read(staffOrderListVmProvider.notifier)
                          .setAscending(!filters.ascending),
                    ),
                  ],
                ),
                if (filters.scope == StaffOrderScope.selected) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 7,
                    runSpacing: 0,
                    children: [
                      for (final status in StaffOrderStatus.values)
                        FilterChip(
                          label: Text(status.label),
                          selected: filters.selectedStatuses.contains(status),
                          onSelected: (_) => ref.read(staffOrderListVmProvider.notifier)
                              .toggleStatus(status),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 6),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  initiallyExpanded: filters.startDate != null || filters.endDate != null,
                  leading: const Icon(Icons.date_range_outlined),
                  title: Text(
                    filters.startDate == null && filters.endDate == null
                        ? '주문 일시 범위 (전체 기간)'
                        : '주문 일시: ${filters.startDate?.label ?? '처음'} ~ ${filters.endDate?.label ?? '끝'}',
                  ),
                  subtitle: const Text('연·월·일·시·분 순서로 입력 · 끝 단위까지 포함'),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _dateInputs(_starts, '시작 시각 (이상)', tablet),
                          const SizedBox(height: 12),
                          _dateInputs(_ends, '종료 시각 (해당 단위 전체 포함)', tablet),
                          const SizedBox(height: 10),
                          Wrap(spacing: 8, runSpacing: 6, children: [
                            FilledButton.icon(
                              onPressed: _applyDateSearch,
                              icon: const Icon(Icons.search),
                              label: const Text('기간 조회'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _clearDateSearch,
                              icon: const Icon(Icons.clear),
                              label: const Text('기간 초기화'),
                            ),
                          ]),
                          const SizedBox(height: 6),
                          Text('예: 2026/9 ~ 2026/10, 2026/9/20 10:30 ~ 2026/9/25 14:45',
                              style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
                ]),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: Text(
                      filters.scope == StaffOrderScope.active
                          ? '진행 중인 주문'
                          : '주문 검색 결과',
                      style: theme.textTheme.titleMedium,
                    )),
                    Text('페이지당 $staffOrderPageSize건',
                        style: theme.textTheme.bodySmall),
                  ],
                ),
                const SizedBox(height: 8),
                if (filters.isSelectionEmpty)
                  const Expanded(child: Center(
                    child: Text('조회할 주문 상태를 하나 이상 선택하세요.'),
                  ))
                else
                  Expanded(
                    child: _OrderPageBody(
                      queryKey: queryKey,
                      tablet: tablet,
                      openOrder: _openOrder,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OrderSearchBar extends StatelessWidget {
  const _OrderSearchBar({
    required this.customerInput,
    required this.onSearch,
    required this.onClear,
  });
  final TextEditingController customerInput;
  final VoidCallback onSearch;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: customerInput,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => onSearch(),
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
              labelText: '고객 ID 검색',
              hintText: '고객 ID를 입력하거나 비워 두세요',
              prefixIcon: Icon(Icons.person_search_outlined),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          tooltip: '고객 ID 검색',
          onPressed: onSearch,
          icon: const Icon(Icons.search),
        ),
        IconButton(
          tooltip: '고객 ID 검색 초기화',
          onPressed: onClear,
          icon: const Icon(Icons.clear),
        ),
      ],
    );
  }
}

class _OrderPageBody extends ConsumerWidget {
  const _OrderPageBody({
    required this.queryKey,
    required this.tablet,
    required this.openOrder,
  });
  final StaffOrderQueryKey queryKey;
  final bool tablet;
  final ValueChanged<String> openOrder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncPage = ref.watch(staffOrdersPageProvider(queryKey));
    return asyncPage.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => _OrderError(
        message: '주문 목록을 불러오지 못했습니다.\n$error',
        onRetry: () => ref.invalidate(staffOrdersPageProvider(queryKey)),
      ),
      data: (page) => Column(
        children: [
          Expanded(
            child: page.orders.isEmpty
                ? Center(
                    child: Text(page.page == 1
                        ? '조건에 해당하는 주문이 없습니다.'
                        : '이 페이지에는 주문이 없습니다. 이전 페이지로 돌아가세요.'),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 12),
                    itemCount: page.orders.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) => _OrderCard(
                      order: page.orders[index],
                      tablet: tablet,
                      onTap: () => openOrder(page.orders[index].orderId),
                    ),
                  ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.outlined(
                  tooltip: '이전 페이지',
                  icon: const Icon(Icons.chevron_left),
                  onPressed: page.page > 1
                      ? () => ref.read(staffOrderListVmProvider.notifier)
                          .setPage(page.page - 1)
                      : null,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Text('${page.page} 페이지 · ${page.orders.length}건'),
                ),
                IconButton.outlined(
                  tooltip: '다음 페이지',
                  icon: const Icon(Icons.chevron_right),
                  onPressed: page.mayHaveNext
                      ? () => ref.read(staffOrderListVmProvider.notifier)
                          .setPage(page.page + 1)
                      : null,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('전체 건수는 현재 API에서 제공하지 않습니다.',
                style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.tablet, required this.onTap});
  final StaffOrder order;
  final bool tablet;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = switch (order.status) {
      StaffOrderStatus.CANCELLED || StaffOrderStatus.RETURNED => theme.colorScheme.error,
      StaffOrderStatus.DELIVERED => theme.colorScheme.secondary,
      _ => theme.colorScheme.primary,
    };
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(tablet ? 18 : 13),
          child: tablet
              ? Row(children: [
                  Expanded(flex: 3, child: _OrderCell('주문 번호', order.orderId, isTitle: true)),
                  Expanded(flex: 2, child: _OrderCell('고객 ID', order.customerId)),
                  Expanded(flex: 2, child: _OrderCell('주문 일시', formatOrderDate(order.orderedAt))),
                  Expanded(flex: 2, child: _OrderStatusBadge(order.status, statusColor)),
                  const Icon(Icons.chevron_right),
                ])
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(child: Text(order.orderId,
                          style: theme.textTheme.titleMedium,
                          overflow: TextOverflow.ellipsis)),
                      _OrderStatusBadge(order.status, statusColor),
                      const Icon(Icons.chevron_right),
                    ]),
                    const SizedBox(height: 8),
                    Text('고객 ${order.customerId} · ${formatOrderDate(order.orderedAt)}',
                        style: theme.textTheme.bodySmall),
                  ],
                ),
        ),
      ),
    );
  }
}

class _OrderStatusBadge extends StatelessWidget {
  const _OrderStatusBadge(this.status, this.color);
  final StaffOrderStatus status;
  final Color color;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(status.label,
          style: TextStyle(color: color, fontWeight: FontWeight.w600)),
    ),
  );
}

class _OrderCell extends StatelessWidget {
  const _OrderCell(this.label, this.value, {this.isTitle = false});
  final String label;
  final String value;
  final bool isTitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text(value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: (isTitle ? theme.textTheme.titleSmall : theme.textTheme.bodyMedium)
                  ?.copyWith(fontWeight: isTitle ? FontWeight.w700 : null)),
        ],
      ),
    );
  }
}

class _OrderError extends StatelessWidget {
  const _OrderError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.error_outline, size: 36),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('다시 조회'),
        ),
      ]),
    ),
  );
}
