import 'package:flutter/material.dart';

import '../login/customer_auth_widgets.dart';

// 업로드 순서와 파일명을 명시해 OS의 파일 정렬 순서에 영향을 받지 않는다.
final List<String> customerProductImages = List.unmodifiable([
  for (var number = 1; number <= 10; number++) 'images/화면 캡처$number.png',
]);

void showCustomerProductImage(BuildContext context, int index) {
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
                      '상품 이미지 ${index + 1} / ${customerProductImages.length}',
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
            Flexible(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _ProductAsset(index: index),
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
    builder: (context) => SafeArea(
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
                      '상품 이미지 ${customerProductImages.length}개',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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
              child: GridView.builder(
                key: const Key('all-product-images'),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                itemCount: customerProductImages.length,
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 200,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: .85,
                ),
                itemBuilder: (_, index) => _ImageCard(index: index),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class HomeProductGallery extends StatelessWidget {
  const HomeProductGallery({super.key});

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 200,
    child: ListView.separated(
      key: const Key('home-product-images'),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      scrollDirection: Axis.horizontal,
      itemCount: customerProductImages.length,
      separatorBuilder: (_, _) => const SizedBox(width: 14),
      itemBuilder: (_, index) =>
          SizedBox(width: 168, child: _ImageCard(index: index)),
    ),
  );
}

class _ImageCard extends StatelessWidget {
  const _ImageCard({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFFF5F5F5),
    borderRadius: BorderRadius.circular(14),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      key: ValueKey('uploaded-product-${index + 1}'),
      onTap: () => showCustomerProductImage(context, index),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: _ProductAsset(index: index),
          ),
          Positioned(
            right: 8,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: SodamStyle.background.withValues(alpha: .9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${index + 1} / ${customerProductImages.length}',
                style: const TextStyle(fontSize: 9, color: SodamStyle.green),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ProductAsset extends StatelessWidget {
  const _ProductAsset({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) => Image.asset(
    customerProductImages[index],
    fit: BoxFit.contain,
    semanticLabel: '상품 이미지 ${index + 1}',
    errorBuilder: (_, _, _) => const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image_outlined, color: SodamStyle.muted),
          SizedBox(height: 8),
          Text(
            '이미지를 불러올 수 없어요.',
            style: TextStyle(fontSize: 11, color: SodamStyle.muted),
          ),
        ],
      ),
    ),
  );
}
