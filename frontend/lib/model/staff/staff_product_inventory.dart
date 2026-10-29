// ignore_for_file: constant_identifier_names

enum SaleOption{
  NORMAL,
  NEAR_EXPIRY
}
enum InventoryStatus{
  MAINTAIN,
  HOLD,
  DISCARD
}
class StaffProductInventory {
  String inventoryId;
  String cosmeticId;
  int stockQuantity;
  DateTime receivedOn;
  DateTime? expiresOn;
  SaleOption saleOption;
  InventoryStatus inventoryStatus;

  StaffProductInventory({
    required this.inventoryId,
    required this.cosmeticId,
    required this.stockQuantity,
    required this.receivedOn,
    required this.expiresOn,
    required this.saleOption,
    required this.inventoryStatus
  });
}