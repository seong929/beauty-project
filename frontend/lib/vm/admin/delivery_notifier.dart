import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../service/api_config.dart';
import '../auth/api_client_provider.dart';

import '../../service/admin/delivery_service.dart';
import '../auth/auth_notifier.dart';
import 'delivery_state.dart';

// 배송 API 서비스 Provider
final deliveryServiceProvider = Provider<DeliveryService>((ref) {
  return DeliveryService(
    baseUrl: ApiConfig.baseUrl,
    client: ref.read(apiClientProvider),
  );
});

// 배송 상태 관리 Notifier
class DeliveryNotifier extends Notifier<DeliveryState> {
  @override
  DeliveryState build() {
    return const DeliveryState();
  }

  // 로그인한 직원의 Access Token 가져오기
  String _getAccessToken() {
    final employee = ref.read(authProvider).employee;

    if (employee == null) {
      throw Exception('로그인이 필요합니다.');
    }

    if (employee.employeeRole != 'ADMIN' && employee.employeeRole != 'STAFF') {
      throw Exception('배송 조회 권한이 없습니다.');
    }

    return employee.accessToken;
  }

  // 배송 목록 조회
  Future<void> fetchDeliveryList() async {
    if (state.isLoading) {
      return;
    }

    state = state.copyWith(isLoading: true, clearErrorMessage: true);

    try {
      final accessToken = _getAccessToken();

      final deliveryService = ref.read(deliveryServiceProvider);

      final deliveries = await deliveryService.fetchDeliveryList(
        accessToken: accessToken,
        isStaff: ref.read(authProvider).isStaff,
      );

      // 기존에 선택한 배송이 목록에 남아 있는지 확인
      final selectedDeliveryExists = deliveries.any(
        (delivery) => delivery.deliveryId == state.selectedDeliveryId,
      );

      state = state.copyWith(
        deliveries: deliveries,
        isLoading: false,
        clearSelectedDeliveryId: !selectedDeliveryExists,
        clearErrorMessage: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  // 배송 선택
  void selectDelivery(String deliveryId) {
    state = state.copyWith(
      selectedDeliveryId: deliveryId,
      clearErrorMessage: true,
    );
  }

  // 배송 상태 필터 변경
  void changeStatusFilter(String status) {
    const allowedStatuses = {'ALL', 'READY', 'IN_TRANSIT', 'DELIVERED'};

    if (!allowedStatuses.contains(status)) {
      return;
    }

    state = state.copyWith(
      selectedStatus: status,
      clearSelectedDeliveryId: true,
      clearErrorMessage: true,
    );
  }

  // 배송 선택 해제
  void clearSelectedDelivery() {
    state = state.copyWith(clearSelectedDeliveryId: true);
  }

  // 오류 메시지 초기화
  void clearErrorMessage() {
    state = state.copyWith(clearErrorMessage: true);
  }
}

// 배송 상태 Provider
final deliveryProvider = NotifierProvider<DeliveryNotifier, DeliveryState>(
  DeliveryNotifier.new,
);
