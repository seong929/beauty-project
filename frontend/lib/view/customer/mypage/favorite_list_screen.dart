import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beauty_project/vm/customer/product_handler.dart';
import 'package:beauty_project/vm/customer/product_search_handler.dart';
import '../login/customer_auth_widgets.dart';
import '../product/product_list.dart';
import '../product/product_widgets.dart';
import 'favorite_product_card.dart';

class CustomerFavoriteListScreen extends ConsumerStatefulWidget {
  const CustomerFavoriteListScreen({super.key});

  @override
  ConsumerState<CustomerFavoriteListScreen> createState() =>
      _CustomerFavoriteListScreenState();
}

class _CustomerFavoriteListScreenState
    extends ConsumerState<CustomerFavoriteListScreen> {
  int _page = 0;
  int _pageSize = 10;
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _changePage(int page) {
    setState(() => _page = page);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(favoriteProductEntriesProvider);
    final catalog = ref.watch(homeCatalogProductsProvider);
    final pages = entries.isEmpty ? 1 : (entries.length / _pageSize).ceil();
    final page = _page.clamp(0, pages - 1);
    final start = page * _pageSize;
    final visible = entries.skip(start).take(_pageSize).toList();
    return Scaffold(
      key: const Key('customer-favorites'),
      appBar: AppBar(
        title: const Text('찜한 상품'),
        actions: [
          TextButton(
            onPressed: () => showCustomerPreviewCart(context),
            child: const Text('장바구니'),
          ),
        ],
      ),
      bottomNavigationBar: ProductNavigation(
        selectedIndex: 3,
        onSearch: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CustomerProductListScreen()),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: RefreshIndicator(
            onRefresh: () async {
              await ref.read(productHandlerProvider.notifier).refreshProducts();
            },
            child: ListView(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      '찜한 상품',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${entries.length}개',
                      key: const Key('favorite-count'),
                      style: const TextStyle(
                        fontSize: 12,
                        color: SodamStyle.muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEFAFB),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '품절·판매 중단 상품도 목록에 보관됩니다. 현재 판매 상태를 확인해 주세요.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.8,
                      color: SodamStyle.muted,
                    ),
                  ),
                ),
                if (catalog.isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: LinearProgressIndicator(),
                  ),
                if (catalog.hasError)
                  Column(
                    children: [
                      const Text(
                        '판매 정보를 불러오지 못했습니다. 찜 목록은 유지됩니다.',
                        style: TextStyle(fontSize: 12),
                      ),
                      TextButton(
                        onPressed: () => ref.invalidate(productHandlerProvider),
                        child: const Text('다시 조회'),
                      ),
                    ],
                  ),
                const SizedBox(height: 16),
                if (entries.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 60),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.favorite_border,
                          size: 38,
                          color: SodamStyle.muted,
                        ),
                        const SizedBox(height: 16),
                        const Text('찜한 상품이 없습니다.'),
                        const SizedBox(height: 16),
                        OutlinedButton(
                          onPressed: () {
                            ref.read(productFilterProvider.notifier).reset();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    const CustomerProductListScreen(),
                              ),
                            );
                          },
                          child: const Text('상품 보러가기'),
                        ),
                      ],
                    ),
                  )
                else
                  LayoutBuilder(
                    builder: (_, constraints) => Wrap(
                      spacing: 14,
                      runSpacing: 24,
                      children: [
                        for (final entry in visible)
                          SizedBox(
                            width: (constraints.maxWidth - 14) / 2,
                            child: FavoriteProductCard(entry: entry),
                          ),
                      ],
                    ),
                  ),
                if (entries.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '총 ${entries.length}건 · ${start + 1}–${start + visible.length}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: SodamStyle.muted,
                          ),
                        ),
                      ),
                      const Text(
                        '페이지당',
                        style: TextStyle(fontSize: 10, color: SodamStyle.muted),
                      ),
                      const SizedBox(width: 8),
                      DropdownButton<int>(
                        key: const Key('favorite-page-size'),
                        value: _pageSize,
                        items: [
                          for (final size in [10, 20, 30])
                            DropdownMenuItem(
                              value: size,
                              child: Text(
                                '$size개',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _pageSize = value;
                              _page = 0;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        key: const Key('favorite-previous-page'),
                        tooltip: '이전 페이지',
                        onPressed: page > 0
                            ? () => _changePage(page - 1)
                            : null,
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Text(
                        '${page + 1} / $pages',
                        style: const TextStyle(fontSize: 12),
                      ),
                      IconButton(
                        key: const Key('favorite-next-page'),
                        tooltip: '다음 페이지',
                        onPressed: page < pages - 1
                            ? () => _changePage(page + 1)
                            : null,
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
