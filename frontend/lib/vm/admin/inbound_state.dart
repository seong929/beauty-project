
import '../../model/admin/inbound.dart';

class InboundState {
  final InboundCreateResponse? inboundResult;
  final bool isLoading;
  final bool isProcessing;
  final String? errorMessage;

  const InboundState({
    this.inboundResult,
    this.isLoading = false,
    this.isProcessing = false,
    this.errorMessage,
  });

  InboundState copyWith({
    InboundCreateResponse? inboundResult,
    bool? isLoading,
    bool? isProcessing,
    String? errorMessage,
    bool clearInboundResult = false,
    bool clearErrorMessage = false,
  }) {
    return InboundState(
      inboundResult: clearInboundResult
          ? null
          : inboundResult ?? this.inboundResult,
      isLoading: isLoading ?? this.isLoading,
      isProcessing: isProcessing ?? this.isProcessing,
      errorMessage: clearErrorMessage
          ? null
          : errorMessage ?? this.errorMessage,
    );
  }
}
