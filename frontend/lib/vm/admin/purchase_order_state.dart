
import '../../model/admin/purchase_order.dart';

class PurchaseOrderState {
  final List<PurchaseOrder> purchaseOrders;
  final PurchaseOrder? selectedPurchaseOrder;
  final bool isLoading;
  final bool isProcessing;
  final String? errorMessage;

  const PurchaseOrderState({
    this.purchaseOrders = const [],
    this.selectedPurchaseOrder,
    this.isLoading = false,
    this.isProcessing = false,
    this.errorMessage,
  });

  PurchaseOrderState copyWith({
    List<PurchaseOrder>? purchaseOrders,
    PurchaseOrder? selectedPurchaseOrder,
    bool? isLoading,
    bool? isProcessing,
    String? errorMessage,
    bool clearSelectedPurchaseOrder = false,
    bool clearErrorMessage = false,
  }) {
    return PurchaseOrderState(
      purchaseOrders: purchaseOrders ?? this.purchaseOrders,
      selectedPurchaseOrder: clearSelectedPurchaseOrder
          ? null
          : (selectedPurchaseOrder ?? this.selectedPurchaseOrder),
      isLoading: isLoading ?? this.isLoading,
      isProcessing: isProcessing ?? this.isProcessing,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
    );
  }
}
