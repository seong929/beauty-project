import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../model/staff/staff_order.dart';
import '../../service/staff/staff_order_service.dart';
import 'staff_inventory_vm.dart';

const int staffOrderPageSize = 20;

enum StaffOrderScope { active, all, selected }

class StaffOrderFilters {
  const StaffOrderFilters({
    this.page = 1,
    this.ascending = false,
    this.scope = StaffOrderScope.active,
    this.selectedStatuses = const {},
    this.customerId = '',
  });

  final int page;
  final bool ascending;
  final StaffOrderScope scope;
  final Set<StaffOrderStatus> selectedStatuses;
  final String customerId;

  /// 백엔드가 statuses를 생략하면 '진행 중'을 기본값으로 적용합니다.
  List<StaffOrderStatus>? get requestedStatuses => switch (scope) {
    StaffOrderScope.active => null,
    StaffOrderScope.all => StaffOrderStatus.values,
    StaffOrderScope.selected => StaffOrderStatus.values
        .where(selectedStatuses.contains)
        .toList(),
  };

  bool get isSelectionEmpty => scope == StaffOrderScope.selected && selectedStatuses.isEmpty;

  StaffOrderFilters copyWith({
    int? page,
    bool? ascending,
    StaffOrderScope? scope,
    Set<StaffOrderStatus>? selectedStatuses,
    String? customerId,
  }) => StaffOrderFilters(
    page: page ?? this.page,
    ascending: ascending ?? this.ascending,
    scope: scope ?? this.scope,
    selectedStatuses: selectedStatuses ?? this.selectedStatuses,
    customerId: customerId ?? this.customerId,
  );

  StaffOrderQueryKey get queryKey => (
    page,
    ascending,
    scope.name,
    (requestedStatuses ?? []).map((e) => e.name).join(','),
    customerId.trim(),
  );
}

/// 순서대로: 페이지, 정렬, 범위, 상태 CSV, 고객 ID.
/// record 구조적 동등성 덕분에 동일 조건은 Riverpod 캐시가 재사용됩니다.
typedef StaffOrderQueryKey = (int, bool, String, String, String);

class StaffOrderListVm extends Notifier<StaffOrderFilters> {
  @override
  StaffOrderFilters build() => const StaffOrderFilters();

  void setPage(int page) {
    if (page >= 1) state = state.copyWith(page: page);
  }

  void setAscending(bool ascending) => state = state.copyWith(
    ascending: ascending,
    page: 1,
  );

  void setScope(StaffOrderScope scope) => state = state.copyWith(
    scope: scope,
    page: 1,
  );

  void toggleStatus(StaffOrderStatus status) {
    final updated = {...state.selectedStatuses};
    if (!updated.add(status)) updated.remove(status);
    state = state.copyWith(selectedStatuses: updated, page: 1);
  }

  void setCustomerId(String value) => state = state.copyWith(
    customerId: value.trim(),
    page: 1,
  );

  void reset() => state = const StaffOrderFilters();
}

final staffOrderListVmProvider =
    NotifierProvider<StaffOrderListVm, StaffOrderFilters>(StaffOrderListVm.new);

final staffOrderServiceProvider = Provider<StaffOrderService>(
  (ref) => StaffOrderService(ref.read(staffInventoryServiceProvider)),
);

final staffOrdersPageProvider = FutureProvider.family<StaffOrderPage, StaffOrderQueryKey>(
  (ref, key) {
    final statuses = key.$4.isEmpty
        ? null
        : key.$4.split(',').map(StaffOrderStatus.values.byName).toList();
    return ref.read(staffOrderServiceProvider).getOrders(
      page: key.$1,
      count: staffOrderPageSize,
      asc: key.$2,
      statuses: statuses,
      customerId: key.$5.isEmpty ? null : key.$5,
    );
  },
);

/// 주문을 선택해야 처음 호출됩니다. 다른 주문 ID는 별도로 캐시됩니다.
final staffOrderDetailProvider = FutureProvider.family<StaffOrder, String>(
  (ref, orderId) => ref.read(staffOrderServiceProvider).getOrderDetail(orderId),
);

/// 상품 목록 펼치기 이전에는 watch하지 않습니다. 닫으면 결과를 재사용합니다.
final staffOrderItemsProvider = FutureProvider.family<List<StaffOrderItem>, String>(
  (ref, orderId) => ref.read(staffOrderServiceProvider).getOrderItems(orderId),
);
