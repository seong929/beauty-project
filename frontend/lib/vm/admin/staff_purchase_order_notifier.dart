
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../model/admin/purchase_order.dart';
import 'purchase_order_notifier.dart';
import '../auth/auth_notifier.dart';
import 'staff_purchase_order_state.dart';

class StaffPurchaseOrderNotifier
    extends Notifier<StaffPurchaseOrderState> {
  @override
  StaffPurchaseOrderState build() {
    return const StaffPurchaseOrderState();
  }

  // 1. 입고 가능한 발주 목록 조회
  Future<void> getPurchaseOrderList() async {
    final authState = ref.read(authProvider);
    final employee = authState.employee;

    // STAFF 또는 ADMIN 로그인 확인
    if ((!authState.isStaff && !authState.isAdmin) ||
        employee == null) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: '직원 로그인이 필요합니다.',
      );
      return;
    }

    if (employee.accessToken.isEmpty) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: '인증 토큰이 없습니다. 다시 로그인해 주세요.',
      );
      return;
    }

    state = state.copyWith(
      isLoading: true,
      clearErrorMessage: true,
    );

    try {
      // 기존 ADMIN Service Provider 재사용
      final service = ref.read(purchaseOrderServiceProvider);

      final purchaseOrders = await service.getPurchaseOrderList(
        accessToken: employee.accessToken,
      );

      // 입고 가능한 발주만 추출
      final availableOrders = purchaseOrders
          .where((order) => order.canInbound)
          .toList();

      // 새로고침 시 기존 선택 발주 유지
      final selectedId =
          state.selectedPurchaseOrder?.purchaseOrderId;

      PurchaseOrder? selectedPurchaseOrder;

      if (selectedId != null) {
        for (final order in availableOrders) {
          if (order.purchaseOrderId == selectedId) {
            selectedPurchaseOrder = order;
            break;
          }
        }
      }

      state = state.copyWith(
        purchaseOrders: availableOrders,
        selectedPurchaseOrder: selectedPurchaseOrder,
        clearSelectedPurchaseOrder:
            selectedPurchaseOrder == null,
        isLoading: false,
        clearErrorMessage: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceFirst(
          'Exception: ',
          '',
        ),
      );
    }
  }

  // 2. 입고할 발주 선택
  void selectPurchaseOrder(PurchaseOrder purchaseOrder) {
    if (!purchaseOrder.canInbound) {
      state = state.copyWith(
        errorMessage: '입고할 수 없는 발주입니다.',
      );
      return;
    }

    state = state.copyWith(
      selectedPurchaseOrder: purchaseOrder,
      clearErrorMessage: true,
    );
  }

  // 3. 선택한 발주 초기화
  void clearSelection() {
    state = state.copyWith(
      clearSelectedPurchaseOrder: true,
    );
  }
}

// STAFF 발주 목록 Provider
final staffPurchaseOrderProvider =
    NotifierProvider<
      StaffPurchaseOrderNotifier,
      StaffPurchaseOrderState
    >(
      StaffPurchaseOrderNotifier.new,
    );
