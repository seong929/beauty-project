import '../../model/delivery/return_pickup.dart';

class ReturnPickupState {
  final List<ReturnPickup> pickups;
  final bool isLoading, isProcessing;
  final String? errorMessage, successMessage;
  final String selectedFilter;
  ReturnPickupState({
    List<ReturnPickup> pickups = const [],
    this.isLoading = false,
    this.isProcessing = false,
    this.errorMessage,
    this.successMessage,
    this.selectedFilter = 'ALL',
  }) : pickups = List.unmodifiable(pickups);
  List<ReturnPickup> get filteredPickups => List.unmodifiable(
    pickups.where(
      (p) => selectedFilter == 'ALL' || p.pickupStatus == selectedFilter,
    ),
  );
  ReturnPickupState copyWith({
    List<ReturnPickup>? pickups,
    bool? isLoading,
    bool? isProcessing,
    String? errorMessage,
    String? successMessage,
    String? selectedFilter,
    bool clearMessages = false,
  }) => ReturnPickupState(
    pickups: pickups ?? this.pickups,
    isLoading: isLoading ?? this.isLoading,
    isProcessing: isProcessing ?? this.isProcessing,
    errorMessage: clearMessages ? null : errorMessage ?? this.errorMessage,
    successMessage: clearMessages
        ? null
        : successMessage ?? this.successMessage,
    selectedFilter: selectedFilter ?? this.selectedFilter,
  );
}
