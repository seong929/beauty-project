import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beauty_project/vm/customer/order_handler.dart';
import '../login/customer_auth_widgets.dart';
import '../product/product_list.dart';
import '../product/product_widgets.dart';
import 'detail_screen.dart';
import 'order_history_widgets.dart';
import 'order_summary.dart';

class CustomerOrderListScreen extends ConsumerStatefulWidget {
  const CustomerOrderListScreen({super.key});

  @override
  ConsumerState<CustomerOrderListScreen> createState() =>
      _CustomerOrderListScreenState();
}

class _CustomerOrderListScreenState
    extends ConsumerState<CustomerOrderListScreen> {
  final _search = TextEditingController();
  String _status = 'ALL';
  static const _statuses = [
    'ALL',
    'PENDING',
    'PAID',
    'PREPARING',
    'SHIPPED',
    'DELIVERED',
    'CANCELLED',
    'RETURNED',
  ];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _filter() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  '구매 내역 필터',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              for (final status in _statuses)
                ListTile(
                  key: Key('order-filter-$status'),
                  title: Text(
                    status == 'ALL' ? '전체' : historyStatusLabel(status),
                  ),
                  trailing: _status == status
                      ? const Icon(Icons.check, color: SodamStyle.green)
                      : null,
                  onTap: () => Navigator.pop(context, status),
                ),
            ],
          ),
        ),
      ),
    );
    if (mounted && selected != null) setState(() => _status = selected);
  }

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(customerOrdersProvider);
    return Scaffold(
      key: const Key('customer-order-list'),
      appBar: AppBar(
        title: const Text('구매 내역 목록'),
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
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const Key('order-history-search'),
                        controller: _search,
                        onChanged: (_) => setState(() {}),
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText: '상품 이름 검색',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          filled: true,
                          fillColor: const Color(0xFFF6F7F8),
                          suffixIcon: _search.text.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: '검색 초기화',
                                  icon: const Icon(Icons.close),
                                  onPressed: () => setState(_search.clear),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton(
                      key: const Key('order-history-filter'),
                      onPressed: _filter,
                      child: Text(
                        _status == 'ALL' ? '필터' : historyStatusLabel(_status),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: orders.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Center(
                    child: OrderLoadError(
                      error: error,
                      onRetry: () => ref.invalidate(customerOrdersProvider),
                    ),
                  ),
                  data: (items) {
                    final query = _search.text.trim().toLowerCase();
                    final filtered = items
                        .where(
                          (order) =>
                              (_status == 'ALL' || order.status == _status) &&
                              (query.isEmpty ||
                                  order.id.toLowerCase().contains(query) ||
                                  order.items.any(
                                    (item) =>
                                        item.name.toLowerCase().contains(query),
                                  )),
                        )
                        .toList();
                    if (filtered.isEmpty) {
                      return Center(
                        child: Text(
                          items.isEmpty
                              ? '구매 내역이 없습니다.'
                              : '조건에 맞는 구매 내역이 없습니다.',
                        ),
                      );
                    }
                    return RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(customerOrdersProvider);
                        await ref.read(customerOrdersProvider.future);
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        itemCount: filtered.length,
                        itemBuilder: (_, index) {
                          final order = filtered[index];
                          final products = order.displayItems;
                          return Container(
                            key: Key('order-${order.id}'),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF6F7F8),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    14,
                                    16,
                                    8,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          orderDateText(order.orderedAt),
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                      Text(
                                        order.id,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: SodamStyle.muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (products.isEmpty)
                                  ListTile(
                                    title: const Text('주문 상세 보기'),
                                    trailing: const Icon(Icons.chevron_right),
                                    onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            CustomerOrderDetailScreen(
                                              order: order,
                                            ),
                                      ),
                                    ),
                                  ),
                                for (final item in products)
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      14,
                                      0,
                                      14,
                                      14,
                                    ),
                                    child: Material(
                                      color: SodamStyle.background,
                                      borderRadius: BorderRadius.circular(10),
                                      child: InkWell(
                                        key: Key('order-detail-${item.id}'),
                                        borderRadius: BorderRadius.circular(10),
                                        onTap: () => Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                CustomerOrderDetailScreen(
                                                  order: order,
                                                  item: item,
                                                ),
                                          ),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              Row(
                                                children: [
                                                  OrderStatusBadge(
                                                    status: order.status,
                                                  ),
                                                  const SizedBox(width: 12),
                                                  const Text(
                                                    '상세 보기',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: SodamStyle.green,
                                                    ),
                                                  ),
                                                  const Icon(
                                                    Icons.chevron_right,
                                                    size: 18,
                                                    color: SodamStyle.green,
                                                  ),
                                                ],
                                              ),
                                              OrderProductInformation(
                                                item: item,
                                              ),
                                              Text(
                                                item.id,
                                                textAlign: TextAlign.right,
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  color: SodamStyle.muted,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
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
