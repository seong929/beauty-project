import '../../model/admin/outbound.dart';

class OutboundState {
  // 출고 대상 주문 목록
  final List<OutboundOrder> orders;

  // 선택한 주문 ID
  final String? selectedOrderId;

  // 선택한 배송업체 ID
  final String selectedCarrierId;

  // 주문 목록 조회 중
  final bool isLoading;

  // 출고 처리 중
  final bool isProcessing;

  // 오류 메시지
  final String? errorMessage;

  // 출고 성공 메시지
  final String? successMessage;

  const OutboundState({
    this.orders = const [],
    this.selectedOrderId,
    this.selectedCarrierId = '',
    this.isLoading = false,
    this.isProcessing = false,
    this.errorMessage,
    this.successMessage,
  });

  OutboundState copyWith({
    List<OutboundOrder>? orders,
    String? selectedOrderId,
    String? selectedCarrierId,
    bool? isLoading,
    bool? isProcessing,
    String? errorMessage,
    String? successMessage,
    bool clearSelectedOrderId = false,
    bool clearErrorMessage = false,
    bool clearSuccessMessage = false,
  }) {
    return OutboundState(
      orders: orders ?? this.orders,
      selectedOrderId: clearSelectedOrderId
          ? null
          : (selectedOrderId ?? this.selectedOrderId),
      selectedCarrierId: selectedCarrierId ?? this.selectedCarrierId,
      isLoading: isLoading ?? this.isLoading,
      isProcessing: isProcessing ?? this.isProcessing,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccessMessage
          ? null
          : (successMessage ?? this.successMessage),
    );
  }

  // 선택한 주문 정보
  OutboundOrder? get selectedOrder {
    for (final order in orders) {
      if (order.orderId == selectedOrderId) {
        return order;
      }
    }

    return null;
  }

  // 출고 가능한 주문 수
  int get preparingCount => orders.length;

  // 출고 처리 가능 여부
  bool get canProcessOutbound {
    return selectedOrder != null &&
        selectedOrder!.orderStatus == 'PREPARING' &&
        selectedCarrierId.isNotEmpty &&
        !isLoading &&
        !isProcessing;
  }
}
