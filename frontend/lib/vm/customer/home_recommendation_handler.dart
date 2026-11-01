// 기능: 홈 추천 사진을 중복 없이 무작위로 최대 20개 선택한다.
// 사진 조회 결과가 바뀔 때만 섞어 화면 재빌드나 탭 조작 중 순서가 흔들리지 않게 한다.
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beauty_project/model/customer/storage_image.dart';
import 'storage_image_handler.dart';

/// 테스트에서 난수 생성기를 주입할 수 있으며 Firebase 원본 목록은 수정하지 않는다.
final customerRecommendationRandomProvider = Provider<Random>(
  (ref) => Random(),
);

final customerHomeRecommendationsProvider =
    Provider.autoDispose<AsyncValue<List<CustomerStorageImage>>>((ref) {
      final images = ref.watch(customerStorageImagesProvider);
      final random = ref.watch(customerRecommendationRandomProvider);
      return images.whenData((source) {
        final shuffled = [...source]..shuffle(random);
        return List.unmodifiable(shuffled.take(20));
      });
    });
