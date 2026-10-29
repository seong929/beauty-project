import 'staff_product_inventory.dart';

/// DB Enum 상태를 변경하지 않고 DISCARD 재고를 수량에 따라 구분하는 검색 필터.
enum InventoryDisplayFilter {
  all,
  maintain,
  hold,
  discard,
  discardCompleted;

  String? get apiValue => switch (this) {
    InventoryDisplayFilter.all => null,
    InventoryDisplayFilter.maintain => 'MAINTAIN',
    InventoryDisplayFilter.hold => 'HOLD',
    InventoryDisplayFilter.discard => 'DISCARD',
    InventoryDisplayFilter.discardCompleted => 'DISCARD_COMPLETED',
  };

  String get label => switch (this) {
    InventoryDisplayFilter.all => '전체 재고',
    InventoryDisplayFilter.maintain => '정상 유지',
    InventoryDisplayFilter.hold => '보류',
    InventoryDisplayFilter.discard => '폐기 대상 (1개 이상)',
    InventoryDisplayFilter.discardCompleted => '폐기 완료 (0개)',
  };

  static InventoryDisplayFilter forBatch(StaffProductInventory batch) =>
      switch (batch.inventoryStatus) {
        InventoryStatus.MAINTAIN => InventoryDisplayFilter.maintain,
        InventoryStatus.HOLD => InventoryDisplayFilter.hold,
        InventoryStatus.DISCARD => batch.stockQuantity == 0
            ? InventoryDisplayFilter.discardCompleted
            : InventoryDisplayFilter.discard,
      };
}

/// 서버 상태별 집계(건수 및 수량)
class InventoryStatusSummary {
  const InventoryStatusSummary({
    required this.inventoryCount,
    required this.totalQuantity,
  });

  final int inventoryCount;
  final int totalQuantity;
}

class InventoryStatusOverview {
  const InventoryStatusOverview({
    required this.summary,
    required this.inventories,
    required this.cosmeticNames,
    required this.page,
    required this.pageSize,
    required this.total,
    required this.totalPages,
  });

  /// 키: MAINTAIN, HOLD, DISCARD, DISCARD_COMPLETED
  final Map<String, InventoryStatusSummary> summary;
  final List<StaffProductInventory> inventories;
  final Map<String, String> cosmeticNames;
  final int page;
  final int pageSize;
  final int total;
  final int totalPages;
}
