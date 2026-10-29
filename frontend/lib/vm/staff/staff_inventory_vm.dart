import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../model/staff/staff_cosmetic.dart';
import '../../model/staff/staff_product_inventory.dart';
import '../../model/staff/staff_inventory_status.dart';
import '../../model/staff/staff_inventory_history.dart';
import '../../service/staff/staff_inventory_service.dart';

final staffInventoryServiceProvider = Provider<StaffInventoryService>(
  (ref) {
    final service = StaffInventoryService(
      baseUrl: 'http://127.0.0.1:8000',
    );
    ref.onDispose(service.dispose);
    return service;
  },
);

/// 화면 진입 시 화장품 종류 목록만 조회합니다.
const int inventoryPageSize = 20;

class InventoryPageVm extends Notifier<int> {
  @override
  int build() => 1;
  void goTo(int value) { if (value >= 1) state = value; }
  void reset() => state = 1;
}

final staffCosmeticsPageProvider = NotifierProvider<InventoryPageVm, int>(
  InventoryPageVm.new,
);
final staffStatusPageProvider = NotifierProvider<InventoryPageVm, int>(
  InventoryPageVm.new,
);

final distinctCosmeticsPageProvider =
    FutureProvider.family<List<RootCosmetics>, (int, InventoryDisplayFilter)>((ref, args) {
  return ref.read(staffInventoryServiceProvider).getDistinctCosmeticsPage(
    page: args.$1, count: inventoryPageSize, inventoryStatus: args.$2.apiValue,
  );
});

/// 화장품 행을 펼친 시점에만 옵션 목록을 조회합니다.
final cosmeticOptionsProvider =
    FutureProvider.family<List<OptionCosmetics>, (String, InventoryDisplayFilter)>((ref, args) {
  return ref.read(staffInventoryServiceProvider).getCosmeticOptions(
    args.$1, inventoryStatus: args.$2.apiValue,
  );
});

/// 옵션 행을 펼친 시점에만 해당 옵션의 재고를 조회합니다.
final cosmeticInventoryProvider =
    FutureProvider.family<List<StaffProductInventory>, (String, InventoryDisplayFilter)>((ref, args) {
  return ref.read(staffInventoryServiceProvider).getInventoryByCosmeticId(
    args.$1, inventoryStatus: args.$2.apiValue,
  );
});

/// Riverpod 3.x: StateNotifier 대신 Notifier를 사용합니다.
/// 펼침 상태만 관리하며 하위 조회는 View에서 expanded일 때 시작됩니다.
class InventoryExpansionVm extends Notifier<Set<String>> {
  @override
  Set<String> build() => <String>{};

  void clear() => state = <String>{};

  void toggle(String key) {
    final next = <String>{...state};
    if (!next.add(key)) {
      next.remove(key);
    }
    state = next;
  }
}

final inventoryExpansionProvider =
    NotifierProvider<InventoryExpansionVm, Set<String>>(
  InventoryExpansionVm.new,
);

/// 두 표시 모드가 같은 선택을 공유하도록 단일 Notifier로 관리합니다.
class InventoryFilterVm extends Notifier<InventoryDisplayFilter> {
  @override
  InventoryDisplayFilter build() => InventoryDisplayFilter.all;

  void setFilter(InventoryDisplayFilter value) => state = value;
}

final staffInventoryFilterProvider =
    NotifierProvider<InventoryFilterVm, InventoryDisplayFilter>(
  InventoryFilterVm.new,
);

/// 폐기 및 세부 갱신 후 모든 필터·페이지 캐시를 다시 평가합니다.
void invalidateStaffInventoryLists(WidgetRef ref) {
  ref.invalidate(distinctCosmeticsPageProvider);
  ref.invalidate(cosmeticOptionsProvider);
  ref.invalidate(cosmeticInventoryProvider);
  ref.invalidate(inventoryStatusOverviewProvider);
}


/// 상태별 전체 재고는 해당 표시 모드로 진입할 때에만 요청합니다.
final inventoryStatusOverviewProvider =
    FutureProvider.family<InventoryStatusOverview, (int, bool, InventoryDisplayFilter)>((ref, args) {
  return ref.read(staffInventoryServiceProvider).getInventoryGroupedByStatus(
    page: args.$1,
    count: inventoryPageSize,
    descending: args.$2,
    inventoryStatus: args.$3.apiValue,
  );
});

enum StaffInventoryDisplayMode { cosmetics, status }

/// 상단 '변경' 버튼의 화장품별 / 재고 상태별 표시 모드.
class StaffInventoryDisplayVm extends Notifier<StaffInventoryDisplayMode> {
  @override
  StaffInventoryDisplayMode build() => StaffInventoryDisplayMode.cosmetics;

  void toggle() {
    state = state == StaffInventoryDisplayMode.cosmetics
        ? StaffInventoryDisplayMode.status
        : StaffInventoryDisplayMode.cosmetics;
  }
}

final staffInventoryDisplayProvider =
    NotifierProvider<StaffInventoryDisplayVm, StaffInventoryDisplayMode>(
  StaffInventoryDisplayVm.new,
);

/// 기본 DESC: DISCARD -> HOLD -> MAINTAIN.
class StaffInventoryStatusSortVm extends Notifier<bool> {
  @override
  bool build() => true;

  void toggle() => state = !state;
}

final staffInventoryStatusDescendingProvider =
    NotifierProvider<StaffInventoryStatusSortVm, bool>(
  StaffInventoryStatusSortVm.new,
);

/// 재고 배치 단위로 캐시하고, 해당 상세 화면에 진입할 때만 조회합니다.
final inventoryBatchDetailProvider =
    FutureProvider.family<StaffInventoryBatchDetail, String>((ref, inventoryId) {
  return ref.read(staffInventoryServiceProvider).getInventoryBatchDetail(inventoryId);
});

/// 입고 이력은 해당 섹션을 펼친 때에만 조회합니다.
final inventoryInboundHistoryProvider =
    FutureProvider.family<List<StaffInventoryInbound>, String>((ref, inventoryId) {
  return ref.read(staffInventoryServiceProvider).getInventoryInboundHistory(inventoryId);
});

/// 출고 이력은 (재고 ID, 페이지)별로 캐시합니다.
final inventoryOutboundHistoryProvider =
    FutureProvider.family<StaffInventoryOutboundPage, (String, int)>((ref, key) {
  return ref.read(staffInventoryServiceProvider).getInventoryOutboundHistory(
    key.$1, page: key.$2,
  );
});
