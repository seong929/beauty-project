// ignore_for_file: constant_identifier_names

enum SaleStatus{
  ON_SALE,
  DISCONTINUED
}

class RootCosmetics{
  String name;
  String categoryName;

  RootCosmetics({
    required this.name,
    required this.categoryName
  });
}

class OptionCosmetics{
  String cosmeticId;
  String manufactureerId;
  int salePrice, unitPrice;
  int minStock, targetStock;
  String? volumeText, saleStatus;

  OptionCosmetics({
    required this.cosmeticId,
    required this.manufactureerId,
    required this.salePrice,
    required this.unitPrice,
    required this.minStock,
    required this.targetStock,
    this.volumeText,
    this.saleStatus
  });
}