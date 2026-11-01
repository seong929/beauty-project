// 기능: 작성한 리뷰와 작성 가능한 배송 완료 상품 탭.
// 표시 계층: ref.watch로 상태를 구독하고 사용자 동작은 Notifier·서비스에 전달한다.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beauty_project/vm/customer/state/customer_screen_handler.dart';
import 'package:beauty_project/model/customer/order.dart';
import 'package:beauty_project/vm/customer/customer_handler.dart';
import 'package:beauty_project/vm/customer/order_handler.dart';
import 'package:beauty_project/vm/customer/review_handler.dart';
import '../order/order_history_widgets.dart';
import '../product/product_list.dart';
import '../product/product_widgets.dart';
import 'review_editor_screen.dart';
import 'review_widgets.dart';

class CustomerReviewListScreen extends ConsumerStatefulWidget {
  const CustomerReviewListScreen({super.key});
  @override
  ConsumerState<CustomerReviewListScreen> createState() =>
      _CustomerReviewListScreenState();
}

class _CustomerReviewListScreenState
    extends ConsumerState<CustomerReviewListScreen> {
  late final _tabProvider = customerReviewTabProvider(this);
  bool get _writable => ref.read(_tabProvider).value;

  /// Function: 관련 Provider를 무효화해 최신 서버 상태를 다시 조회한다.
  void _refresh() {
    ref.invalidate(customerReviewsProvider);
    ref.invalidate(eligibleReviewProductsProvider);
    ref.invalidate(customerOrdersProvider);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(_tabProvider);
    final customerId = ref.watch(customerHandlerProvider).value?.customerId;
    final reviews = ref.watch(customerReviewsProvider);
    final busy = ref.watch(reviewMutationProvider).isLoading;
    return Scaffold(
      key: const Key('customer-review-list'),
      appBar: AppBar(
        title: const Text('리뷰 내역'),
        actions: [
          IconButton(
            onPressed: _refresh,
            tooltip: '다시 조회',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      bottomNavigationBar: ProductNavigation(
        selectedIndex: 3,
        onSearch: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CustomerProductListScreen()),
        ),
      ),
      body: customerId == null
          ? const Center(child: Text('로그인 후 리뷰 내역을 확인해 주세요.'))
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: ChoiceChip(
                              key: const Key('review-tab-mine'),
                              label: const Text('내 리뷰'),
                              selected: !_writable,
                              onSelected: (_) =>
                                  ref.read(_tabProvider.notifier).select(false),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ChoiceChip(
                              key: const Key('review-tab-writable'),
                              label: const Text('작성 가능한 상품'),
                              selected: _writable,
                              onSelected: (_) =>
                                  ref.read(_tabProvider.notifier).select(true),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: reviews.when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (error, _) => Center(
                          child: OrderLoadError(
                            error: error,
                            onRetry: _refresh,
                          ),
                        ),
                        data: (items) {
                          if (!_writable) {
                            return items.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text('작성한 리뷰가 없습니다.'),
                                        TextButton(
                                          onPressed: () => ref
                                              .read(_tabProvider.notifier)
                                              .select(true),
                                          child: const Text('배송 완료 상품 리뷰 작성'),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView(
                                    padding: const EdgeInsets.fromLTRB(
                                      22,
                                      0,
                                      22,
                                      24,
                                    ),
                                    children: [
                                      for (final review in items)
                                        CustomerReviewCard(
                                          review: review,
                                          mine: true,
                                          showProduct: true,
                                          busy: busy,
                                          onEdit: () =>
                                              Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      CustomerReviewEditorScreen(
                                                        productId:
                                                            review.productId,
                                                        productName:
                                                            review.productName,
                                                        review: review,
                                                      ),
                                                ),
                                              ),
                                          onDelete: () => confirmDeleteReview(
                                            context,
                                            ref,
                                            review,
                                          ),
                                        ),
                                    ],
                                  );
                          }
                          final eligible = ref.watch(
                            eligibleReviewProductsProvider,
                          );
                          final orders = ref.watch(customerOrdersProvider);
                          if (eligible.isLoading || orders.isLoading) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          if (eligible.hasError || orders.hasError) {
                            return Center(
                              child: OrderLoadError(
                                error: eligible.error ?? orders.error!,
                                onRetry: _refresh,
                              ),
                            );
                          }
                          final written = items
                              .map((review) => review.productId)
                              .toSet();
                          final available = <String, CustomerOrderLine>{};
                          for (final order in orders.value ?? []) {
                            for (final item in order.items) {
                              if (eligible.value?.contains(item.productId) ==
                                      true &&
                                  !written.contains(item.productId)) {
                                available.putIfAbsent(
                                  item.productId,
                                  () => item,
                                );
                              }
                            }
                          }
                          if (available.isEmpty) {
                            return const Center(
                              child: Text('현재 리뷰를 작성할 수 있는 상품이 없습니다.'),
                            );
                          }
                          return ListView(
                            padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
                            children: [
                              for (final item in available.values)
                                Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        OrderProductInformation(item: item),
                                        OutlinedButton(
                                          key: Key(
                                            'write-purchased-review-${item.productId}',
                                          ),
                                          onPressed: () =>
                                              Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      CustomerReviewEditorScreen(
                                                        productId:
                                                            item.productId,
                                                        productName: item.name,
                                                      ),
                                                ),
                                              ),
                                          child: const Text('리뷰 작성'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
