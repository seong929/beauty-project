import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:beauty_project/model/customer/review.dart';
import 'customer_auth_service.dart';

class CustomerReviewService {
  const CustomerReviewService({required this.client, required this.baseUrl});
  final http.Client client;
  final Uri baseUrl;

  // 기존 전체 리뷰 조회를 한 번만 요청해 상품별 별점을 집계한다.
  Future<Map<String, ReviewStatistics>> fetchProductRatings() async {
    final data = await _request(
      () => client.get(baseUrl.resolve('reviews_select')),
    );
    try {
      final rows = data['result'];
      if (rows is! List) throw const FormatException();
      final grouped = <String, List<CustomerReview>>{};
      for (final row in rows) {
        if (row is! Map<String, dynamic>) throw const FormatException();
        final review = CustomerReview.fromJson(row);
        (grouped[review.productId] ??= []).add(review);
      }
      return Map.unmodifiable({
        for (final entry in grouped.entries)
          entry.key: ReviewStatistics(entry.value),
      });
    } on FormatException {
      throw const CustomerAuthException('상품 별점을 확인할 수 없습니다. 다시 조회해 주세요.');
    }
  }

  Future<List<CustomerReview>> fetch({
    String? customerId,
    String? productId,
  }) async {
    if (customerId == null && productId == null) {
      throw const CustomerAuthException('리뷰 조회 조건을 확인해 주세요.');
    }
    final data = await _request(
      () => client.get(
        baseUrl
            .resolve('reviews_select')
            .replace(
              queryParameters: {
                'customer_id': ?customerId,
                'cosmetic_id': ?productId,
              },
            ),
      ),
    );
    try {
      final rows = data['result'];
      if (rows is! List) throw const FormatException();
      final reviews = <CustomerReview>[];
      for (final row in rows) {
        if (row is! Map<String, dynamic>) throw const FormatException();
        final review = CustomerReview.fromJson(row);
        if ((customerId != null && review.customerId != customerId) ||
            (productId != null && review.productId != productId)) {
          throw const FormatException();
        }
        reviews.add(review);
      }
      return List.unmodifiable(reviews);
    } on FormatException {
      throw const CustomerAuthException('리뷰 응답을 확인할 수 없습니다.');
    }
  }

  Future<Set<String>> eligibleProducts(String customerId) async {
    final data = await _request(
      () => client.get(
        baseUrl
            .resolve('reviews_eligibility')
            .replace(queryParameters: {'customer_id': customerId}),
      ),
    );
    final rows = data['result'];
    if (rows is! List ||
        rows.any(
          (row) =>
              row is! Map ||
              row['cosmetic_id'] is! String ||
              (row['cosmetic_id'] as String).isEmpty,
        )) {
      throw const CustomerAuthException('리뷰 작성 가능 상품을 확인할 수 없습니다.');
    }
    return {for (final row in rows) row['cosmetic_id'] as String};
  }

  Future<void> save({
    required String customerId,
    required String productId,
    required String content,
    required int rating,
    String? reviewId,
  }) async {
    if (customerId.isEmpty ||
        productId.isEmpty ||
        productId.startsWith('preview_') ||
        content.trim().isEmpty ||
        content.trim().runes.length > 2000 ||
        rating < 1 ||
        rating > 5) {
      throw const CustomerAuthException('리뷰 내용과 1~5점의 별점을 입력해 주세요.');
    }
    final form = {
      'customer_id': customerId,
      'review_content': content.trim(),
      'rating': '$rating',
      if (reviewId == null) 'cosmetic_id': productId else 'review_id': reviewId,
    };
    final data = await _request(
      () => reviewId == null
          ? client.post(baseUrl.resolve('reviews_upload'), body: form)
          : client.put(baseUrl.resolve('reviews_update'), body: form),
      mutation: true,
    );
    if (data['result'] != 'OK' ||
        data['customer_id'] != customerId ||
        data['cosmetic_id'] != productId ||
        data['review_id'] is! String ||
        (data['review_id'] as String).isEmpty ||
        (reviewId != null && data['review_id'] != reviewId)) {
      throw const CustomerAuthException(
        '리뷰 저장 결과를 확인하지 못했습니다. 리뷰 목록을 다시 조회해 주세요.',
      );
    }
  }

  Future<void> delete(CustomerReview review, String customerId) async {
    if (customerId != review.customerId) {
      throw const CustomerAuthException('작성자만 리뷰를 삭제할 수 있습니다.');
    }
    final data = await _request(
      () => client.delete(
        baseUrl.resolve('reviews_delete'),
        body: {'customer_id': customerId, 'review_id': review.id},
      ),
      mutation: true,
    );
    if (data['result'] != 'OK' ||
        data['review_id'] != review.id ||
        data['customer_id'] != customerId ||
        data['cosmetic_id'] != review.productId ||
        data['deleted_count'] != 1) {
      throw const CustomerAuthException('리뷰 삭제 결과를 확인하지 못했습니다. 다시 조회해 주세요.');
    }
  }

  Future<Map<String, dynamic>> _request(
    Future<http.Response> Function() send, {
    bool mutation = false,
  }) async {
    try {
      final response = await send().timeout(const Duration(seconds: 15));
      if (response.statusCode >= 500) {
        throw const CustomerAuthException('리뷰 서버에 연결하지 못했습니다. 목록을 다시 조회해 주세요.');
      }
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data is! Map<String, dynamic>) throw const FormatException();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw CustomerAuthException(
          data['detail'] is String
              ? data['detail'] as String
              : '리뷰 요청을 처리하지 못했습니다.',
        );
      }
      return data;
    } on TimeoutException {
      throw CustomerAuthException(
        mutation
            ? '리뷰 처리 결과를 확인하지 못했습니다. 목록을 다시 조회해 주세요.'
            : '리뷰 조회 시간이 초과되었습니다.',
      );
    } on http.ClientException {
      throw const CustomerAuthException('네트워크 연결을 확인하고 리뷰를 다시 조회해 주세요.');
    } on FormatException {
      throw const CustomerAuthException('리뷰 응답을 확인할 수 없습니다.');
    }
  }
}
