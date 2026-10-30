import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beauty_project/model/customer/home_product.dart';
import 'package:beauty_project/model/customer/storage_image.dart';
import 'package:beauty_project/model/customer/storage_product.dart';
import 'product_handler.dart';
import 'review_handler.dart';
import 'storage_image_handler.dart';

List<StorageProduct> buildStorageProducts(
  List<CustomerStorageImage> images,
  List<HomeProduct> catalog,
) {
  String normalize(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'\s+'), '');
  final products = <String, StorageProduct>{};
  for (final image in images) {
    final matches = catalog.where(
      (product) =>
          image.objectName == 'cosmetics/${product.id}/image' ||
          normalize(image.title) == normalize(product.name),
    );
    if (matches.isEmpty) {
      // 상품번호 전용 이미지에 연결된 판매 정보가 없으면 다른 상품에 재사용하지 않는다.
      if (image.objectName.startsWith('cosmetics/')) continue;
      final type = storageProductType(image.title);
      if (type == null) continue;
      final product = StorageProduct(image: image, type: type);
      products[product.id] = product;
    } else {
      for (final linked in matches) {
        final type = storageProductType(linked.name);
        if (type == null) continue;
        final existing = products[linked.id];
        final canonical = 'cosmetics/${linked.id}/image';
        if (existing?.image.objectName == canonical) continue;
        products[linked.id] = StorageProduct(
          image: image,
          type: type,
          linkedProduct: linked,
        );
      }
    }
  }
  return List.unmodifiable(products.values);
}

final storageProductsProvider = Provider<AsyncValue<List<StorageProduct>>>((
  ref,
) {
  final catalog =
      ref.watch(homeCatalogProductsProvider).value ?? <HomeProduct>[];
  return ref
      .watch(customerStorageImagesProvider)
      .whenData((images) => buildStorageProducts(images, catalog));
});

final filteredStorageProductsProvider = Provider<List<StorageProduct>>((ref) {
  final filters = ref.watch(productFilterProvider);
  return filterProducts(
    ref.watch(storageProductsProvider).value ?? <StorageProduct>[],
    filters,
    ratings: filters.sort == ProductSort.ratingHigh
        ? ref.watch(catalogProductRatingsProvider).value
        : null,
  );
});

// 변경 내용(2026-10-30): 홈 표시 목록은 Firebase 사진이 기준이며 DB 연결은 상품번호·이름이 일치할 때만 한다.
// 미연결 항목의 임시 가격·용량은 표시 전용이며 기존 DB 결제·장바구니 정보는 유지한다.
