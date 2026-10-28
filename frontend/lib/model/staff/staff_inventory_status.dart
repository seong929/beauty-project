import 'staff_product_inventory.dart';

/// /staff/inventory/by-status 의 상태별 집계(건수 / 수량).
class InventoryStatusSummary {
  const InventoryStatusSummary({
    required this.inventoryCount,
    required this.totalQuantity,
  });

  final int inventoryCount;
  final int totalQuantity;
}

/// 백엔드의 전체 상태별 조회 결과.
class InventoryStatusOverview {
  const InventoryStatusOverview({
    required this.summary,
    required this.inventories,
    required this.cosmeticNames,
  });

  final Map<InventoryStatus, InventoryStatusSummary> summary;
  final List<StaffProductInventory> inventories;

  /// cosmetic_id -> cosmetics.cosmetic_name, 상태별 목록의 표시 제목.
  final Map<String, String> cosmeticNames;
}
