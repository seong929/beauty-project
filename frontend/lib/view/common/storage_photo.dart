import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../model/common/storage_image.dart';

final storageImageLoaderProvider =
    Provider<ImageProvider<Object> Function(String)>(
      (ref) =>
          (url) => NetworkImage(
            url,
            // 공개 Firebase 파일은 바이트 조회용 CORS 헤더가 없을 수 있다.
            // 웹에서는 이 경우 HTML 이미지로 표시하고 앱에서는 기존 로더를 쓴다.
            webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
          ),
    );

class ProductImageFrame extends StatelessWidget {
  const ProductImageFrame({super.key, required this.child});
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

class StoragePhoto extends ConsumerWidget {
  const StoragePhoto({super.key, required this.image, this.label});
  final StorageImage image;
  final String? label;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ProductImageFrame(
    child: Image(
      key: ValueKey(image.downloadUri.toString()),
      image: ref.watch(storageImageLoaderProvider)(
        image.downloadUri.toString(),
      ),
      fit: BoxFit.contain,
      semanticLabel: label ?? image.title,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) =>
          wasSynchronouslyLoaded || frame != null
          ? child
          : const Center(
              child: Icon(Icons.image_outlined, color: Color(0xFF8B9096)),
            ),
      errorBuilder: (_, _, _) => const Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: Color(0xFF8B9096),
          semanticLabel: '이미지를 불러올 수 없어요.',
        ),
      ),
    ),
  );
}
