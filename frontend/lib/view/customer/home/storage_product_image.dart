// 기능: 흰색 정사각형 상품 이미지와 로딩·오류 표시.
// 표시 계층: ref.watch로 상태를 구독하고 사용자 동작은 Notifier·서비스에 전달한다.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beauty_project/model/customer/storage_image.dart';
import '../login/customer_auth_widgets.dart';

final customerStorageImageLoaderProvider =
    Provider<ImageProvider<Object> Function(String)>(
      (ref) =>
          (url) => NetworkImage(url),
    );

// 모든 상품 사진은 흰 바탕의 정사각형 안에 원본 전체를 표시한다.
class CustomerProductImageFrame extends StatelessWidget {
  const CustomerProductImageFrame({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
    child: AspectRatio(
      aspectRatio: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: ColoredBox(color: Colors.white, child: child),
      ),
    ),
  );
}

class CustomerStoragePhoto extends ConsumerWidget {
  const CustomerStoragePhoto({super.key, required this.image, this.label});
  final CustomerStorageImage image;
  final String? label;
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      CustomerProductImageFrame(
        child: Image(
          key: ValueKey(image.downloadUri.toString()),
          image: ref.watch(customerStorageImageLoaderProvider)(
            image.downloadUri.toString(),
          ),
          fit: BoxFit.contain,
          semanticLabel: label ?? image.title,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) =>
              wasSynchronouslyLoaded || frame != null
              ? child
              : const Center(
                  child: Icon(Icons.image_outlined, color: SodamStyle.muted),
                ),
          errorBuilder: (_, _, _) => const Center(
            child: Icon(
              Icons.broken_image_outlined,
              color: SodamStyle.muted,
              semanticLabel: '이미지를 불러올 수 없어요.',
            ),
          ),
        ),
      );
}
