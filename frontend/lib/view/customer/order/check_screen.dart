// 기능: 배송지·수량·포인트·결제 수단·동의 단계 연결.
// 표시 계층: ref.watch로 상태를 구독하고 사용자 동작은 Notifier·서비스에 전달한다.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beauty_project/vm/customer/state/customer_screen_handler.dart';
import 'package:beauty_project/vm/customer/cart_handler.dart';
import 'package:beauty_project/vm/customer/cart_persistence_handler.dart';
import 'package:beauty_project/vm/customer/checkout_flow_handler.dart';
import 'package:beauty_project/vm/customer/checkout_handler.dart';
import 'package:beauty_project/vm/customer/customer_handler.dart';
import 'package:beauty_project/vm/customer/order_handler.dart';
import '../product/product_widgets.dart';
import 'checkout_widgets.dart';
import 'complete_screen.dart';
import 'list_screen.dart';
import 'checkout_stock_widgets.dart';
import 'package:beauty_project/vm/customer/checkout_stock_handler.dart';
import 'package:beauty_project/vm/customer/product_handler.dart';
import 'package:beauty_project/vm/customer/point_handler.dart';
import '../delivery/shipping_address_sheet.dart';
import 'checkout_points_widgets.dart';
import 'package:beauty_project/vm/customer/checkout_points_handler.dart';

class CustomerCheckoutScreen extends ConsumerStatefulWidget {
  const CustomerCheckoutScreen({super.key});

  @override
  ConsumerState<CustomerCheckoutScreen> createState() =>
      _CustomerCheckoutScreenState();
}

