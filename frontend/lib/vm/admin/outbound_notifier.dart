import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../service/api_config.dart';
import '../auth/api_client_provider.dart';

import '../../service/admin/outbound_service.dart';
import '../auth/auth_notifier.dart';
import 'outbound_state.dart';

// 출고 API 서비스 Provider
final outboundServiceProvider = Provider<OutboundService>((ref) {
  return OutboundService(
    baseUrl: ApiConfig.baseUrl,
    client: ref.read(apiClientProvider),
  );
});

// 출고 상태 관리 Notifier
class OutboundNotifier extends Notifier<OutboundState> {
  @override
  OutboundState build() {
    Future.microtask(() {
      fetchPreparingOrders();
    });
    return const OutboundState();
  }

  // 로그인한 직원의 Access Token 가져오기
  String _getAccessToken() {
    final employee = ref.read(authProvider).employee;

    if (employee == null) {
      throw Exception('로그인이 필요합니다.');
    }

    if (employee.employeeRole != 'ADMIN' && employee.employeeRole != 'STAFF') {
      throw Exception('출고 관리 권한이 없습니다.');
    }

    return employee.accessToken;
  }

  // 출고 대상 주문 목록 조회
  Future<void> fetchPreparingOrders() async {
    if (state.isLoading || state.isProcessing) {
      return;
    }

    state = state.copyWith(isLoading: true, clearErrorMessage: true);

    try {
      final accessToken = _getAccessToken();

      final outboundService = ref.read(outboundServiceProvider);

      final orders = await outboundService.fetchPreparingOrders(
        accessToken: accessToken,
      );

      // 기존 선택 주문이 목록에 남아 있는지 확인
      final selectedOrderExists = orders.any(
        (order) => order.orderId == state.selectedOrderId,
      );

      state = state.copyWith(
        orders: orders,
        isLoading: false,
        clearSelectedOrderId: !selectedOrderExists,
        clearErrorMessage: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  // 주문 선택
  void selectOrder(String orderId) {
    if (state.isProcessing) {
      return;
    }

    state = state.copyWith(
      selectedOrderId: orderId,
      clearErrorMessage: true,
      clearSuccessMessage: true,
    );
  }

  // 배송업체 선택
  void selectCarrier(String carrierId) {
    if (state.isProcessing) {
      return;
    }

    state = state.copyWith(
      selectedCarrierId: carrierId,
      clearErrorMessage: true,
      clearSuccessMessage: true,
    );
  }

  // 선택한 주문 출고 처리
  Future<bool> createOutbound() async {
    if (!state.canProcessOutbound) {
      state = state.copyWith(
        errorMessage: '출고할 주문과 배송업체를 선택해 주세요.',
        clearSuccessMessage: true,
      );
      return false;
    }

    final orderId = state.selectedOrderId!;
    final carrierId = state.selectedCarrierId;

    state = state.copyWith(
      isProcessing: true,
      clearErrorMessage: true,
      clearSuccessMessage: true,
    );

    try {
      final accessToken = _getAccessToken();

      final outboundService = ref.read(outboundServiceProvider);

      final result = await outboundService.createOutbound(
        accessToken: accessToken,
        orderId: orderId,
        carrierId: carrierId,
      );

      // 출고 성공 후 처리된 주문을 목록에서 제거
      final updatedOrders = state.orders
          .where((order) => order.orderId != orderId)
          .toList();

      state = state.copyWith(
        orders: updatedOrders,
        isProcessing: false,
        clearSelectedOrderId: true,
        successMessage:
            '${result.orderId} 출고가 완료되었습니다.\n'
            '배송 번호: ${result.deliveryId}',
      );

      // 서버에서 최신 주문 목록 다시 조회
      await fetchPreparingOrders();

      return true;
    } catch (e) {
      state = state.copyWith(
        isProcessing: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
        clearSuccessMessage: true,
      );

      return false;
    }
  }

  // 메시지 초기화
  void clearMessages() {
    state = state.copyWith(clearErrorMessage: true, clearSuccessMessage: true);
  }
}

// 출고 상태 Provider
final outboundProvider = NotifierProvider<OutboundNotifier, OutboundState>(
  OutboundNotifier.new,
);
