
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../model/admin/purchase_order.dart';
import '../../service/admin/purchase_order_service.dart';
import '../auth/auth_notifier.dart';
import 'purchase_order_state.dart';

// 발주 Service Provider
final purchaseOrderServiceProvider = Provider<PurchaseOrderService>((ref) {
  return const PurchaseOrderService(
    baseUrl: 'http://127.0.0.1:8000',
  );
});

class PurchaseOrderNotifier extends Notifier<PurchaseOrderState> {
  @override
  PurchaseOrderState build() {
    return const PurchaseOrderState();
  }

  // 1. 발주 목록 조회
  Future<void> getPurchaseOrderList() async {
    final authState = ref.read(authProvider);
    final employee = authState.employee;

    if (!authState.isAdmin || employee == null) {
      state = state.copyWith(
        errorMessage: '관리자 로그인이 필요합니다.',
      );
      return;
    }

    if (employee.accessToken.isEmpty) {
      state = state.copyWith(
        errorMessage: '인증 토큰이 없습니다. 다시 로그인해 주세요.',
      );
      return;
    }

    state = state.copyWith(
      isLoading: true,
      clearErrorMessage: true,
    );

    try {
      final service = ref.read(purchaseOrderServiceProvider);

      final purchaseOrders = await service.getPurchaseOrderList(
        accessToken: employee.accessToken,
      );

      // 목록을 새로고침해도 기존 선택 발주 유지
      final selectedId = state.selectedPurchaseOrder?.purchaseOrderId;

      PurchaseOrder? selectedPurchaseOrder;

      if (selectedId != null) {
        for (final purchaseOrder in purchaseOrders) {
          if (purchaseOrder.purchaseOrderId == selectedId) {
            selectedPurchaseOrder = purchaseOrder;
            break;
          }
        }
      }

      state = state.copyWith(
        purchaseOrders: purchaseOrders,
        selectedPurchaseOrder: selectedPurchaseOrder,
        clearSelectedPurchaseOrder: selectedPurchaseOrder == null,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  // 2. 발주 선택
  void selectPurchaseOrder(PurchaseOrder purchaseOrder) {
    state = state.copyWith(
      selectedPurchaseOrder: purchaseOrder,
    );
  }

  // 3. 발주 등록
  Future<bool> createPurchaseOrder({
    required String approvalId,
    required String manufacturerId,
    required String unitSupplyPrice,
  }) async {
    if (state.isProcessing) {
      return false;
    }

    final authState = ref.read(authProvider);
    final employee = authState.employee;

    if (!authState.isAdmin || employee == null) {
      state = state.copyWith(
        errorMessage: '관리자 로그인이 필요합니다.',
      );
      return false;
    }

    if (employee.accessToken.isEmpty) {
      state = state.copyWith(
        errorMessage: '인증 토큰이 없습니다. 다시 로그인해 주세요.',
      );
      return false;
    }

    // 입력값 검증
    if (approvalId.trim().isEmpty ||
        manufacturerId.trim().isEmpty ||
        unitSupplyPrice.trim().isEmpty) {
      state = state.copyWith(
        errorMessage: '모든 발주 정보를 입력해 주세요.',
      );
      return false;
    }

    final price = num.tryParse(unitSupplyPrice.trim());

    if (price == null || !price.isFinite || price <= 0) {
      state = state.copyWith(
        errorMessage: '공급 단가는 0보다 큰 숫자여야 합니다.',
      );
      return false;
    }

    state = state.copyWith(
      isProcessing: true,
      clearErrorMessage: true,
    );

    try {
      final service = ref.read(purchaseOrderServiceProvider);

      final request = PurchaseOrderCreateRequest(
        approvalId: approvalId.trim(),
        manufacturerId: manufacturerId.trim(),
        unitSupplyPrice: unitSupplyPrice.trim(),
      );

      await service.createPurchaseOrder(
        request: request,
        accessToken: employee.accessToken,
      );

      // 등록 성공 후 발주 목록 새로고침
      await getPurchaseOrderList();

      if (state.errorMessage != null) {
        return false;
      }

      return true;
    } catch (e) {
      state = state.copyWith(
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );

      return false;
    } finally {
      state = state.copyWith(
        isProcessing: false,
      );
    }
  }
}

// 발주 NotifierProvider
final purchaseOrderProvider =
    NotifierProvider<PurchaseOrderNotifier, PurchaseOrderState>(
      PurchaseOrderNotifier.new,
    );
