import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beauty_project/model/customer/review.dart';
import 'package:beauty_project/service/customer/customer_auth_service.dart';
import 'package:beauty_project/service/customer/customer_review_service.dart';
import 'customer_handler.dart';
import 'customer_providers.dart';

final customerReviewServiceProvider = Provider<CustomerReviewService>(
  (ref) => CustomerReviewService(
    client: ref.watch(customerHttpClientProvider),
    baseUrl: ref.watch(customerApiBaseUrlProvider),
  ),
);

final productReviewsProvider = FutureProvider.autoDispose
    .family<List<CustomerReview>, String>(
      (ref, productId) =>
          ref.watch(customerReviewServiceProvider).fetch(productId: productId),
      retry: (_, _) => null,
    );

final catalogProductRatingsProvider =
    FutureProvider.autoDispose<Map<String, ReviewStatistics>>(
      (ref) => ref.watch(customerReviewServiceProvider).fetchProductRatings(),
      retry: (_, _) => null,
    );

final customerReviewsProvider = FutureProvider<List<CustomerReview>>((ref) {
  final id = ref.watch(
    customerHandlerProvider.select((session) => session.value?.customerId),
  );
  return id == null
      ? <CustomerReview>[]
      : ref.watch(customerReviewServiceProvider).fetch(customerId: id);
}, retry: (_, _) => null);

final eligibleReviewProductsProvider = FutureProvider<Set<String>>((ref) {
  final id = ref.watch(
    customerHandlerProvider.select((session) => session.value?.customerId),
  );
  return id == null
      ? <String>{}
      : ref.watch(customerReviewServiceProvider).eligibleProducts(id);
}, retry: (_, _) => null);

class ReviewMutationHandler extends AsyncNotifier<void> {
  String? activeProductId;
  @override
  void build() {
    ref.watch(
      customerHandlerProvider.select((session) => session.value?.customerId),
    );
    activeProductId = null;
  }

  Future<bool> save({
    required String productId,
    required String content,
    required int rating,
    CustomerReview? review,
  }) => _run(productId, (service, id) {
    if (review != null &&
        (review.customerId != id || review.productId != productId)) {
      throw const CustomerAuthException('작성자만 리뷰를 수정할 수 있습니다.');
    }
    return service.save(
      customerId: id,
      productId: productId,
      content: content,
      rating: rating,
      reviewId: review?.id,
    );
  });

  Future<bool> delete(CustomerReview review) =>
      _run(review.productId, (service, id) => service.delete(review, id));

  Future<bool> _run(
    String productId,
    Future<void> Function(CustomerReviewService, String) action,
  ) async {
    if (state.isLoading) return false;
    activeProductId = productId;
    final id = ref.read(customerHandlerProvider).value?.customerId;
    if (id == null) {
      state = AsyncError(
        const CustomerAuthException('로그인 후 리뷰를 작성해 주세요.'),
        StackTrace.current,
      );
      return false;
    }
    state = const AsyncLoading();
    try {
      await action(ref.read(customerReviewServiceProvider), id);
      if (!ref.mounted ||
          ref.read(customerHandlerProvider).value?.customerId != id) {
        return false;
      }
      _refresh(productId);
      state = const AsyncData(null);
      return true;
    } catch (error, stack) {
      if (!ref.mounted ||
          ref.read(customerHandlerProvider).value?.customerId != id) {
        return false;
      }
      _refresh(productId);
      state = AsyncError(error, stack);
      return false;
    }
  }

  void _refresh(String productId) {
    ref.invalidate(productReviewsProvider(productId));
    ref.invalidate(customerReviewsProvider);
    ref.invalidate(catalogProductRatingsProvider);
  }
}

final reviewMutationProvider =
    AsyncNotifierProvider<ReviewMutationHandler, void>(
      ReviewMutationHandler.new,
    );
