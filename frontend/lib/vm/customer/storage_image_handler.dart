import 'package:beauty_project/model/customer/storage_image.dart';
import '../common/storage_image_handler.dart';
export '../common/storage_image_handler.dart';

// 기존 고객 Provider 이름은 공용 Provider의 별칭이다. 데이터나 Firebase 앱을 중복 생성하지 않는다.
final customerStorageBucketProvider = storageBucketProvider;
final customerStorageHttpClientProvider = storageHttpClientProvider;
final customerStorageImagesProvider = storageImagesProvider;
final customerProductImageProvider = productStorageImageProvider;

CustomerProductImage? findCustomerProductImage(
  List<CustomerStorageImage> images, {
  required String productId,
  required String productName,
}) => findProductStorageImage(
  images,
  productId: productId,
  productName: productName,
);

// 변경 내용(2026-10-30): 고객과 관리자에서 동일한 이미지 목록과 연결 결과를 사용한다.
