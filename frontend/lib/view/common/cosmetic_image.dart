import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../model/common/storage_image.dart';
import '../../vm/common/storage_image_handler.dart';
import 'storage_photo.dart';

final cosmeticImageLoaderProvider = storageImageLoaderProvider;

/// 고객과 같은 공개 Storage 목록, 상품 매칭 및 이미지 로더를 사용한다.
class CosmeticImage extends ConsumerWidget {
  const CosmeticImage({
    super.key,
    required this.cosmeticIds,
    this.cosmeticName = '',
    this.size = 64,
  });
  final List<String> cosmeticIds;
  final String cosmeticName;
  final double size;

  ProductImageMatch? _match(List<StorageImage> images) {
    // 그룹에 속한 모든 옵션의 전용 사진을 먼저 확인한다.
    for (final id in cosmeticIds) {
      final canonical = images
          .where((image) => image.objectName == 'cosmetics/$id/image')
          .firstOrNull;
      if (canonical != null) return ProductImageMatch(canonical);
    }
    // 구형 API 응답에 옵션 ID가 없어도 고객과 같이 상품명으로 찾는다.
    return findProductStorageImage(
      images,
      productId: cosmeticIds.firstOrNull ?? '',
      productName: cosmeticName,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget placeholder() => const ProductImageFrame(
      child: Center(
        child: Icon(Icons.image_outlined, color: Color(0xFF8B9096)),
      ),
    );
    return SizedBox(
      width: size,
      height: size,
      child: ref
          .watch(storageImagesProvider)
          .when(
            loading: placeholder,
            error: (_, _) => const ProductImageFrame(
              child: Center(
                child: Icon(
                  Icons.broken_image_outlined,
                  semanticLabel: '이미지를 불러올 수 없어요.',
                ),
              ),
            ),
            data: (images) {
              final match = _match(images);
              if (match == null) return placeholder();
              return Stack(
                fit: StackFit.expand,
                children: [
                  StoragePhoto(
                    image: match.image,
                    label: match.isRepresentative
                        ? '$cosmeticName 대표 이미지'
                        : cosmeticName,
                  ),
                  if (match.isRepresentative)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        color: const Color(0xE6FFFFFF),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 3,
                          vertical: 1,
                        ),
                        child: const Text(
                          '대표 이미지',
                          style: TextStyle(fontSize: 8, color: Colors.grey),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
    );
  }
}
