
// 기능: 흰색 정사각형 상품 이미지와 로딩·오류 표시.
// 표시 계층: ref.watch로 상태를 구독하고 사용자 동작은 Notifier·서비스에 전달한다.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beauty_project/model/customer/storage_image.dart';
export '../../common/storage_photo.dart';
import '../../common/storage_photo.dart' show storageImageLoaderProvider, StoragePhoto;

final customerStorageImageLoaderProvider = storageImageLoaderProvider;

// 모든 상품 사진을 흰색 정사각형 영역에 표시한다.
class CustomerProductImageFrame extends StatelessWidget {
  const CustomerProductImageFrame({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
    child: AspectRatio(
      aspectRatio: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: ColoredBox(
          color: Colors.white,
          child: child,
        ),
      ),
    ),
  );
}

class CustomerStoragePhoto extends ConsumerWidget {
  const CustomerStoragePhoto({
    super.key,
    required this.image,
    this.label,
  });

  final CustomerStorageImage image;
  final String? label;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      CustomerProductImageFrame(
        child: StoragePhoto(
          image: image,
          label: label,
        ),
      );
}
