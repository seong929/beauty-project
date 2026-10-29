import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beauty_project/model/customer/review.dart';
import 'package:beauty_project/vm/customer/review_handler.dart';
import '../login/customer_auth_widgets.dart';
import '../order/order_summary.dart';

class ReviewStars extends StatelessWidget {
  const ReviewStars({super.key, required this.rating, this.size = 17});
  final double rating;
  final double size;
  @override
  Widget build(BuildContext context) => Semantics(
    label: rating == 0
        ? '등록된 별점 없음'
        : '별점 ${rating.toStringAsFixed(1)}점, 5점 만점',
    child: ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 5; i++)
            Icon(
              rating >= i + 1
                  ? Icons.star
                  : rating >= i + 0.5
                  ? Icons.star_half
                  : Icons.star_border,
              color: const Color(0xFFD9A441),
              size: size,
            ),
        ],
      ),
    ),
  );
}

class ReviewStatisticsPanel extends StatelessWidget {
  const ReviewStatisticsPanel({super.key, required this.reviews});
  final List<CustomerReview> reviews;
  @override
  Widget build(BuildContext context) {
    final stats = ReviewStatistics(reviews);
    return Container(
      key: const Key('review-statistics'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F7F8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            child: Column(
              children: [
                Text(
                  stats.averageLabel,
                  key: const Key('review-average'),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                ReviewStars(rating: stats.average, size: 15),
                const SizedBox(height: 6),
                Text(
                  '${stats.count}개의 리뷰',
                  style: const TextStyle(fontSize: 11, color: SodamStyle.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              children: [
                for (var score = 5; score >= 1; score--)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 28,
                          child: Text(
                            '$score점',
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                        Expanded(
                          child: LinearProgressIndicator(
                            value: stats.count == 0
                                ? 0
                                : stats.counts[score]! / stats.count,
                            minHeight: 5,
                            backgroundColor: const Color(0xFFEBEDF0),
                            color: const Color(0xFFD9A441),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 9),
                        SizedBox(
                          width: 26,
                          child: Text(
                            '${stats.counts[score]}',
                            key: Key('review-score-count-$score'),
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontSize: 10,
                              color: SodamStyle.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CustomerReviewCard extends StatelessWidget {
  const CustomerReviewCard({
    super.key,
    required this.review,
    this.mine = false,
    this.showProduct = false,
    this.onEdit,
    this.onDelete,
    this.busy = false,
  });
  final CustomerReview review;
  final bool mine;
  final bool showProduct;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool busy;
  @override
  Widget build(BuildContext context) => Container(
    key: Key('review-card-${review.id}'),
    padding: const EdgeInsets.symmetric(vertical: 18),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: SodamStyle.border)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showProduct) ...[
          Text(
            review.productName,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 9),
        ],
        Row(
          children: [
            ReviewStars(rating: review.rating.toDouble()),
            const Spacer(),
            Text(
              mine ? '내 리뷰' : review.publicName,
              style: const TextStyle(fontSize: 11, color: SodamStyle.muted),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          orderDateText(review.reviewedAt),
          style: const TextStyle(fontSize: 10, color: SodamStyle.muted),
        ),
        const SizedBox(height: 12),
        Text(review.content, style: const TextStyle(fontSize: 13, height: 1.8)),
        if (mine)
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              children: [
                TextButton(
                  key: Key('review-edit-${review.id}'),
                  onPressed: busy ? null : onEdit,
                  child: const Text('수정'),
                ),
                TextButton(
                  key: Key('review-delete-${review.id}'),
                  onPressed: busy ? null : onDelete,
                  child: const Text(
                    '삭제',
                    style: TextStyle(color: Color(0xFFAE6762)),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

Future<void> confirmDeleteReview(
  BuildContext context,
  WidgetRef ref,
  CustomerReview review,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('리뷰 삭제'),
      content: const Text('이 리뷰와 별점을 삭제하시겠어요?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('취소'),
        ),
        TextButton(
          key: const Key('confirm-review-delete'),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('삭제'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  final deleted = await ref
      .read(reviewMutationProvider.notifier)
      .delete(review);
  if (!context.mounted || !messenger.mounted) return;
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        deleted
            ? '리뷰를 삭제했습니다.'
            : ref.read(reviewMutationProvider).error?.toString() ??
                  '리뷰 요청을 처리 중입니다.',
      ),
    ),
  );
}
