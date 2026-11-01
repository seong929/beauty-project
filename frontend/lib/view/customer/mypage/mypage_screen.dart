// 기능: 고객 프로필·포인트·구매·배송 메뉴와 탈퇴.
// 표시 계층: ref.watch로 상태를 구독하고 사용자 동작은 Notifier·서비스에 전달한다.

import 'package:flutter/material.dart';
import 'package:beauty_project/model/customer/customers.dart';
import 'package:beauty_project/model/customer/order.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beauty_project/vm/customer/state/customer_screen_handler.dart';
import 'package:beauty_project/vm/customer/customer_handler.dart';
import 'package:beauty_project/vm/customer/customer_profile_photo_handler.dart';
import 'package:beauty_project/vm/customer/order_handler.dart';
import '../delivery/delivery_list_screen.dart';
import '../login/customer_auth_widgets.dart';
import '../login/customer_login_screen.dart';
import '../order/list_screen.dart';
import '../product/product_list.dart';
import '../product/product_widgets.dart';
import 'profile_edit_screen.dart';
import '../review/customer_review_list_screen.dart';
import 'point_history_screen.dart';
import 'package:beauty_project/vm/customer/point_handler.dart';

class CustomerMyPageScreen extends ConsumerStatefulWidget {
  const CustomerMyPageScreen({super.key});

  @override
  ConsumerState<CustomerMyPageScreen> createState() =>
      _CustomerMyPageScreenState();
}

class _CustomerMyPageScreenState extends ConsumerState<CustomerMyPageScreen> {
  late final _operationProvider = customerOperationProvider((
    screen: this,
    action: 'withdraw',
  ));
  CustomerOperationHandler get _operation =>
      ref.read(_operationProvider.notifier);
  bool get _busy => ref.read(_operationProvider).isLoading;

  void _open(Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  /// Function: 폼을 검증하고 로그인 VM을 호출한 뒤 성공하면 홈 화면으로 이동한다.
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

  /// Function: 탈퇴 여부를 확인하고 처리 중 동작을 잠근 뒤 로그인 화면으로 이동한다.
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
    _operation.begin();
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
      if (mounted) _operation.finish();
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

  Widget _buildContent(
    Customers customer,
    String points,
    AsyncValue<List<CustomerOrder>> orders,
    int? shipping,
  ) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 600),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
        children: [
          _buildProfileCard(customer),
          const SizedBox(height: 16),
          _buildPointsCard(points),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildOrderStatistic(
                const Key('mypage-purchases'),
                orders.value?.length.toString() ?? '—',
                '구매 주문',
                const CustomerOrderListScreen(),
              ),
              Container(height: 36, width: 1, color: SodamStyle.border),
              _buildOrderStatistic(
                const Key('mypage-shipping'),
                shipping?.toString() ?? '—',
                '배송 중',
                const CustomerDeliveryListScreen(),
              ),
            ],
          ),
          if (orders.hasError)
            TextButton(
              onPressed: () => ref.invalidate(customerOrdersProvider),
              child: const Text('주문 정보를 불러오지 못했어요. 다시 조회'),
            ),
          const SizedBox(height: 20),
          ..._buildMenus(),
          const SizedBox(height: 16),
          _buildAccountAction(
            const Key('customer-logout'),
            Icons.logout,
            '로그아웃',
            () {
              ref.read(customerHandlerProvider.notifier).logout();
              _login();
            },
          ),
          _buildAccountAction(
            const Key('mypage-withdraw'),
            Icons.person_remove_outlined,
            '회원 탈퇴',
            _withdraw,
            color: const Color(0xFFB47575),
          ),
          const SizedBox(height: 16),
          const Text(
            '하나 · 매일의 아름다움 습관',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: SodamStyle.muted),
          ),
        ],
      ),
    ),
  );

  Widget _buildProfileCard(Customers customer) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: const Color(0xFFEEFAFB),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        // 고객번호별로 저장된 사진을 구독해 개인정보 수정 후 즉시 반영한다.
        buildCustomerProfileAvatar(
          key: const Key('mypage-profile-photo'),
          bytes: ref
              .watch(customerProfilePhotoProvider(customer.customerId))
              .value,
          radius: 28,
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
                style: const TextStyle(fontSize: 11, color: SodamStyle.muted),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _buildPointsCard(String points) => InkWell(
    key: const Key('mypage-points'),
    borderRadius: BorderRadius.circular(10),
    onTap: () => _open(const CustomerPointHistoryScreen()),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEEFAFB),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Text('보유 마일리지', style: TextStyle(fontSize: 11)),
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
          const Text('내역 보기', style: TextStyle(fontSize: 10)),
          const Icon(Icons.chevron_right, size: 16),
        ],
      ),
    ),
  );

  List<Widget> _buildMenus() => [
    _menu(
      Icons.account_balance_wallet_outlined,
      '마일리지 내역',
      () => _open(const CustomerPointHistoryScreen()),
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
  ];

  Widget _buildOrderStatistic(
    Key key,
    String count,
    String label,
    Widget destination,
  ) => Expanded(
    child: InkWell(
      key: key,
      onTap: () => _open(destination),
      child: Column(
        children: [
          Text(
            count,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: SodamStyle.muted),
          ),
        ],
      ),
    ),
  );

  Widget _buildAccountAction(
    Key key,
    IconData icon,
    String label,
    VoidCallback onPressed, {
    Color? color,
  }) => Align(
    alignment: Alignment.centerRight,
    child: TextButton.icon(
      key: key,
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 32),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: 16, color: color),
      label: Text(label, style: color == null ? null : TextStyle(color: color)),
    ),
  );

  @override
  Widget build(BuildContext context) {
    ref.watch(_operationProvider);
    final customer = ref.watch(customerHandlerProvider).value;
    final orders = ref.watch(customerOrdersProvider);
    final balance =
        ref.watch(customerPointsProvider).value?.balance ??
        customer?.pointsBalance ??
        0;
    final points = balance.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );
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
              : _buildContent(customer, points, orders, shipping),
        ),
      ),
    );
  }
}

// 변경 내용(2026-10-30): 찜 메뉴를 제거하고 상단 요약을 구매 주문 수·배송 중 건수로 표시한다.
