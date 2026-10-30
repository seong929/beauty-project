import 'package:beauty_project/model/customer/storage_image.dart';
import 'package:beauty_project/model/customer/home_product.dart';
import 'package:beauty_project/view/customer/home/storage_product_image.dart';
import 'package:beauty_project/vm/customer/storage_image_handler.dart';
import 'package:flutter/material.dart';

// UI 회귀 테스트에서는 실제 Firebase에 요청하지 않고 로컬 이미지로 렌더링한다.
final previewStorageImages = [
  for (var i = 1; i <= 30; i++)
    CustomerStorageImage(
      bucket: 'fixture.firebasestorage.app',
      objectName: '${homePreviewProducts[i - 1].name}.png',
    ),
];

final previewStorageOverrides = [
  customerStorageImagesProvider.overrideWith(
    (ref) async => previewStorageImages,
  ),
  customerStorageImageLoaderProvider.overrideWithValue((url) {
    final name = Uri.parse(url).pathSegments.last;
    final number =
        previewStorageImages.indexWhere((image) => image.objectName == name) +
        1;
    return AssetImage('images/화면 캡처$number.png');
  }),
];