class _CustomerCheckoutScreenState
    extends ConsumerState<CustomerCheckoutScreen> {
  final _scroll = ScrollController();
  late final _paymentUi = customerOperationProvider((
    screen: this,
    action: 'checkout-payment',
  ));
  late final _addressUi = customerOperationProvider((
    screen: this,
    action: 'checkout-address',
  ));
  bool get _submitting => ref.read(_paymentUi).isLoading;
  bool get _editingAddress => ref.read(_addressUi).isLoading;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted && ref.read(selectedCartItemsProvider).isNotEmpty) {
        ref.read(productHandlerProvider.notifier).refreshProducts();
      }
    });
  }

  /// Function: 입력·포커스·스크롤 등 화면이 소유한 자원을 해제한다. Provider는 autoDispose 규칙을 따른다.
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _top() {
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _back() {
    if (ref.read(customerPaymentProvider).isLoading || _submitting) return;
    if (ref.read(checkoutFlowProvider).step == CheckoutStep.information) {
      Navigator.of(context).maybePop();
    } else {
      ref.read(checkoutFlowProvider.notifier).previous();
      _top();
    }
  }

  void _details(String title, String message) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(child: Text(message)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('확인'),
        ),
      ],
    ),
  );

  /// Function: 중복 결제를 막고 결제 VM의 확정 결과를 주문 완료 화면에 전달한다.
  Future<void> _pay() async {
    if (_submitting ||
        !ref.read(checkoutFlowProvider).canSubmit ||
        ref.read(customerPaymentProvider).isLoading) {
      return;
    }
    ref.read(_paymentUi.notifier).begin();
    try {
      final order = await ref.read(customerPaymentProvider.notifier).pay();
      if (!mounted || order == null) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => CustomerOrderCompleteScreen(order: order),
        ),
      );
    } finally {
      if (mounted) ref.read(_paymentUi.notifier).finish();
    }
  }

  // Function: 이번 결제의 배송 정보만 변경한다. 회원 기본 정보는 수정하지 않는다.
  Future<void> _changeShipping() async {
    if (_submitting ||
        _editingAddress ||
        ref.read(customerPaymentProvider).isLoading) {
      return;
    }
    final customerId = ref.read(customerHandlerProvider).value?.customerId;
    if (customerId == null) return;
    ref.read(_addressUi.notifier).begin();
    try {
      final address = await showShippingAddressSheet(
        context,
        ref.read(checkoutAddressProvider),
      );
      if (!mounted ||
          address == null ||
          ref.read(customerHandlerProvider).value?.customerId != customerId) {
        return;
      }
      ref.read(checkoutAddressProvider.notifier).update(address);
    } finally {
      if (mounted) ref.read(_addressUi.notifier).finish();
    }
  }

  List<Widget> _buildInformation() {
    final customer = ref.watch(customerHandlerProvider).value;
    final canChangeShipping =
        customer != null &&
        !_submitting &&
        !_editingAddress &&
        !ref.watch(customerPaymentProvider).isLoading;
    return [
      _buildOrdererInfo(),
      const Divider(),
      _buildShippingInfo(canChangeShipping: canChangeShipping),
      const Divider(),
      _buildProductsInfo(),
      TextButton(
        key: const Key('checkout-order-shipping'),
        onPressed: canChangeShipping ? _changeShipping : null,
        child: const Text('주문 배송 정보 변경'),
      ),
    ];
  }

  Widget _buildOrdererInfo() {
    final customer = ref.watch(customerHandlerProvider).value;
    return ExpansionTile(
      key: const Key('checkout-orderer'),
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 16),
      shape: const Border(),
      collapsedShape: const Border(),
      title: const Text(
        '주문자 정보',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                customer?.name ?? '로그인이 필요합니다.',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              if (customer != null) ...[
                const SizedBox(height: 6),
                Text(customer.phone),
                Text(customer.email),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildShippingInfo({required bool canChangeShipping}) {
    final address = ref.watch(checkoutAddressProvider);
    final flow = ref.watch(checkoutFlowProvider);
    final handler = ref.read(checkoutFlowProvider.notifier);
    return CheckoutSection(
      title: '배송지 정보',
      trailing: TextButton(
        key: const Key('checkout-change-address'),
        onPressed: canChangeShipping ? _changeShipping : null,
        child: Text(_editingAddress ? '변경 중…' : '배송지 변경'),
      ),
      children: [
        if (address?.isComplete == true) ...[
          Text(
            '${address!.recipient} ${address.phone}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Text(
            address.address,
            style: const TextStyle(
              fontSize: 13,
              color: CheckoutStyle.muted,
              height: 1.7,
            ),
          ),
        ] else
          const Text(
            '배송지를 입력해 주세요.',
            style: TextStyle(fontSize: 13, color: CheckoutStyle.muted),
          ),
        const SizedBox(height: 12),
        DropdownButtonFormField<CheckoutDeliveryRequest>(
          key: const Key('checkout-delivery-request'),
          initialValue: flow.deliveryRequest,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: '배송 요청사항',
            labelStyle: const TextStyle(
              fontSize: 12,
              color: CheckoutStyle.muted,
            ),
            filled: true,
            fillColor: CheckoutStyle.field,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
          style: const TextStyle(
            fontFamily: 'NotoSansKR',
            fontSize: 12,
            color: CheckoutStyle.ink,
          ),
          items: [
            for (final request in CheckoutDeliveryRequest.values)
              DropdownMenuItem(value: request, child: Text(request.label)),
          ],
          onChanged: (value) {
            if (value != null) handler.selectDeliveryRequest(value);
          },
        ),
        if (flow.deliveryRequest == CheckoutDeliveryRequest.custom) ...[
          const SizedBox(height: 10),
          TextFormField(
            key: const Key('checkout-custom-delivery-request'),
            initialValue: flow.customDeliveryRequest,
            onChanged: handler.editDeliveryRequest,
            maxLength: 200,
            minLines: 2,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: '배송 요청사항을 입력해 주세요.',
              hintStyle: TextStyle(fontSize: 12, color: CheckoutStyle.muted),
            ),
            style: const TextStyle(fontSize: 13),
          ),
        ],
        const SizedBox(height: 6),
        _buildHint('배송 요청사항은 주문의 배송 정보와 함께 저장됩니다.'),
      ],
    );
  }

  Widget _buildProductsInfo() {
    final items = ref.watch(selectedCartItemsProvider);
    return CheckoutSection(
      title: '주문 상품 정보',
      children: [
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('결제할 상품이 없어요.'),
          ),
        for (final item in items)
          CheckoutProductSummary(item: item, editQuantity: true),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => showCustomerPreviewCart(context),
            child: const Text('장바구니에서 상품 변경'),
          ),
        ),
      ],
    );
  }

  Text _buildHint(String text, {double fontSize = 11, double? height}) => Text(
    text,
    style: TextStyle(
      fontSize: fontSize,
      color: CheckoutStyle.muted,
      height: height,
    ),
  );

  List<Widget> _buildAmounts() {
    final total = ref.watch(selectedCartTotalProvider);
    final points = ref.watch(checkoutPointSummaryProvider);
    return [
      const CheckoutSection(
        title: '할인 금액',
        children: [CheckoutAmountRow('상품 할인', '0원')],
      ),
      const Divider(),
      const CheckoutPointsSection(),
      const Divider(),
      CheckoutSection(
        title: '결제 금액 확인',
        children: [
          CheckoutAmountRow('상품 금액', productPrice(total)),
          if (points.used > 0)
            CheckoutAmountRow(
              '포인트 사용',
              '-${productPrice(points.used.toDouble())}',
            ),
          const CheckoutAmountRow('배송비', '무료'),
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 8),
          CheckoutAmountRow(
            '총 결제 금액',
            productPrice(points.payable),
            key: const Key('checkout-total'),
            highlight: true,
          ),
        ],
      ),
    ];
  }

  Widget _buildBenefits({bool compact = false}) => CheckoutSection(
    title: '혜택 포인트',
    children: [
      CheckoutAmountRow(
        compact ? '총 적립 예정' : '예상 적립',
        '${expectedPurchasePoints(ref.watch(checkoutPointSummaryProvider).payable)}P',
      ),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: compact ? CheckoutStyle.field : Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            CheckoutAmountRow(
              '구매 적립 (결제 금액의 10%)',
              '${expectedPurchasePoints(ref.watch(checkoutPointSummaryProvider).payable)}P',
            ),
            _buildHint('포인트 차감 후 결제 금액 기준 · 소수점 이하 버림'),
          ],
        ),
      ),
    ],
  );

  static const _paymentNotice =
      '결제수단 선택은 화면에서만 적용됩니다. 현재는 카드·계좌에서 금액이 청구되지 않고 주문이 결제 완료 상태로 저장됩니다.';

  Widget _buildPaymentInfo(CheckoutFlowState flow, {bool compact = false}) =>
      CheckoutSection(
        title: '결제 수단',
        children: [
          CheckoutMethodChoices(
            selected: flow.method,
            compact: compact,
            onChanged: ref.read(checkoutFlowProvider.notifier).selectMethod,
          ),
          if (!compact) ...[
            const SizedBox(height: 12),
            _buildHint(_paymentNotice, fontSize: 12, height: 1.7),
          ],
        ],
      );

  List<Widget> _buildPaymentMethod(CheckoutFlowState flow) => [
    _buildPaymentInfo(flow),
    const Divider(),
    _buildBenefits(),
  ];

  List<Widget> _buildAgreement(CheckoutFlowState flow) {
    final handler = ref.read(checkoutFlowProvider.notifier);
    final points = ref.watch(checkoutPointSummaryProvider);
    return [
      _buildPaymentInfo(flow, compact: true),
      const Divider(),
      _buildBenefits(compact: true),
      const Divider(),
      CheckoutSection(
        title: '주문 내용 및 결제 동의',
        children: [
          CheckoutAgreementRow(
            key: const Key('checkout-agree-all'),
            label: '전체 동의',
            value: flow.allAgreed,
            onChanged: handler.agreeAll,
          ),
          CheckoutAgreementRow(
            key: const Key('checkout-agree-purchase'),
            label: '구매 조건 및 결제 진행 동의 (필수)',
            value: flow.purchaseAgreed,
            onChanged: handler.agreePurchase,
            description: '선택한 상품과 수량, 배송 주소를 확인했습니다.',
            onDetails: () => _details(
              '구매 조건 및 결제 진행 확인',
              '주문 상품과 수량, 배송 주소를 확인해 주세요. 최종 가격과 재고는 주문 처리 시 서버에서 확인합니다.\n\n$_paymentNotice',
            ),
          ),
          CheckoutAgreementRow(
            key: const Key('checkout-agree-privacy'),
            label: '주문 정보 전송 확인 (필수)',
            value: flow.privacyAgreed,
            onChanged: handler.agreePrivacy,
            onDetails: () => _details(
              '주문 정보 전송 확인',
              '주문 처리를 위해 로그인한 고객번호, 선택 상품과 수량, 배송 주소를 서버에 전송합니다. 카드번호·계좌번호를 입력받거나 전송하지 않습니다.',
            ),
          ),
          const SizedBox(height: 10),
          _buildHint('필수 항목을 모두 확인해야 주문을 확정할 수 있습니다.'),
        ],
      ),
      const Divider(),
      CheckoutSection(
        title: '배송 요청사항',
        children: [
          Text(
            flow.deliveryRequestText,
            key: const Key('checkout-delivery-request-summary'),
            style: const TextStyle(fontSize: 13, height: 1.7),
          ),
          const SizedBox(height: 6),
          _buildHint('배송 요청사항은 주문의 배송 정보와 함께 저장됩니다.'),
        ],
      ),
      const Divider(),
      if (points.used > 0)
        CheckoutAmountRow('포인트 사용', '-${productPrice(points.used.toDouble())}'),
      CheckoutAmountRow(
        '총 결제 금액',
        productPrice(points.payable),
        highlight: true,
      ),
      const SizedBox(height: 12),
      _buildHint(_paymentNotice, fontSize: 12, height: 1.7),
    ];
  }

  Widget _buildContinueButton({
    required bool enabled,
    required bool last,
    required String label,
  }) => DecoratedBox(
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: CheckoutStyle.border)),
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton(
            key: Key(last ? 'checkout-payment' : 'checkout-next'),
            style: FilledButton.styleFrom(
              backgroundColor: CheckoutStyle.accent,
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFFE9EBED),
              disabledForegroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: enabled
                ? () {
                    if (last) {
                      _pay();
                    } else {
                      ref.read(checkoutFlowProvider.notifier).next();
                      _top();
                    }
                  }
                : null,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _buildCheckoutBody({
    required CheckoutFlowState flow,
    required List<Widget> content,
    required Object? error,
    required bool reviewRequired,
  }) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 600),
      child: ListView(
        controller: _scroll,
        key: Key('checkout-step-${flow.step.index}'),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        children: [
          const CheckoutStockNotice(),
          ...content,
          if (error != null) ...[
            const SizedBox(height: 16),
            Text(
              error.toString(),
              key: const Key('checkout-payment-error'),
              style: const TextStyle(color: Color(0xFFB94B55), fontSize: 13),
            ),
            if (reviewRequired)
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const CustomerOrderListScreen(),
                  ),
                ),
                child: const Text('구매 내역 확인'),
              ),
          ],
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    ref.watch(_paymentUi);
    ref.watch(_addressUi);
    final flow = ref.watch(checkoutFlowProvider);
    final payment = ref.watch(customerPaymentProvider);
    final reviewRequired = ref
        .read(customerPaymentProvider.notifier)
        .reviewRequired;
    final address = ref.watch(checkoutAddressProvider);
    final items = ref.watch(selectedCartItemsProvider);
    final points = ref.watch(checkoutPointSummaryProvider);
    final busy = payment.isLoading || _submitting;
    final ready =
        !busy &&
        !reviewRequired &&
        !ref.watch(cartPersistenceProvider).isLoading &&
        ref.watch(checkoutStockProvider).canPurchase &&
        points.canContinue &&
        ref.watch(customerHandlerProvider).value != null &&
        items.isNotEmpty &&
        flow.deliveryRequestValid &&
        address?.isComplete == true;
    final last = flow.step == CheckoutStep.agreement;
    final canContinue =
        ready &&
        (last
            ? flow.canSubmit
            : flow.step != CheckoutStep.method || flow.method != null);
    final label = busy
        ? '주문 처리 중…'
        : switch (flow.step) {
            CheckoutStep.information => '다음',
            CheckoutStep.amount => '${productPrice(points.payable)} · 다음',
            CheckoutStep.method => '주문 내용 확인',
            CheckoutStep.agreement => '${productPrice(points.payable)} 결제하기',
          };
    final content = switch (flow.step) {
      CheckoutStep.information => _buildInformation(),
      CheckoutStep.amount => _buildAmounts(),
      CheckoutStep.method => _buildPaymentMethod(flow),
      CheckoutStep.agreement => _buildAgreement(flow),
    };
    return Theme(
      data: CheckoutStyle.theme(Theme.of(context)),
      child: PopScope(
        canPop: !busy && flow.step == CheckoutStep.information,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && !busy) _back();
        },
        child: AbsorbPointer(
          absorbing: busy,
          child: Scaffold(
            key: const Key('customer-checkout-screen'),
            appBar: AppBar(
              leading: IconButton(
                key: const Key('checkout-back'),
                onPressed: _back,
                tooltip: '이전',
                icon: const Icon(Icons.arrow_back_ios_new, size: 19),
              ),
              title: const Text('주문/결제'),
            ),
            bottomNavigationBar: _buildContinueButton(
              enabled: canContinue,
              last: last,
              label: label,
            ),
            body: _buildCheckoutBody(
              flow: flow,
              content: content,
              error: payment.hasError ? payment.error : null,
              reviewRequired: reviewRequired,
            ),
          ),
        ),
      ),
    );
  }
}

// 변경 내용(2026-10-30): 결제 진입 시 재고를 갱신하고 주문 상품의 수량 변경·재고 부족 표시·결제 차단을 연결한다.
