import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beauty_project/model/customer/home_product.dart';
import 'package:beauty_project/model/customer/review.dart';
import 'package:beauty_project/vm/customer/customer_handler.dart';
import 'package:beauty_project/vm/customer/review_handler.dart';
import '../login/customer_auth_widgets.dart';
import '../order/order_history_widgets.dart';
import 'review_editor_screen.dart';
import 'review_widgets.dart';

class ProductReviewRatingLine extends ConsumerWidget {
  const ProductReviewRatingLine({
    super.key,
    required this.product,
    required this.onTap,
  });
  final HomeProduct product;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!product.isDatabaseProduct) return const SizedBox.shrink();
    final response = ref.watch(productReviewsProvider(product.id));
    return InkWell(
      key: const Key('product-rating-link'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: response.when(
          loading: () => const Text(
            '별점 확인 중…',
            style: TextStyle(fontSize: 12, color: SodamStyle.muted),
          ),
          error: (_, _) => const Text(
            '리뷰 · 별점 다시 조회',
            style: TextStyle(fontSize: 12, color: SodamStyle.muted),
          ),
          data: (reviews) {
            final stats = ReviewStatistics(reviews);
            return Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ReviewStars(rating: stats.average),
                Text(
                  stats.count == 0
                      ? '아직 등록된 리뷰가 없어요.'
                      : '${stats.averageLabel} · 리뷰 ${stats.count}개',
                  style: const TextStyle(fontSize: 12, color: SodamStyle.muted),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class ProductReviewsSection extends ConsumerStatefulWidget {
  const ProductReviewsSection({super.key, required this.product});
  final HomeProduct product;
  @override
  ConsumerState<ProductReviewsSection> createState() =>
      _ProductReviewsSectionState();
}

class _ProductReviewsSectionState extends ConsumerState<ProductReviewsSection> {
  int _visible = 5;
  void _refresh() {
    ref.invalidate(productReviewsProvider(widget.product.id));
    ref.invalidate(catalogProductRatingsProvider);
    ref.invalidate(eligibleReviewProductsProvider);
  }

  void _edit([CustomerReview? review]) => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => CustomerReviewEditorScreen(
        productId: widget.product.id,
        productName: widget.product.name,
        review: review,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    if (!product.isDatabaseProduct) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Text(
          '예시 상품에는 등록된 리뷰가 없습니다.',
          style: TextStyle(fontSize: 12, color: SodamStyle.muted),
        ),
      );
    }
    final response = ref.watch(productReviewsProvider(product.id));
    final customerId = ref.watch(customerHandlerProvider).value?.customerId;
    final eligibility = ref.watch(eligibleReviewProductsProvider);
    final mine = response.value
        ?.where((review) => review.customerId == customerId)
        .firstOrNull;
    final busy = ref.watch(reviewMutationProvider).isLoading;
    final canWrite =
        !busy &&
        customerId != null &&
        !response.isLoading &&
        !response.hasError &&
        (mine != null || eligibility.value?.contains(product.id) == true);
    return Column(
      key: const Key('product-review-section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 32),
        Row(
          children: [
            const Expanded(
              child: Text(
                '상품 리뷰',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              key: const Key('product-reviews-refresh'),
              tooltip: '리뷰 새로고침',
              onPressed: _refresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          key: const Key('product-write-review'),
          onPressed: canWrite ? () => _edit(mine) : null,
          icon: const Icon(Icons.rate_review_outlined, size: 18),
          label: Text(mine == null ? '리뷰 작성' : '내 리뷰 수정'),
        ),
        if (customerId == null)
          const Text(
            '로그인 후 배송 완료 상품의 리뷰를 작성할 수 있습니다.',
            style: TextStyle(fontSize: 11, color: SodamStyle.muted),
          )
        else if (mine == null &&
            !eligibility.isLoading &&
            eligibility.value?.contains(product.id) != true)
          const Text(
            '배송 완료된 구매 상품만 리뷰를 작성할 수 있습니다.',
            style: TextStyle(fontSize: 11, color: SodamStyle.muted),
          ),
        if (eligibility.hasError)
          TextButton(
            onPressed: () => ref.invalidate(eligibleReviewProductsProvider),
            child: const Text('작성 가능 여부 다시 조회'),
          ),
        const SizedBox(height: 14),
        response.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, _) => OrderLoadError(error: error, onRetry: _refresh),
          data: (reviews) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ReviewStatisticsPanel(reviews: reviews),
              if (reviews.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Text(
                    '등록된 리뷰가 없습니다.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: SodamStyle.muted),
                  ),
                ),
              for (final review in reviews.take(_visible))
                CustomerReviewCard(
                  review: review,
                  mine: review.customerId == customerId,
                  busy: busy,
                  onEdit: () => _edit(review),
                  onDelete: () => confirmDeleteReview(context, ref, review),
                ),
              if (reviews.length > _visible)
                TextButton(
                  key: const Key('product-more-reviews'),
                  onPressed: () => setState(() => _visible += 5),
                  child: Text('리뷰 더 보기 (${reviews.length - _visible}개)'),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class OrderReviewAction extends ConsumerWidget {
  const OrderReviewAction({
    super.key,
    required this.productId,
    required this.productName,
  });
  final String productId;
  final String productName;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mine = ref.watch(customerReviewsProvider);
    final eligible = ref.watch(eligibleReviewProductsProvider);
    final existing = mine.value
        ?.where((entry) => entry.productId == productId)
        .firstOrNull;
    final ready =
        existing != null || eligible.value?.contains(productId) == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          key: const Key('order-detail-review'),
          icon: const Icon(Icons.rate_review_outlined, size: 18),
          onPressed: ready && !mine.isLoading && !mine.hasError
              ? () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CustomerReviewEditorScreen(
                      productId: productId,
                      productName: productName,
                      review: existing,
                    ),
                  ),
                )
              : null,
          label: Text(existing != null ? '내 리뷰 수정' : '배송 완료 후 리뷰 작성'),
        ),
        if (eligible.hasError || mine.hasError || !ready)
          TextButton(
            onPressed: () {
              ref.invalidate(eligibleReviewProductsProvider);
              ref.invalidate(customerReviewsProvider);
            },
            child: const Text('리뷰 작성 가능 여부 새로고침'),
          ),
      ],
    );
  }
}
