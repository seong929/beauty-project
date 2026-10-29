import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../service/api_config.dart';
import '../auth/api_client_provider.dart';

import '../../model/admin/approval.dart';
import '../../service/admin/approval_service.dart';
import '../auth/auth_notifier.dart';
import 'approval_state.dart';

// FastAPI 통신 Service
final approvalServiceProvider = Provider<ApprovalService>((ref) {
  return ApprovalService(
    baseUrl: ApiConfig.baseUrl,
    client: ref.read(apiClientProvider),
  );
});

// Riverpod Notifier
class ApprovalNotifier extends Notifier<ApprovalState> {
  @override
  ApprovalState build() {
    return const ApprovalState();
  }

  // 1. 품의 목록 조회
  Future<void> getApprovalList() async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true, clearErrorMessage: true);

    try {
      final service = ref.read(approvalServiceProvider);

      final approvals = await service.getApprovalList();

      state = state.copyWith(
        approvals: approvals,
        isLoading: false,
        clearSelectedApproval: true,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  // 2. 품의 선택
  void selectApproval(Approval approval) {
    state = state.copyWith(selectedApproval: approval);
  }

  // 3. 품의 승인 및 반려
  Future<bool> decideApproval({
    required String approvalId,
    required String employeeId,
    required String decisionStatus,
    String? manufacturerId,
    int? orderQuantity,
    String? unitSupplyPrice,
  }) async {
    if (state.isProcessing) {
      return false;
    }

    // 로그인한 관리자 정보 확인
    final authState = ref.read(authProvider);
    final employee = authState.employee;

    if (!authState.isAdmin || employee == null) {
      state = state.copyWith(errorMessage: '관리자 로그인이 필요합니다.');
      return false;
    }

    // 로그인한 관리자와 결재 요청자 일치 확인
    if (employee.employeeId != employeeId) {
      state = state.copyWith(errorMessage: '로그인한 관리자 정보가 일치하지 않습니다.');
      return false;
    }

    // JWT 가져오기
    final accessToken = employee.accessToken;

    if (accessToken.isEmpty) {
      state = state.copyWith(errorMessage: '인증 토큰이 없습니다. 다시 로그인해 주세요.');
      return false;
    }

    state = state.copyWith(isProcessing: true, clearErrorMessage: true);

    try {
      final service = ref.read(approvalServiceProvider);

      // JWT를 포함하여 승인·반려 API 호출
      await service.decideApproval(
        approvalId: approvalId,
        employeeId: employeeId,
        decisionStatus: decisionStatus,
        accessToken: accessToken,
        manufacturerId: manufacturerId,
        orderQuantity: orderQuantity,
        unitSupplyPrice: unitSupplyPrice,
      );

      // 승인·반려 후 최신 품의 목록 다시 조회
      await getApprovalList();

      // 결재 요청이 커밋된 뒤 목록 갱신이 실패해도 작업 자체는 성공이다.
      return true;
    } catch (e) {
      state = state.copyWith(
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );

      return false;
    } finally {
      state = state.copyWith(isProcessing: false);
    }
  }
}

// NotifierProvider
final approvalProvider = NotifierProvider<ApprovalNotifier, ApprovalState>(
  ApprovalNotifier.new,
);
