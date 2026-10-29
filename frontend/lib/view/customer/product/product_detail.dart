import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beauty_project/model/customer/home_product.dart';
import 'package:beauty_project/vm/customer/cart_handler.dart';
import 'package:beauty_project/vm/customer/cart_persistence_handler.dart';
import '../login/customer_auth_widgets.dart';
import '../order/check_screen.dart';
import '../review/product_reviews_section.dart';
import 'product_list.dart';
import 'product_widgets.dart';

class CustomerProductDetailScreen extends ConsumerStatefulWidget {
  const CustomerProductDetailScreen({
    super.key,
    required this.product,
    this.option,
    this.fromSearch = false,
  });
  final HomeProduct product;
  final HomeProductOption? option;
  final bool fromSearch;
  @override
  ConsumerState<CustomerProductDetailScreen> createState() =>
      _CustomerProductDetailScreenState();
}

class _CustomerProductDetailScreenState
    extends ConsumerState<CustomerProductDetailScreen> {
  int _quantity = 1;
  bool _saving = false;
  final _reviewsKey = GlobalKey();

  void _search() {
    if (widget.fromSearch) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const CustomerProductListScreen()),
      );
    }
  }

  Future<void> _addToCart({bool checkout = false}) async {
    if (_saving || ref.read(cartPersistenceProvider).isLoading) return;
    final product = widget.product;
    final option = widget.option ?? product.options.first;
    // 상세 화면이 닫힌 후에도 알림의 '보기'가 동작하도록 Navigator를 보관한다.
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      final saved = await ref
          .read(cartPersistenceProvider.notifier)
          .add(product, option, _quantity);
      if (!mounted || !navigator.mounted) return;
      if (!saved) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              ref.read(cartPersistenceProvider).error?.toString() ??
                  '장바구니 저장 요청을 처리 중입니다.',
            ),
          ),
        );
        return;
      }
      messenger.hideCurrentSnackBar();
      if (checkout) {
        // 현재 상품만 기존 결제 화면으로 전달한다. 결제는 이곳에서 실행하지 않는다.
        final cart = ref.read(cartHandlerProvider.notifier);
        cart.selectAll(false);
        cart.select('${product.id}:${option.label}', true);
        navigator.push(
          MaterialPageRoute(builder: (_) => const CustomerCheckoutScreen()),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: const Text('장바구니에 담았어요.'),
            action: SnackBarAction(
              label: '보기',
              onPressed: () {
                if (navigator.mounted) {
                  showCustomerPreviewCart(navigator.context);
                }
              },
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final option = widget.option ?? product.options.first;
    final saving = _saving || ref.watch(cartPersistenceProvider).isLoading;
    final enabled = !saving && product.hasKnownPrice;
    return Scaffold(
      key: const Key('product-detail-screen'),
      appBar: AppBar(
        title: const Text('상품 상세', style: TextStyle(fontSize: 13)),
        actions: [
          IconButton(
            key: const Key('product-nav-0'),
            tooltip: '홈',
            onPressed: () =>
                Navigator.of(context).popUntil((route) => route.isFirst),
            icon: const Icon(Icons.home_outlined, size: 21),
          ),
          IconButton(
            key: const Key('product-nav-1'),
            tooltip: '상품 검색',
            onPressed: _search,
            icon: const Icon(Icons.search, size: 21),
          ),
          IconButton(
            key: const Key('product-nav-2'),
            tooltip: '장바구니',
            onPressed: () => showCustomerPreviewCart(context),
            icon: const Icon(Icons.shopping_bag_outlined, size: 21),
          ),
          const SizedBox(width: 6),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: SodamStyle.border)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    border: Border.all(color: SodamStyle.border),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: ProductFavoriteButton(
                    productId: product.id,
                    product: product,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    key: const Key('add-product-to-cart'),
                    onPressed: enabled ? () => _addToCart() : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: SodamStyle.ink,
                      side: const BorderSide(color: SodamStyle.border),
                    ),
                    child: Text(saving ? '저장 중…' : '장바구니'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    key: const Key('buy-product-now'),
                    onPressed: enabled
                        ? () => _addToCart(checkout: true)
                        : null,
                    child: const Text('구매하기'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            key: const Key('product-detail-scroll'),
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) => ProductPhoto(
                    product: product,
                    height: constraints.maxWidth.clamp(240, 380),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  product.brand,
                  style: const TextStyle(fontSize: 12, color: SodamStyle.muted),
                ),
                const SizedBox(height: 6),
                Text(
                  product.name,
                  style: const TextStyle(
                    fontSize: 20,
                    height: 1.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.5,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '용량 ${option.label}',
                  key: const Key('detail-fixed-volume'),
                  style: const TextStyle(fontSize: 12, color: SodamStyle.muted),
                ),
                ProductReviewRatingLine(
                  product: product,
                  onTap: () {
                    final target = _reviewsKey.currentContext;
                    if (target != null) {
                      Scrollable.ensureVisible(
                        target,
                        duration: const Duration(milliseconds: 250),
                      );
                    }
                  },
                ),
                const SizedBox(height: 6),
                Text(
                  product.hasKnownPrice
                      ? productPrice(option.price)
                      : '가격 확인 불가',
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.8,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: SodamStyle.soft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.shopping_bag_outlined,
                        size: 20,
                        color: SodamStyle.green,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          product.isDatabaseProduct
                              ? '현재 등록된 상품 가격과 용량입니다.'
                              : '상품명·가격·옵션은 화면 구성을 위한 예시입니다.',
                          style: const TextStyle(
                            fontSize: 11,
                            height: 1.7,
                            color: SodamStyle.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  '상품 정보',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Text(
                  product.description,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.9,
                    color: SodamStyle.muted,
                  ),
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 12),
                const Text(
                  '수량 선택',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: SodamStyle.field,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          option.label,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      IconButton(
                        key: const Key('quantity-decrease'),
                        tooltip: '수량 줄이기',
                        onPressed: _quantity <= 1 || saving
                            ? null
                            : () => setState(() => _quantity--),
                        icon: const Icon(Icons.remove, size: 18),
                      ),
                      Text('$_quantity', key: const Key('product-quantity')),
                      IconButton(
                        key: const Key('quantity-increase'),
                        tooltip: '수량 늘리기',
                        onPressed: _quantity >= 99 || saving
                            ? null
                            : () => setState(() => _quantity++),
                        icon: const Icon(Icons.add, size: 18),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Expanded(
                      child: Text('합계', style: TextStyle(fontSize: 13)),
                    ),
                    Text(
                      product.hasKnownPrice
                          ? productPrice(option.price * _quantity)
                          : '가격 확인 불가',
                      key: const Key('detail-total'),
                      style: const TextStyle(
                        fontSize: 20,
                        color: SodamStyle.green,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                KeyedSubtree(
                  key: _reviewsKey,
                  child: ProductReviewsSection(product: product),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
