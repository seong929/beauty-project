import 'package:flutter/foundation.dart';

@immutable
class ReturnManagementState {
  final String selectedStatus;
  final String? processingReturnId;
  final String? errorMessage;
  final String? successMessage;

  const ReturnManagementState({
    this.selectedStatus = 'ALL',
    this.processingReturnId,
    this.errorMessage,
    this.successMessage,
  });

  bool get isProcessing => processingReturnId != null;

  ReturnManagementState copyWith({
    String? selectedStatus,
    String? processingReturnId,
    String? errorMessage,
    String? successMessage,
    bool clearProcessing = false,
    bool clearMessages = false,
  }) => ReturnManagementState(
    selectedStatus: selectedStatus ?? this.selectedStatus,
    processingReturnId: clearProcessing
        ? null
        : processingReturnId ?? this.processingReturnId,
    errorMessage: clearMessages ? null : errorMessage ?? this.errorMessage,
    successMessage: clearMessages
        ? null
        : successMessage ?? this.successMessage,
  );
}
