
import '../../model/delivery/delivery.dart';

class DeliveryState {
  // 전체 배송 목록
  final List<Delivery> deliveries;

  // 선택한 배송번호
  final String? selectedDeliveryId;

  // 배송 상태 필터
  final String selectedStatus;

  // 배송 목록 조회 중
  final bool isLoading;

  // 배송 상태 변경 처리 중
  final bool isProcessing;

  // 성공 메시지
  final String? successMessage;

  // 오류 메시지
  final String? errorMessage;

  const DeliveryState({
    this.deliveries = const [],
    this.selectedDeliveryId,
    this.selectedStatus = 'ALL',
    this.isLoading = false,
    this.isProcessing = false,
    this.successMessage,
    this.errorMessage,
  });

  // State 복사 및 변경
  DeliveryState copyWith({
    List<Delivery>? deliveries,
    String? selectedDeliveryId,
    String? selectedStatus,
    bool? isLoading,
    bool? isProcessing,
    String? successMessage,
    String? errorMessage,
    bool clearSelectedDeliveryId = false,
    bool clearSuccessMessage = false,
    bool clearErrorMessage = false,
  }) {
    return DeliveryState(
      deliveries: deliveries ?? this.deliveries,
      selectedDeliveryId: clearSelectedDeliveryId
          ? null
          : (selectedDeliveryId ?? this.selectedDeliveryId),
      selectedStatus: selectedStatus ?? this.selectedStatus,
      isLoading: isLoading ?? this.isLoading,
      isProcessing: isProcessing ?? this.isProcessing,
      successMessage: clearSuccessMessage
          ? null
          : (successMessage ?? this.successMessage),
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
    );
  }

  // 현재 선택한 배송
  Delivery? get selectedDelivery {
    for (final delivery in deliveries) {
      if (delivery.deliveryId == selectedDeliveryId) {
        return delivery;
      }
    }

    return null;
  }

  // 배송 상태별 목록 필터링
  List<Delivery> get filteredDeliveries {
    if (selectedStatus == 'ALL') {
      return deliveries;
    }

    return deliveries.where((delivery) {
      return delivery.deliveryStatus == selectedStatus;
    }).toList();
  }

  // 전체 배송 건수
  int get totalCount => deliveries.length;

  // 배송 준비 건수
  int get readyCount {
    return deliveries.where((delivery) {
      return delivery.deliveryStatus == 'READY';
    }).length;
  }

  // 배송 중 건수
  int get inTransitCount {
    return deliveries.where((delivery) {
      return delivery.deliveryStatus == 'IN_TRANSIT';
    }).length;
  }

  // 배송 완료 건수
  int get deliveredCount {
    return deliveries.where((delivery) {
      return delivery.deliveryStatus == 'DELIVERED';
    }).length;
  }

  // 배송 시작 가능 여부
  bool get canStartDelivery {
    return selectedDelivery?.deliveryStatus == 'READY' &&
        !isLoading &&
        !isProcessing;
  }

  // 배송 완료 가능 여부
  bool get canCompleteDelivery {
    return selectedDelivery?.deliveryStatus == 'IN_TRANSIT' &&
        !isLoading &&
        !isProcessing;
  }
}
