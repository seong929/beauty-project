
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../service/delivery/delivery_service.dart';
import '../auth/auth_notifier.dart';
import 'delivery_state.dart';

// 배송업체 API 서비스 Provider
final deliveryServiceProvider = Provider<DeliveryService>((ref) {
  return const DeliveryService(
    baseUrl: 'http://127.0.0.1:8000',
  );
});

// 배송업체 상태 관리 Notifier
class DeliveryNotifier extends Notifier<DeliveryState> {
  @override
  DeliveryState build() {
    return const DeliveryState();
  }

  // 로그인한 사용자의 Access Token 가져오기
  String _getAccessToken() {
    final employee = ref.read(authProvider).employee;

    if (employee == null) {
      throw Exception('로그인이 필요합니다.');
    }

    if (employee.accessToken.isEmpty) {
      throw Exception('로그인 토큰이 없습니다.');
    }

    return employee.accessToken;
  }

  // 배송 목록 조회
  Future<void> fetchDeliveryList() async {
    if (state.isLoading || state.isProcessing) {
      return;
    }

    state = state.copyWith(
      isLoading: true,
      clearErrorMessage: true,
    );

    try {
      final accessToken = _getAccessToken();

      final deliveryService = ref.read(
        deliveryServiceProvider,
      );

      final deliveries = await deliveryService.fetchDeliveryList(
        accessToken: accessToken,
      );

      // 기존 선택 배송이 목록에 존재하는지 확인
      final selectedDeliveryExists = deliveries.any(
        (delivery) =>
            delivery.deliveryId == state.selectedDeliveryId,
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
        errorMessage: e.toString().replaceFirst(
          'Exception: ',
          '',
        ),
      );
    }
  }

  // 배송 선택
  void selectDelivery(String deliveryId) {
    if (state.isProcessing) {
      return;
    }

    state = state.copyWith(
      selectedDeliveryId: deliveryId,
      clearSuccessMessage: true,
      clearErrorMessage: true,
    );
  }

  // 배송 상태 필터 변경
  void changeStatusFilter(String status) {
    if (state.isProcessing) {
      return;
    }

    const allowedStatuses = {
      'ALL',
      'READY',
      'IN_TRANSIT',
      'DELIVERED',
    };

    if (!allowedStatuses.contains(status)) {
      return;
    }

    state = state.copyWith(
      selectedStatus: status,
      clearSelectedDeliveryId: true,
      clearSuccessMessage: true,
      clearErrorMessage: true,
    );
  }

  // 배송 시작
  Future<void> startDelivery() async {
    if (!state.canStartDelivery) {
      return;
    }

    await _updateDeliveryStatus('IN_TRANSIT');
  }

  // 배송 완료
  Future<void> completeDelivery() async {
    if (!state.canCompleteDelivery) {
      return;
    }

    await _updateDeliveryStatus('DELIVERED');
  }

  // 배송 상태 변경 공통 처리
  Future<void> _updateDeliveryStatus(
    String deliveryStatus,
  ) async {
    final selectedDelivery = state.selectedDelivery;

    if (selectedDelivery == null || state.isProcessing) {
      return;
    }

    final deliveryId = selectedDelivery.deliveryId;

    state = state.copyWith(
      isProcessing: true,
      clearSuccessMessage: true,
      clearErrorMessage: true,
    );

    try {
      final accessToken = _getAccessToken();

      final deliveryService = ref.read(
        deliveryServiceProvider,
      );

      // PATCH API 호출
      final result = await deliveryService.updateDeliveryStatus(
        accessToken: accessToken,
        deliveryId: deliveryId,
        deliveryStatus: deliveryStatus,
      );

      // PATCH 성공 후 최신 배송 목록 조회
      final deliveries = await deliveryService.fetchDeliveryList(
        accessToken: accessToken,
      );

      // 선택한 배송이 필터 결과에 남아 있는지 확인
      final selectedDeliveryExists = deliveries.any(
        (delivery) =>
            delivery.deliveryId == deliveryId &&
            (state.selectedStatus == 'ALL' ||
                delivery.deliveryStatus == state.selectedStatus),
      );

      state = state.copyWith(
        deliveries: deliveries,
        isProcessing: false,
        successMessage: result.message,
        clearSelectedDeliveryId: !selectedDeliveryExists,
        clearErrorMessage: true,
      );
    } catch (e) {
      state = state.copyWith(
        isProcessing: false,
        errorMessage: e.toString().replaceFirst(
          'Exception: ',
          '',
        ),
      );
    }
  }

  // 성공 및 오류 메시지 초기화
  void clearMessages() {
    state = state.copyWith(
      clearSuccessMessage: true,
      clearErrorMessage: true,
    );
  }
}

// 배송업체 상태 Provider
final deliveryProvider =
    NotifierProvider<DeliveryNotifier, DeliveryState>(
  DeliveryNotifier.new,
);
