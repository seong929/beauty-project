import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beauty_project/vm/customer/customer_handler.dart';
import 'package:beauty_project/vm/customer/order_handler.dart';
import 'package:beauty_project/vm/customer/product_search_handler.dart';
import '../delivery/delivery_list_screen.dart';
import '../login/customer_auth_widgets.dart';
import '../login/customer_login_screen.dart';
import '../order/list_screen.dart';
import '../product/product_list.dart';
import '../product/product_widgets.dart';
import 'favorite_list_screen.dart';
import 'profile_edit_screen.dart';
import '../review/customer_review_list_screen.dart';

class CustomerMyPageScreen extends ConsumerStatefulWidget {
  const CustomerMyPageScreen({super.key});

  @override
  ConsumerState<CustomerMyPageScreen> createState() =>
      _CustomerMyPageScreenState();
}

class _CustomerMyPageScreenState extends ConsumerState<CustomerMyPageScreen> {
  bool _busy = false;

  void _open(Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  void _login() => Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const CustomerLoginScreen()),
    (_) => false,
  );

  Future<void> _info(String title, String message) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('확인'),
        ),
      ],
    ),
  );

  Future<void> _withdraw() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('회원 탈퇴'),
        content: const Text('탈퇴하면 이 계정으로 로그인할 수 없습니다. 탈퇴하시겠어요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            key: const Key('confirm-withdraw'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('탈퇴하기'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(customerHandlerProvider.notifier).withdraw();
      if (mounted) _login();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _menu(
    IconData icon,
    String title,
    VoidCallback onTap, {
    String? subtitle,
    Key? key,
  }) => ListTile(
    key: key,
    contentPadding: EdgeInsets.zero,
    visualDensity: const VisualDensity(vertical: -2),
    leading: Icon(icon, size: 20, color: SodamStyle.green),
    minLeadingWidth: 14,
    title: Text(title, style: const TextStyle(fontSize: 13)),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (subtitle != null)
          Text(
            subtitle,
            style: const TextStyle(fontSize: 10, color: SodamStyle.muted),
          ),
        const Icon(Icons.chevron_right, size: 18),
      ],
    ),
    onTap: onTap,
  );

  @override
  Widget build(BuildContext context) {
    final customer = ref.watch(customerHandlerProvider).value;
    final orders = ref.watch(customerOrdersProvider);
    final points = customer?.pointsBalance.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );
    final favorites = ref.watch(favoriteProductsProvider);
    final shipping = orders.value
        ?.where((order) => order.status == 'SHIPPED')
        .length;
    return PopScope(
      canPop: !_busy,
      child: AbsorbPointer(
        absorbing: _busy,
        child: Scaffold(
          key: const Key('customer-mypage'),
          appBar: AppBar(
            title: const Text('마이페이지'),
            actions: [
              TextButton(
                onPressed: () => showCustomerPreviewCart(context),
                child: const Text('장바구니'),
              ),
            ],
          ),
          bottomNavigationBar: ProductNavigation(
            selectedIndex: 3,
            onSearch: () => _open(const CustomerProductListScreen()),
          ),
          body: customer == null
              ? Center(
                  child: FilledButton(
                    onPressed: _login,
                    child: const Text('로그인'),
                  ),
                )
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEFAFB),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              const CircleAvatar(
                                radius: 28,
                                backgroundColor: Color(0xFFD6F4F6),
                                child: Text(
                                  '소담',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: SodamStyle.green,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 18),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${customer.name}님',
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      customer.loginId,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: SodamStyle.muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        InkWell(
                          key: const Key('mypage-points'),
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => _info(
                            '마일리지',
                            '현재 보유 마일리지 ${customer.pointsBalance}P\n마일리지 상세 내역 조회는 준비 중입니다.',
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEFAFB),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Text(
                                  '보유 마일리지',
                                  style: TextStyle(fontSize: 11),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    '${points}P',
                                    key: const Key('mypage-point-balance'),
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: SodamStyle.green,
                                    ),
                                  ),
                                ),
                                const Text(
                                  '내역 보기',
                                  style: TextStyle(fontSize: 10),
                                ),
                                const Icon(Icons.chevron_right, size: 16),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                key: const Key('mypage-favorites'),
                                onTap: () =>
                                    _open(const CustomerFavoriteListScreen()),
                                child: Column(
                                  children: [
                                    Text(
                                      '${favorites.length}',
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const Text(
                                      '찜한 상품',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: SodamStyle.muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Container(
                              height: 36,
                              width: 1,
                              color: SodamStyle.border,
                            ),
                            Expanded(
                              child: InkWell(
                                key: const Key('mypage-shipping'),
                                onTap: () =>
                                    _open(const CustomerDeliveryListScreen()),
                                child: Column(
                                  children: [
                                    Text(
                                      shipping?.toString() ?? '—',
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const Text(
                                      '배송 중',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: SodamStyle.muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (orders.hasError)
                          TextButton(
                            onPressed: () =>
                                ref.invalidate(customerOrdersProvider),
                            child: const Text('주문 정보를 불러오지 못했어요. 다시 조회'),
                          ),
                        const SizedBox(height: 20),
                        _menu(
                          Icons.account_balance_wallet_outlined,
                          '마일리지 내역',
                          () => _info(
                            '마일리지',
                            '현재 보유 마일리지 ${customer.pointsBalance}P\n상세 내역 조회는 준비 중입니다.',
                          ),
                        ),
                        _menu(
                          Icons.favorite_border,
                          '찜한 상품',
                          () => _open(const CustomerFavoriteListScreen()),
                        ),
                        _menu(
                          Icons.shopping_bag_outlined,
                          '구매 내역',
                          () => _open(const CustomerOrderListScreen()),
                          key: const Key('mypage-orders'),
                        ),
                        _menu(
                          Icons.local_shipping_outlined,
                          '배송 현황',
                          () => _open(const CustomerDeliveryListScreen()),
                          key: const Key('mypage-delivery-status'),
                        ),
                        _menu(
                          Icons.rate_review_outlined,
                          '리뷰 내역',
                          () => _open(const CustomerReviewListScreen()),
                          key: const Key('mypage-reviews'),
                        ),
                        _menu(
                          Icons.local_shipping_outlined,
                          '배송 주소 관리',
                          () => _open(
                            const CustomerProfileEditScreen(addressOnly: true),
                          ),
                        ),
                        _menu(
                          Icons.person_outline,
                          '개인정보 수정',
                          () => _open(const CustomerProfileEditScreen()),
                          key: const Key('mypage-edit-profile'),
                        ),
                        _menu(
                          Icons.help_outline,
                          '배송 · 반품 안내',
                          () => _info(
                            '배송 · 반품 안내',
                            '구매 내역에서 주문 상태와 배송 주소를 확인할 수 있습니다. 출고 전인 주문은 배송 주소 변경이 가능합니다.\n\n배송된 상품의 반품은 구매 상세의 반품 신청에서 진행하고, 접수·회수·검수·환불 상태를 확인할 수 있습니다.',
                          ),
                        ),
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            key: const Key('customer-logout'),
                            style: TextButton.styleFrom(
                              minimumSize: const Size(0, 32),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () {
                              ref
                                  .read(customerHandlerProvider.notifier)
                                  .logout();
                              _login();
                            },
                            icon: const Icon(Icons.logout, size: 16),
                            label: const Text('로그아웃'),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            key: const Key('mypage-withdraw'),
                            style: TextButton.styleFrom(
                              minimumSize: const Size(0, 32),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: _withdraw,
                            icon: const Icon(
                              Icons.person_remove_outlined,
                              size: 16,
                              color: Color(0xFFB47575),
                            ),
                            label: const Text(
                              '회원 탈퇴',
                              style: TextStyle(color: Color(0xFFB47575)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          '소담 · 매일의 아름다움 습관',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            color: SodamStyle.muted,
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
