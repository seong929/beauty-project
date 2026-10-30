import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beauty_project/model/customer/order.dart';
import 'package:beauty_project/vm/customer/customer_handler.dart';
import 'package:beauty_project/vm/customer/order_handler.dart';
import 'package:beauty_project/vm/customer/return_handler.dart';
import '../login/customer_auth_widgets.dart';
import '../order/order_history_widgets.dart';
import '../product/product_list.dart';
import '../product/product_widgets.dart';
import 'return_status_screen.dart';

class CustomerReturnRequestScreen extends ConsumerStatefulWidget {
  const CustomerReturnRequestScreen({
    super.key,
    required this.order,
    this.item,
  });
  final CustomerOrder order;
  final CustomerOrderLine? item;

  @override
  ConsumerState<CustomerReturnRequestScreen> createState() =>
      _CustomerReturnRequestScreenState();
}

class _CustomerReturnRequestScreenState
    extends ConsumerState<CustomerReturnRequestScreen> {
  final _form = GlobalKey<FormState>();
  final _details = TextEditingController();
  final _quantity = TextEditingController(text: '1');
  String? _reason;
  String? _itemId;
  bool _confirmed = false;

  @override
  void dispose() {
    _details.dispose();
    _quantity.dispose();
    super.dispose();
  }

  Future<void> _submit(CustomerOrder order, CustomerOrderLine item) async {
    if (!_confirmed || !_form.currentState!.validate()) return;
    final result = await ref
        .read(customerReturnHandlerProvider.notifier)
        .submit(
          order: order,
          item: item,
          reason: '$_reason\n${_details.text.trim()}',
          quantity: int.tryParse(_quantity.text) ?? 1,
        );
    if (!mounted || result == null) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => CustomerReturnStatusScreen(
          order: order,
          item: item,
          initial: result,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final customerId = ref.watch(customerHandlerProvider).value?.customerId;
    final order =
        ref
            .watch(customerOrdersProvider)
            .value
            ?.where((entry) => entry.id == widget.order.id)
            .firstOrNull ??
        widget.order;
    final candidates = order.items
        .where(
          (entry) =>
              widget.item == null ||
              (entry.productId == widget.item!.productId &&
                  entry.unitPrice == widget.item!.unitPrice &&
                  entry.saleOption == widget.item!.saleOption &&
                  entry.deliveryId == widget.item!.deliveryId),
        )
        .toList();
    final item =
        candidates.where((entry) => entry.id == _itemId).firstOrNull ??
        candidates.where((entry) => entry.id == widget.item?.id).firstOrNull ??
        candidates.firstOrNull;
    final history = ref.watch(customerReturnsProvider(item?.id));
    final submission = ref.watch(customerReturnHandlerProvider);
    final handler = ref.read(customerReturnHandlerProvider.notifier);
    final available = item == null
        ? 0
        : remainingReturnQuantity(item: item, requests: history.value ?? []);
    final eligible =
        customerId == order.customerId &&
        item != null &&
        const {'SHIPPED', 'DELIVERED', 'RETURNED'}.contains(order.status);
    final busy = submission.isLoading;
    final canSend =
        eligible &&
        available > 0 &&
        history.hasValue &&
        !history.isLoading &&
        !history.hasError &&
        !busy &&
        _confirmed &&
        !handler.reviewRequired(item.id);
    return PopScope(
      canPop: !busy,
      child: AbsorbPointer(
        absorbing: busy,
        child: Scaffold(
          key: const Key('customer-return-request'),
          appBar: AppBar(
            title: const Text('반품 신청'),
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
              MaterialPageRoute(
                builder: (_) => const CustomerProductListScreen(),
              ),
            ),
          ),
          body: customerId != order.customerId
              ? const Center(child: Text('로그인한 고객의 구매 내역을 확인해 주세요.'))
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
                      children: [
                        if (item != null) OrderProductInformation(item: item),
                        if (item != null)
                          Text(
                            item.id,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 10,
                              color: SodamStyle.muted,
                            ),
                          ),
                        if (!eligible)
                          const Padding(
                            padding: EdgeInsets.all(14),
                            child: Text('배송된 주문상품만 반품 신청할 수 있습니다.'),
                          ),
                        const SizedBox(height: 22),
                        Form(
                          key: _form,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (candidates.length > 1) ...[
                                DropdownButtonFormField<String>(
                                  key: const Key('return-purchase-item'),
                                  initialValue: item?.id,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: '반품할 구매항목 선택',
                                  ),
                                  items: [
                                    for (final entry in candidates)
                                      DropdownMenuItem(
                                        value: entry.id,
                                        child: Text(
                                          '${entry.id} · 구매 ${entry.quantity}개',
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                  ],
                                  onChanged: (value) => setState(() {
                                    _itemId = value;
                                    _quantity.text = '1';
                                    _confirmed = false;
                                  }),
                                ),
                                const SizedBox(height: 18),
                              ],
                              const Text(
                                '반품 사유',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                key: const Key('return-reason'),
                                decoration: const InputDecoration(
                                  hintText: '반품 사유를 선택해 주세요.',
                                ),
                                items: [
                                  for (final reason in [
                                    '파손',
                                    '오배송',
                                    '상품 불량',
                                    '단순 변심',
                                    '기타',
                                  ])
                                    DropdownMenuItem(
                                      value: reason,
                                      child: Text(reason),
                                    ),
                                ],
                                onChanged: (value) => setState(() {
                                  _reason = value;
                                  _confirmed = false;
                                }),
                                validator: (value) =>
                                    value == null ? '반품 사유를 선택해 주세요.' : null,
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                '상세 사유',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                key: const Key('return-detail'),
                                controller: _details,
                                minLines: 2,
                                maxLines: 4,
                                maxLength: 450,
                                decoration: const InputDecoration(
                                  hintText: '상품의 상태와 사유를 알려주세요.',
                                ),
                                onChanged: (_) {
                                  if (_confirmed) {
                                    setState(() => _confirmed = false);
                                  }
                                },
                                validator: (value) =>
                                    value == null || value.trim().isEmpty
                                    ? '상세 사유를 입력해 주세요.'
                                    : null,
                              ),
                              if ((item?.quantity ?? 0) > 1) ...[
                                const SizedBox(height: 12),
                                TextFormField(
                                  key: const Key('return-quantity'),
                                  controller: _quantity,
                                  decoration: InputDecoration(
                                    labelText: '반품 수량',
                                    helperText: '현재 반품 가능 수량 $available개',
                                  ),
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  maxLength: 6,
                                  validator: (value) {
                                    final quantity =
                                        int.tryParse(value ?? '') ?? 0;
                                    return quantity < 1 || quantity > available
                                        ? '1~$available개로 입력해 주세요.'
                                        : null;
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (history.isLoading) const LinearProgressIndicator(),
                        if (history.hasError)
                          OrderLoadError(
                            error: history.error!,
                            onRetry: () => ref.invalidate(
                              customerReturnsProvider(item?.id),
                            ),
                          ),
                        if (history.hasValue && available == 0)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text('이미 반품 신청한 수량을 제외하면 반품 가능한 상품이 없습니다.'),
                          ),
                        CheckboxListTile(
                          key: const Key('return-confirm'),
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          value: _confirmed,
                          onChanged: (value) =>
                              setState(() => _confirmed = value ?? false),
                          title: const Text(
                            '상품 상태와 반품 신청 내용을 확인했습니다.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEFAFB),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            '반품은 신청 후 검토·승인·회수·검수 절차를 거칩니다. 신청만으로 환불이 완료되지 않으며, 진행 결과는 반품 현황에서 확인할 수 있습니다.',
                            style: TextStyle(
                              fontSize: 12,
                              color: SodamStyle.muted,
                              height: 1.8,
                            ),
                          ),
                        ),
                        if (submission.hasError &&
                            handler.activeItemId == item?.id)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              submission.error.toString(),
                              key: const Key('return-error'),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),
                        FilledButton(
                          key: const Key('return-submit'),
                          onPressed: canSend
                              ? () => _submit(order, item)
                              : null,
                          child: Text(busy ? '신청 중…' : '반품 신청하기'),
                        ),
                        const SizedBox(height: 18),
                        if (history.value?.isNotEmpty == true)
                          const Text(
                            '기존 반품 신청 내역',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        for (final request in history.value ?? [])
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              request.statusLabel,
                              style: const TextStyle(fontSize: 13),
                            ),
                            subtitle: Text(
                              '${request.id} · ${request.quantity}개',
                              style: const TextStyle(fontSize: 10),
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: item == null
                                ? null
                                : () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          CustomerReturnStatusScreen(
                                            order: order,
                                            item: item,
                                            initial: request,
                                          ),
                                    ),
                                  ),
                          ),
                        TextButton(
                          onPressed: () =>
                              ref.invalidate(customerReturnsProvider(item?.id)),
                          child: const Text('반품 내역 새로고침'),
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
