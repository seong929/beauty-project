
import '../../model/admin/approval.dart';

class ApprovalState {
  final List<Approval> approvals;
  final Approval? selectedApproval;
  final bool isLoading;
  final bool isProcessing;
  final String? errorMessage;

  const ApprovalState({
    this.approvals = const [],
    this.selectedApproval,
    this.isLoading = false,
    this.isProcessing = false,
    this.errorMessage,
  });

  ApprovalState copyWith({
    List<Approval>? approvals,
    Approval? selectedApproval,
    bool clearSelectedApproval = false,
    bool? isLoading,
    bool? isProcessing,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return ApprovalState(
      approvals: approvals ?? this.approvals,
      selectedApproval: clearSelectedApproval
          ? null
          : selectedApproval ?? this.selectedApproval,
      isLoading: isLoading ?? this.isLoading,
      isProcessing: isProcessing ?? this.isProcessing,
      errorMessage: clearErrorMessage
          ? null
          : errorMessage ?? this.errorMessage,
    );
  }
}
