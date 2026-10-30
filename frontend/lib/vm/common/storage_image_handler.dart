import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:beauty_project/firebase_options.dart';
import 'package:beauty_project/model/common/storage_image.dart';
import 'package:beauty_project/service/common/storage_service.dart';

final storageBucketProvider = Provider<String>((ref) {
  const override = String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
  if (override.isNotEmpty) return override;
  return (kIsWeb ? DefaultFirebaseOptions.web : DefaultFirebaseOptions.android)
      .storageBucket!;
});

final storageHttpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final storageImagesProvider = FutureProvider<List<StorageImage>>(
  (ref) => StorageService(
    client: ref.watch(storageHttpClientProvider),
    bucket: ref.watch(storageBucketProvider),
  ).fetchImages(),
  retry: (_, _) => null,
);

// DB는 유지한다. 실제 이름 일치가 우선이며, 사용자가 허용한 같은 종류의
// 대표 사진만 대체한다. 선크림·샴푸·틴트를 일반 보습 크림으로 대체하지 않는다.
ProductImageMatch? findProductStorageImage(
  List<StorageImage> images, {
  required String productId,
  required String productName,
}) {
  final canonical = images
      .where((image) => image.objectName == 'cosmetics/$productId/image')
      .firstOrNull;
  if (canonical != null) return ProductImageMatch(canonical);
  String normalized(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'\s+'), '');
  final name = normalized(productName);
  final exact = images
      .where((image) => normalized(image.title) == name)
      .toList();
  if (exact.length == 1) return ProductImageMatch(exact.single);

  const mapping = {
    'mfr_seed_aurora_cat_seed_skincare_1_1': '소나무 진정 시카 토너.png',
    'mfr_seed_aurora_cat_seed_skincare_1_2': '소나무 진정 시카 토너.png',
    'mfr_seed_mirae_cat_seed_body_1_1': '세라마이드 아토 로션.png',
  };
  var representative = mapping[productId];
  if (representative == null &&
      !RegExp(
        r'선크림|썬크림|선로션|샴푸|틴트|클렌|테스트|sunscreen|shampoo|tint|cleanser',
      ).hasMatch(name)) {
    if (RegExp(r'로션|에멀전|lotion|emulsion').hasMatch(name)) {
      representative = '세라마이드 아토 로션.png';
    } else if (RegExp(r'크림|cream').hasMatch(name)) {
      representative = '에스트라 아토베리어365 크림.png';
    } else if (RegExp(r'토너|스킨(?!케어)|toner').hasMatch(name)) {
      representative = '소나무 진정 시카 토너.png';
    }
  }
  if (representative == null) return null;
  final image = images
      .where((image) => image.name == representative)
      .firstOrNull;
  return image == null
      ? null
      : ProductImageMatch(image, isRepresentative: true);
}

final productStorageImageProvider =
    Provider.family<AsyncValue<ProductImageMatch?>, ({String id, String name})>(
      (ref, product) => ref
          .watch(storageImagesProvider)
          .whenData(
            (images) => findProductStorageImage(
              images,
              productId: product.id,
              productName: product.name,
            ),
          ),
    );

// 변경 내용(2026-10-30): 고객·관리자 이미지가 한 버킷·목록·상품 매칭 기준을 공유한다.
