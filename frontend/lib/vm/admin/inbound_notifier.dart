import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../service/api_config.dart';
import '../auth/api_client_provider.dart';

import '../../model/admin/inbound.dart';
import '../../service/admin/inbound_service.dart';
import '../auth/auth_notifier.dart';
import 'inbound_state.dart';

// 입고 API Service Provider
final inboundServiceProvider = Provider<InboundService>((ref) {
  return InboundService(
    baseUrl: ApiConfig.baseUrl,
    client: ref.read(apiClientProvider),
  );
});

// 입고 상태 관리 Provider
final inboundProvider = NotifierProvider<InboundNotifier, InboundState>(
  InboundNotifier.new,
);

class InboundNotifier extends Notifier<InboundState> {
  @override
  InboundState build() {
    return const InboundState();
  }

  // 본사 직원 및 관리자 입고 등록
  Future<bool> createInbound({
    required String purchaseOrderId,
    required int inboundQuantity,
    required DateTime inboundOn,
    DateTime? expiresOn,
  }) async {
    // 중복 요청 방지
    if (state.isProcessing) {
      return false;
    }

    // 기존 오류 및 입고 결과 초기화
    state = state.copyWith(
      isProcessing: true,
      clearErrorMessage: true,
      clearInboundResult: true,
    );

    try {
      // 로그인한 직원 정보 조회
      final authState = ref.read(authProvider);
      final employee = authState.employee;

      if (employee == null) {
        throw Exception('로그인이 필요합니다.');
      }

      // STAFF와 ADMIN 모두 허용
      if (!authState.isStaff && !authState.isAdmin) {
        throw Exception('본사 직원 또는 관리자만 입고 등록할 수 있습니다.');
      }

      final accessToken = employee.accessToken;
      final employeeId = employee.employeeId;

      if (accessToken.isEmpty) {
        throw Exception('로그인 인증 정보가 없습니다.');
      }

      if (employeeId.isEmpty) {
        throw Exception('직원 정보가 올바르지 않습니다.');
      }

      // 입력값 검증
      if (purchaseOrderId.trim().isEmpty) {
        throw Exception('발주를 선택해 주세요.');
      }

      if (inboundQuantity <= 0) {
        throw Exception('입고 수량은 1개 이상이어야 합니다.');
      }

      if (expiresOn != null) {
        final receivedDate = DateTime(
          inboundOn.year,
          inboundOn.month,
          inboundOn.day,
        );

        final expiryDate = DateTime(
          expiresOn.year,
          expiresOn.month,
          expiresOn.day,
        );

        if (expiryDate.isBefore(receivedDate)) {
          throw Exception('사용기한은 입고일보다 빠를 수 없습니다.');
        }
      }

      // FastAPI 요청 Model 생성
      final request = InboundCreateRequest(
        purchaseOrderId: purchaseOrderId.trim(),
        employeeId: employeeId,
        inboundQuantity: inboundQuantity,
        inboundOn: inboundOn,
        expiresOn: expiresOn,
      );

      // 입고 등록 API 호출
      final inboundService = ref.read(inboundServiceProvider);

      final result = await inboundService.createInbound(
        request: request,
        accessToken: accessToken,
      );

      // 성공 결과 저장
      state = state.copyWith(
        inboundResult: result,
        isProcessing: false,
        clearErrorMessage: true,
      );

      return true;
    } catch (e) {
      // 오류 저장
      state = state.copyWith(
        isProcessing: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );

      return false;
    }
  }

  // 입고 결과 및 오류 초기화
  void clearInboundResult() {
    state = state.copyWith(clearInboundResult: true, clearErrorMessage: true);
  }
}
