
import '../../model/admin/delivery.dart';

class DeliveryState {
  // 전체 배송 목록
  final List<Delivery> deliveries;

  // 선택한 배송 ID
  final String? selectedDeliveryId;

  // 배송 상태 필터
  final String selectedStatus;

  // 배송 목록 조회 중
  final bool isLoading;

  // 오류 메시지
  final String? errorMessage;

  const DeliveryState({
    this.deliveries = const [],
    this.selectedDeliveryId,
    this.selectedStatus = 'ALL',
    this.isLoading = false,
    this.errorMessage,
  });

  DeliveryState copyWith({
    List<Delivery>? deliveries,
    String? selectedDeliveryId,
    String? selectedStatus,
    bool? isLoading,
    String? errorMessage,
    bool clearSelectedDeliveryId = false,
    bool clearErrorMessage = false,
  }) {
    return DeliveryState(
      deliveries: deliveries ?? this.deliveries,
      selectedDeliveryId: clearSelectedDeliveryId
          ? null
          : (selectedDeliveryId ?? this.selectedDeliveryId),
      selectedStatus: selectedStatus ?? this.selectedStatus,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
    );
  }

  // 선택한 배송 정보
  Delivery? get selectedDelivery {
    for (final delivery in deliveries) {
      if (delivery.deliveryId == selectedDeliveryId) {
        return delivery;
      }
    }

    return null;
  }

  // 배송 상태에 따른 목록 필터링
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
}
