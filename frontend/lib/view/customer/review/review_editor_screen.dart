import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beauty_project/model/customer/review.dart';
import 'package:beauty_project/vm/customer/customer_handler.dart';
import 'package:beauty_project/vm/customer/product_handler.dart';
import 'package:beauty_project/vm/customer/review_handler.dart';
import '../login/customer_auth_widgets.dart';
import '../product/product_widgets.dart';

class CustomerReviewEditorScreen extends ConsumerStatefulWidget {
  const CustomerReviewEditorScreen({
    super.key,
    required this.productId,
    required this.productName,
    this.review,
  });
  final String productId;
  final String productName;
  final CustomerReview? review;
  @override
  ConsumerState<CustomerReviewEditorScreen> createState() =>
      _CustomerReviewEditorScreenState();
}

class _CustomerReviewEditorScreenState
    extends ConsumerState<CustomerReviewEditorScreen> {
  final _form = GlobalKey<FormState>();
  late final _content = TextEditingController(
    text: widget.review?.content ?? '',
  );
  late int _rating = widget.review?.rating ?? 0;
  @override
  void dispose() {
    _content.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate() || _rating < 1 || _rating > 5) return;
    final id = ref.read(customerHandlerProvider).value?.customerId;
    if (id == null ||
        (widget.review != null && widget.review!.customerId != id)) {
      return;
    }
    if (widget.review == null &&
        ref
                .read(eligibleReviewProductsProvider)
                .value
                ?.contains(widget.productId) !=
            true) {
      return;
    }
    final saved = await ref
        .read(reviewMutationProvider.notifier)
        .save(
          productId: widget.productId,
          content: _content.text,
          rating: _rating,
          review: widget.review,
        );
    if (mounted && saved) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final customerId = ref.watch(customerHandlerProvider).value?.customerId;
    final eligibility = widget.review == null
        ? ref.watch(eligibleReviewProductsProvider)
        : null;
    final product = ref
        .watch(homeCatalogProductsProvider)
        .value
        ?.where((entry) => entry.id == widget.productId)
        .firstOrNull;
    final mutation = ref.watch(reviewMutationProvider);
    final allowed =
        customerId != null &&
        (widget.review == null
            ? eligibility?.value?.contains(widget.productId) == true
            : widget.review!.customerId == customerId);
    final busy = mutation.isLoading;
    final canSave =
        allowed && !busy && _rating >= 1 && _content.text.trim().isNotEmpty;
    return PopScope(
      canPop: !busy,
      child: AbsorbPointer(
        absorbing: busy,
        child: Scaffold(
          key: const Key('customer-review-editor'),
          appBar: AppBar(
            title: Text(widget.review == null ? '리뷰 작성' : '리뷰 수정'),
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: ListView(
                padding: const EdgeInsets.all(22),
                children: [
                  if (product != null)
                    Center(
                      child: SizedBox(
                        width: 110,
                        child: ProductPhoto(product: product, height: 120),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    widget.productName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '상품은 어떠셨나요?',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var score = 1; score <= 5; score++)
                        IconButton(
                          key: Key('review-rating-$score'),
                          tooltip: '$score점',
                          onPressed: () => setState(() => _rating = score),
                          icon: Icon(
                            _rating >= score ? Icons.star : Icons.star_border,
                            size: 32,
                            color: const Color(0xFFD9A441),
                          ),
                        ),
                    ],
                  ),
                  Text(
                    _rating == 0 ? '별점을 선택해 주세요.' : '$_rating점',
                    key: const Key('review-selected-rating'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      color: SodamStyle.muted,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Form(
                    key: _form,
                    child: TextFormField(
                      key: const Key('review-content'),
                      controller: _content,
                      minLines: 5,
                      maxLines: 10,
                      maxLength: 2000,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: '리뷰 내용',
                        hintText: '사용해 본 경험을 알려주세요.',
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? '리뷰 내용을 입력해 주세요.'
                          : value.trim().runes.length > 2000
                          ? '리뷰는 2000자 이내로 입력해 주세요.'
                          : null,
                    ),
                  ),
                  if (eligibility?.isLoading == true)
                    const LinearProgressIndicator(),
                  if (!allowed && eligibility?.isLoading != true)
                    const Text(
                      '로그인한 고객의 배송 완료 상품만 리뷰를 작성할 수 있습니다.',
                      style: TextStyle(fontSize: 12, color: SodamStyle.muted),
                    ),
                  if (eligibility?.hasError == true)
                    TextButton(
                      onPressed: () =>
                          ref.invalidate(eligibleReviewProductsProvider),
                      child: const Text('작성 가능 여부 다시 조회'),
                    ),
                  if (mutation.hasError &&
                      ref
                              .read(reviewMutationProvider.notifier)
                              .activeProductId ==
                          widget.productId)
                    Text(
                      mutation.error.toString(),
                      key: const Key('review-save-error'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  const SizedBox(height: 20),
                  FilledButton(
                    key: const Key('review-save'),
                    onPressed: canSave ? _save : null,
                    child: Text(
                      busy
                          ? '저장 중…'
                          : widget.review == null
                          ? '리뷰 등록'
                          : '리뷰 수정 완료',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
