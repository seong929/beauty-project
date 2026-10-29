
import '../../model/admin/purchase_order.dart';

class StaffPurchaseOrderState {
  final List<PurchaseOrder> purchaseOrders;
  final PurchaseOrder? selectedPurchaseOrder;
  final bool isLoading;
  final String? errorMessage;

  const StaffPurchaseOrderState({
    this.purchaseOrders = const [],
    this.selectedPurchaseOrder,
    this.isLoading = false,
    this.errorMessage,
  });

  // 입고 가능한 발주만 조회
  List<PurchaseOrder> get inboundAvailableOrders {
    return purchaseOrders
        .where((order) => order.canInbound)
        .toList();
  }

  StaffPurchaseOrderState copyWith({
    List<PurchaseOrder>? purchaseOrders,
    PurchaseOrder? selectedPurchaseOrder,
    bool? isLoading,
    String? errorMessage,
    bool clearSelectedPurchaseOrder = false,
    bool clearErrorMessage = false,
  }) {
    return StaffPurchaseOrderState(
      purchaseOrders: purchaseOrders ?? this.purchaseOrders,
      selectedPurchaseOrder: clearSelectedPurchaseOrder
          ? null
          : (selectedPurchaseOrder ?? this.selectedPurchaseOrder),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
    );
  }
}
