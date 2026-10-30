import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beauty_project/model/customer/storage_image.dart';
import 'package:beauty_project/vm/customer/storage_image_handler.dart';
import '../login/customer_auth_widgets.dart';
import 'storage_product_image.dart';

void showCustomerProductImage(
  BuildContext context,
  CustomerStorageImage image,
  int index,
  int total,
) {
  showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 4, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '상품 이미지 ${index + 1} / $total',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  IconButton(
                    tooltip: '이미지 닫기',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                image.title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12),
              ),
            ),
            Flexible(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: CustomerStoragePhoto(image: image),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

void showAllCustomerProductImages(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => const _AllProductImages(),
  );
}

class _GalleryState extends ConsumerWidget {
  const _GalleryState({required this.value, required this.onData});
  final AsyncValue<List<CustomerStorageImage>> value;
  final Widget Function(List<CustomerStorageImage>) onData;
  @override
  Widget build(BuildContext context, WidgetRef ref) => value.when(
    skipLoadingOnRefresh: false,
    loading: () => const Center(child: CircularProgressIndicator()),
    error: (error, _) => Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: SodamStyle.muted),
            ),
          ),
          TextButton(
            key: const Key('retry-storage-images'),
            onPressed: () => ref.invalidate(customerStorageImagesProvider),
            child: const Text('이미지 다시 불러오기'),
          ),
        ],
      ),
    ),
    data: (images) => images.isEmpty
        ? const Center(
            child: Text(
              '아직 등록된 상품 이미지가 없어요.',
              style: TextStyle(fontSize: 12, color: SodamStyle.muted),
            ),
          )
        : onData(images),
  );
}

class _AllProductImages extends ConsumerWidget {
  const _AllProductImages();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final images = ref.watch(customerStorageImagesProvider);
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .8,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      images.hasValue
                          ? '상품 이미지 ${images.value!.length}개'
                          : '상품 이미지',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '이미지 새로고침',
                    onPressed: () =>
                        ref.invalidate(customerStorageImagesProvider),
                    icon: const Icon(Icons.refresh),
                  ),
                  IconButton(
                    tooltip: '전체 이미지 닫기',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _GalleryState(
                value: images,
                onData: (entries) => GridView.builder(
                  key: const Key('all-product-images'),
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  itemCount: entries.length,
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 200,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: .85,
                  ),
                  itemBuilder: (_, index) => _ImageCard(
                    image: entries[index],
                    index: index,
                    total: entries.length,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeProductGallery extends ConsumerWidget {
  const HomeProductGallery({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => SizedBox(
    height: 200,
    child: _GalleryState(
      value: ref.watch(customerStorageImagesProvider),
      onData: (images) => ListView.separated(
        key: const Key('home-product-images'),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: images.length.clamp(0, 10),
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (_, index) => SizedBox(
          width: 168,
          child: _ImageCard(
            image: images[index],
            index: index,
            total: images.length,
          ),
        ),
      ),
    ),
  );
}

class _ImageCard extends StatelessWidget {
  const _ImageCard({
    required this.image,
    required this.index,
    required this.total,
  });
  final CustomerStorageImage image;
  final int index;
  final int total;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(10),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      key: ValueKey('uploaded-product-${index + 1}'),
      onTap: () => showCustomerProductImage(context, image, index, total),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: CustomerStoragePhoto(image: image)),
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    image.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 9,
                      color: SodamStyle.muted,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '${index + 1} / $total',
                  style: const TextStyle(fontSize: 9, color: SodamStyle.green),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
