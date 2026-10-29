class CustomerReview {
  const CustomerReview({
    required this.id,
    required this.customerId,
    required this.productId,
    required this.customerName,
    required this.productName,
    required this.content,
    required this.rating,
    this.reviewedAt,
  });
  final String id;
  final String customerId;
  final String productId;
  final String customerName;
  final String productName;
  final String content;
  final int rating;
  final DateTime? reviewedAt;

  factory CustomerReview.fromJson(Map<String, dynamic> json) {
    final rating = int.tryParse(json['rating']?.toString() ?? '');
    if (rating == null ||
        rating < 1 ||
        rating > 5 ||
        ['review_id', 'customer_id', 'cosmetic_id', 'review_content'].any(
          (field) =>
              json[field] is! String || (json[field] as String).trim().isEmpty,
        )) {
      throw const FormatException('리뷰 응답 오류');
    }
    return CustomerReview(
      id: json['review_id'],
      customerId: json['customer_id'],
      productId: json['cosmetic_id'],
      customerName: json['customer_name']?.toString() ?? '구매 고객',
      productName: json['cosmetic_name']?.toString() ?? '구매 상품',
      content: json['review_content'],
      rating: rating,
      reviewedAt: DateTime.tryParse(json['reviewed_at']?.toString() ?? ''),
    );
  }

  String get publicName {
    final letters = customerName.runes.toList();
    if (letters.length < 2) return '*';
    return '${String.fromCharCode(letters.first)}**${String.fromCharCode(letters.last)}';
  }
}

class ReviewStatistics {
  ReviewStatistics(List<CustomerReview> reviews)
    : count = reviews.length,
      average = reviews.isEmpty
          ? 0
          : reviews.fold<int>(0, (sum, review) => sum + review.rating) /
                reviews.length,
      counts = Map.unmodifiable({
        for (var score = 1; score <= 5; score++)
          score: reviews.where((review) => review.rating == score).length,
      });
  final int count;
  final double average;
  final Map<int, int> counts;
  String get averageLabel => count == 0 ? '—' : average.toStringAsFixed(1);
}
