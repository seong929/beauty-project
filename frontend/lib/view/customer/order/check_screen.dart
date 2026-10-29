import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beauty_project/vm/customer/cart_handler.dart';
import 'package:beauty_project/vm/customer/cart_persistence_handler.dart';
import 'package:beauty_project/vm/customer/checkout_flow_handler.dart';
import 'package:beauty_project/vm/customer/checkout_handler.dart';
import 'package:beauty_project/vm/customer/customer_handler.dart';
import 'package:beauty_project/vm/customer/order_handler.dart';
import '../delivery/delivery_address_screen.dart';
import '../product/product_widgets.dart';
import 'checkout_widgets.dart';
import 'complete_screen.dart';
import 'list_screen.dart';

class CustomerCheckoutScreen extends ConsumerStatefulWidget {
  const CustomerCheckoutScreen({super.key});

  @override
  ConsumerState<CustomerCheckoutScreen> createState() =>
      _CustomerCheckoutScreenState();
}

class _CustomerCheckoutScreenState
    extends ConsumerState<CustomerCheckoutScreen> {
  final _scroll = ScrollController();
  bool _submitting = false;

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

  Future<void> _pay() async {
    if (_submitting ||
        !ref.read(checkoutFlowProvider).canSubmit ||
        ref.read(customerPaymentProvider).isLoading) {
      return;
    }
    setState(() => _submitting = true);
    try {
      final order = await ref.read(customerPaymentProvider.notifier).pay();
      if (!mounted || order == null) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => CustomerOrderCompleteScreen(order: order),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  List<Widget> _information() {
    final customer = ref.watch(customerHandlerProvider).value;
    final address = ref.watch(checkoutAddressProvider);
    final items = ref.watch(selectedCartItemsProvider);
    final flow = ref.watch(checkoutFlowProvider);
    final handler = ref.read(checkoutFlowProvider.notifier);
    return [
      ExpansionTile(
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
      ),
      const Divider(),
      CheckoutSection(
        title: '배송지 정보',
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
          const Text(
            '배송 요청사항은 현재 화면에만 유지되며 주문에는 저장되지 않습니다.',
            style: TextStyle(fontSize: 11, color: CheckoutStyle.muted),
          ),
        ],
      ),
      const Divider(),
      CheckoutSection(
        title: '주문 상품 정보',
        children: [
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('결제할 상품이 없어요.'),
            ),
          for (final item in items) CheckoutProductSummary(item: item),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => showCustomerPreviewCart(context),
              child: const Text('장바구니에서 상품 변경'),
            ),
          ),
        ],
      ),
      TextButton(
        key: const Key('checkout-existing-order-address'),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const CustomerDeliveryAddressScreen(),
          ),
        ),
        child: const Text('주문한 상품의 배송지 변경'),
      ),
    ];
  }

  List<Widget> _amount() {
    final customer = ref.watch(customerHandlerProvider).value;
    final total = ref.watch(selectedCartTotalProvider);
    return [
      const CheckoutSection(
        title: '할인 금액',
        children: [CheckoutAmountRow('상품 할인', '0원')],
      ),
      const Divider(),
      CheckoutSection(
        title: '소담 포인트',
        children: [
          TextFormField(
            key: const Key('checkout-points'),
            enabled: false,
            initialValue: '0',
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              filled: true,
              fillColor: CheckoutStyle.field,
              suffixText: '사용 준비 중',
              suffixStyle: const TextStyle(
                fontSize: 12,
                color: CheckoutStyle.muted,
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const SizedBox(
                width: 32,
                height: 36,
                child: Checkbox(value: false, onChanged: null),
              ),
              Expanded(
                child: Text(
                  '항상 포인트 사용 (준비 중) · 보유 ${customer?.pointsBalance ?? 0}P',
                  style: const TextStyle(
                    fontSize: 12,
                    color: CheckoutStyle.muted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            '포인트 사용은 현재 주문에 적용되지 않습니다.',
            style: TextStyle(fontSize: 11, color: CheckoutStyle.muted),
          ),
        ],
      ),
      const Divider(),
      CheckoutSection(
        title: '결제 금액 확인',
        children: [
          CheckoutAmountRow('상품 금액', productPrice(total)),
          const CheckoutAmountRow('배송비', '무료'),
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 8),
          CheckoutAmountRow(
            '총 결제 금액',
            productPrice(total),
            key: const Key('checkout-total'),
            highlight: true,
          ),
        ],
      ),
    ];
  }

  Widget _benefits({bool compact = false}) => CheckoutSection(
    title: '혜택 포인트',
    children: [
      CheckoutAmountRow(compact ? '총 적립 예정' : '예상 적립', '준비 중'),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: compact ? CheckoutStyle.field : Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Column(
          children: [
            CheckoutAmountRow('구매 적립', '준비 중'),
            CheckoutAmountRow('리뷰 적립', '준비 중'),
          ],
        ),
      ),
    ],
  );

  static const _paymentNotice =
      '결제수단 선택은 화면에서만 적용됩니다. 현재는 카드·계좌에서 금액이 청구되지 않고 주문이 결제 완료 상태로 저장됩니다.';

  List<Widget> _method(CheckoutFlowState flow) => [
    CheckoutSection(
      title: '결제 수단',
      children: [
        CheckoutMethodChoices(
          selected: flow.method,
          onChanged: ref.read(checkoutFlowProvider.notifier).selectMethod,
        ),
        const SizedBox(height: 12),
        const Text(
          _paymentNotice,
          style: TextStyle(
            fontSize: 12,
            color: CheckoutStyle.muted,
            height: 1.7,
          ),
        ),
      ],
    ),
    const Divider(),
    _benefits(),
  ];

  List<Widget> _agreement(CheckoutFlowState flow) {
    final handler = ref.read(checkoutFlowProvider.notifier);
    final total = ref.watch(selectedCartTotalProvider);
    return [
      CheckoutSection(
        title: '결제 수단',
        children: [
          CheckoutMethodChoices(
            selected: flow.method,
            onChanged: handler.selectMethod,
            compact: true,
          ),
        ],
      ),
      const Divider(),
      _benefits(compact: true),
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
          const Text(
            '필수 항목을 모두 확인해야 주문을 확정할 수 있습니다.',
            style: TextStyle(fontSize: 11, color: CheckoutStyle.muted),
          ),
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
          const Text(
            '배송 요청사항은 주문에 저장되지 않습니다.',
            style: TextStyle(fontSize: 11, color: CheckoutStyle.muted),
          ),
        ],
      ),
      const Divider(),
      CheckoutAmountRow('총 결제 금액', productPrice(total), highlight: true),
      const SizedBox(height: 12),
      const Text(
        _paymentNotice,
        style: TextStyle(fontSize: 12, color: CheckoutStyle.muted, height: 1.7),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final flow = ref.watch(checkoutFlowProvider);
    final payment = ref.watch(customerPaymentProvider);
    final reviewRequired = ref
        .read(customerPaymentProvider.notifier)
        .reviewRequired;
    final address = ref.watch(checkoutAddressProvider);
    final items = ref.watch(selectedCartItemsProvider);
    final total = ref.watch(selectedCartTotalProvider);
    final busy = payment.isLoading || _submitting;
    final ready =
        !busy &&
        !reviewRequired &&
        !ref.watch(cartPersistenceProvider).isLoading &&
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
            CheckoutStep.amount => '${productPrice(total)} · 다음',
            CheckoutStep.method => '주문 내용 확인',
            CheckoutStep.agreement => '${productPrice(total)} 결제하기',
          };
    final content = switch (flow.step) {
      CheckoutStep.information => _information(),
      CheckoutStep.amount => _amount(),
      CheckoutStep.method => _method(flow),
      CheckoutStep.agreement => _agreement(flow),
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
            bottomNavigationBar: DecoratedBox(
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
                      onPressed: canContinue
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
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: ListView(
                  controller: _scroll,
                  key: Key('checkout-step-${flow.step.index}'),
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                  children: [
                    ...content,
                    if (payment.hasError) ...[
                      const SizedBox(height: 16),
                      Text(
                        payment.error.toString(),
                        key: const Key('checkout-payment-error'),
                        style: const TextStyle(
                          color: Color(0xFFB94B55),
                          fontSize: 13,
                        ),
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
            ),
          ),
        ),
      ),
    );
  }
}
