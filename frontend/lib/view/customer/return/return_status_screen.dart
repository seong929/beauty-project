import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beauty_project/model/customer/order.dart';
import 'package:beauty_project/model/customer/return_request.dart';
import 'package:beauty_project/vm/customer/customer_handler.dart';
import 'package:beauty_project/vm/customer/return_handler.dart';
import 'package:beauty_project/vm/customer/order_handler.dart';
import '../login/customer_auth_widgets.dart';
import '../order/order_history_widgets.dart';
import '../order/order_summary.dart';
import '../product/product_list.dart';
import '../product/product_widgets.dart';

class CustomerReturnStatusScreen extends ConsumerWidget {
  const CustomerReturnStatusScreen({
    super.key,
    required this.order,
    required this.item,
    required this.initial,
  });
  final CustomerOrder order;
  final CustomerOrderLine item;
  final CustomerReturnRequest initial;

  Widget _event(
    String title,
    bool done,
    DateTime? date, {
    bool last = false,
  }) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 26,
          child: Column(
            children: [
              Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.only(top: 5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done ? SodamStyle.green : SodamStyle.background,
                  border: Border.all(color: const Color(0xFFD9F1F3), width: 2),
                ),
              ),
              if (!last)
                Expanded(
                  child: Container(width: 1, color: const Color(0xFFEBEDF0)),
                ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 0, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: done ? SodamStyle.ink : SodamStyle.muted,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  done
                      ? (date == null ? '처리일 미제공' : orderDateText(date))
                      : '진행 대기',
                  style: const TextStyle(fontSize: 11, color: SodamStyle.muted),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customerId = ref.watch(customerHandlerProvider).value?.customerId;
    final history = ref.watch(customerReturnsProvider(item.id));
    final request =
        history.value?.where((entry) => entry.id == initial.id).firstOrNull ??
        initial;
    void refresh() {
      ref.invalidate(customerReturnsProvider(item.id));
      ref.invalidate(customerOrdersProvider);
    }

    final reasonParts = request.reason.split('\n');
    return Scaffold(
      key: const Key('customer-return-status'),
      appBar: AppBar(
        title: const Text('반품 진행 · 결과'),
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
      body: customerId != request.customerId || customerId != order.customerId
          ? const Center(child: Text('로그인한 고객의 반품 내역을 확인해 주세요.'))
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEFAFB),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            request.statusLabel,
                            key: const Key('return-current-status'),
                            style: const TextStyle(
                              fontSize: 11,
                              color: SodamStyle.green,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          orderDateText(request.requestedOn),
                          style: const TextStyle(
                            fontSize: 11,
                            color: SodamStyle.muted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    OrderProductInformation(
                      item: CustomerOrderLine(
                        id: item.id,
                        productId: item.productId,
                        name: item.name,
                        quantity: request.quantity,
                        unitPrice: item.unitPrice,
                        saleOption: item.saleOption,
                        deliveryId: item.deliveryId,
                      ),
                    ),
                    const Divider(height: 26),
                    OrderInformationRow('반품번호', request.id),
                    OrderInformationRow('구매번호', request.itemId),
                    OrderInformationRow('반품 사유', reasonParts.first),
                    if (reasonParts.length > 1)
                      OrderInformationRow(
                        '상세 내용',
                        reasonParts.skip(1).join('\n'),
                      ),
                    const SizedBox(height: 20),
                    _event('반품 신청', true, request.requestedOn),
                    _event(
                      request.status == 'REJECTED' ? '반품 반려' : '반품 승인',
                      request.approved || request.status == 'REJECTED',
                      request.status == 'REJECTED' ? null : request.approvedOn,
                    ),
                    _event(
                      '회수 요청',
                      request.pickupRequested,
                      request.pickupRequestedOn,
                    ),
                    _event(
                      '수거 완료',
                      request.collected,
                      request.pickupCompletedOn,
                    ),
                    _event(
                      '본사 수령',
                      request.receivedOn != null,
                      request.receivedOn,
                    ),
                    _event(
                      '검수 완료',
                      request.status == 'COMPLETED',
                      request.inspectionCompletedOn,
                      last: true,
                    ),
                    OrderInformationRow('환불 상태', request.refundLabel),
                    const Text(
                      '환불 상태는 내부 업무 진행 현황입니다. 외부 결제 취소·실제 금액 반환은 연동되어 있지 않습니다.',
                      style: TextStyle(fontSize: 11, color: SodamStyle.muted),
                    ),
                    OrderInformationRow(
                      '처리 결과',
                      request.inspectionResult?.isNotEmpty == true
                          ? request.inspectionResult!
                          : '등록 대기',
                    ),
                    if (request.pickupStatus == 'FAILED')
                      const Text(
                        '회수에 실패했습니다. 후속 처리 안내를 확인해 주세요.',
                        style: TextStyle(color: Color(0xFFAD615C)),
                      ),
                    if (history.isLoading) const LinearProgressIndicator(),
                    if (history.hasError)
                      OrderLoadError(error: history.error!, onRetry: refresh),
                    if (history.hasValue &&
                        !history.value!.any((entry) => entry.id == initial.id))
                      const Text('최신 조회 결과에서 해당 신청을 찾지 못했습니다. 다시 조회해 주세요.'),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      key: const Key('return-status-refresh'),
                      onPressed: refresh,
                      child: const Text('반품 현황 새로고침'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
