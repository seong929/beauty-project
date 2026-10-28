import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../model/staff/staff_cosmetic.dart';
import '../../model/staff/staff_product_inventory.dart';
import '../../model/staff/staff_inventory_status.dart';
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
final distinctCosmeticsProvider = FutureProvider<List<RootCosmetics>>((ref) {
  return ref.read(staffInventoryServiceProvider).getDistinctCosmetics();
});

/// 화장품 행을 펼친 시점에만 옵션 목록을 조회합니다.
final cosmeticOptionsProvider =
    FutureProvider.family<List<OptionCosmetics>, String>((ref, name) {
  return ref.read(staffInventoryServiceProvider).getCosmeticOptions(name);
});

/// 옵션 행을 펼친 시점에만 해당 옵션의 재고를 조회합니다.
final cosmeticInventoryProvider =
    FutureProvider.family<List<StaffProductInventory>, String>((ref, id) {
  return ref.read(staffInventoryServiceProvider).getInventoryByCosmeticId(id);
});

/// Riverpod 3.x: StateNotifier 대신 Notifier를 사용합니다.
/// 펼침 상태만 관리하며 하위 조회는 View에서 expanded일 때 시작됩니다.
class InventoryExpansionVm extends Notifier<Set<String>> {
  @override
  Set<String> build() => <String>{};

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


/// 상태별 전체 재고는 해당 표시 모드로 진입할 때에만 요청합니다.
final inventoryStatusOverviewProvider =
    FutureProvider<InventoryStatusOverview>((ref) {
  return ref.read(staffInventoryServiceProvider).getInventoryGroupedByStatus();
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
