import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:typed_data';

import '../../service/admin/management_service.dart';
import '../auth/api_client_provider.dart';
import '../auth/auth_notifier.dart';
import '../staff/staff_inventory_vm.dart';
import 'return_management_state.dart';
import '../common/storage_image_handler.dart';

final managementServiceProvider = Provider<ManagementService>(
  (ref) => ManagementService(ref.watch(apiClientProvider)),
);

final returnListProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>(
      (ref) => ref.watch(managementServiceProvider).getReturns(),
      retry: (_, _) => null,
    );

final returnManagementProvider =
    NotifierProvider.autoDispose<
      ReturnManagementNotifier,
      ReturnManagementState
    >(ReturnManagementNotifier.new);

class ReturnManagementNotifier extends Notifier<ReturnManagementState> {
  @override
  ReturnManagementState build() => const ReturnManagementState();

  void changeStatus(String status) {
    if (!state.isProcessing &&
        const {
          'ALL',
          'REQUESTED',
          'APPROVED',
          'REJECTED',
          'COLLECTING',
          'INSPECTING',
          'COMPLETED',
        }.contains(status)) {
      state = state.copyWith(selectedStatus: status);
    }
  }

  Future<void> updateRefundStatus({
    required String returnId,
    required String expectedStatus,
    required String refundStatus,
  }) async {
    if (state.isProcessing || ref.read(managementActionsProvider)) return;
    state = state.copyWith(processingReturnId: returnId, clearMessages: true);
    var saved = false;
    try {
      final auth = ref.read(authProvider);
      if (!auth.isAdmin || auth.employee == null) {
        throw Exception('환불 상태 관리는 본사 관리자만 가능합니다.');
      }
      final result = await ref
          .read(managementServiceProvider)
          .updateRefundStatus(
            returnId: returnId,
            employeeId: auth.employee!.employeeId,
            expectedStatus: expectedStatus,
            refundStatus: refundStatus,
          );
      saved = true;
      if (!ref.mounted) return;
      final refreshed = ref.refresh(returnListProvider.future);
      await refreshed;
      if (!ref.mounted) return;
      state = state.copyWith(
        clearProcessing: true,
        successMessage: result['message'] as String,
      );
    } catch (error) {
      if (!ref.mounted) return;
      state = state.copyWith(
        clearProcessing: true,
        errorMessage: saved
            ? '내부 상태는 저장되었으나 목록 갱신에 실패했습니다. 새로고침해 주세요.'
            : '${error.toString().replaceFirst('Exception: ', '')} 결과가 불확실하면 새로고침 후 확인해 주세요.',
      );
      // 네트워크 단절 시 서버가 저장했을 수 있으므로 자동 재전송하지 않는다.
      if (!saved) ref.invalidate(returnListProvider);
    }
  }
}

final carrierChoicesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>(
      (ref) => ref.watch(managementServiceProvider).getCarriers(),
    );

final categoryChoicesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>(
      (ref) => ref.watch(managementServiceProvider).getCategories(),
    );

final cosmeticDetailsProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>(
      (ref, cosmeticId) =>
          ref.watch(managementServiceProvider).getCosmeticDetails(cosmeticId),
    );

final cosmeticImageProvider = FutureProvider.family<String?, String>(
  (ref, cosmeticId) =>
      ref.watch(managementServiceProvider).getCosmeticImage(cosmeticId),
);

class CosmeticImagesRevision extends Notifier<int> {
  @override
  int build() => 0;
  void refresh() => state++;
}

final cosmeticImagesRevisionProvider =
    NotifierProvider<CosmeticImagesRevision, int>(CosmeticImagesRevision.new);

class ManagementActions extends Notifier<bool> {
  @override
  bool build() => false;

  String get _employeeId {
    final auth = ref.read(authProvider);
    if ((!auth.isAdmin && !auth.isStaff) || auth.employee == null) {
      throw Exception('직원 또는 관리자 로그인이 필요합니다.');
    }
    return auth.employee!.employeeId;
  }

  Future<void> returnAction(
    String id,
    String action,
    String method, [
    Map<String, dynamic> extra = const {},
  ]) async {
    if (state) return;
    state = true;
    try {
      await ref.read(managementServiceProvider).returnAction(
        id,
        action,
        method,
        {'employee_id': _employeeId, ...extra},
      );
      ref.invalidate(returnListProvider);
    } finally {
      state = false;
    }
  }

  Future<Map<String, dynamic>> createCosmetic(Map<String, dynamic> data) async {
    if (!ref.read(authProvider).isAdmin) {
      throw Exception('상품 등록은 관리자만 가능합니다.');
    }
    if (state) throw Exception('이미 처리 중입니다.');
    state = true;
    try {
      return await ref.read(managementServiceProvider).createCosmetic({
        ...data,
        'employee_id': _employeeId,
      });
    } finally {
      state = false;
    }
  }

  Future<void> changeSaleStatus(String cosmeticId, String status) async {
    if (!ref.read(authProvider).isAdmin) throw Exception('관리자 권한이 필요합니다.');
    if (state) return;
    state = true;
    try {
      await ref
          .read(managementServiceProvider)
          .changeSaleStatus(cosmeticId, status);
      ref.invalidate(cosmeticOptionsProvider);
    } finally {
      state = false;
    }
  }

  Future<void> updateCosmeticDetails(
    String cosmeticId,
    Map<String, dynamic> data,
  ) async {
    if (!ref.read(authProvider).isAdmin) throw Exception('관리자 권한이 필요합니다.');
    if (state) throw Exception('이미 처리 중입니다.');
    state = true;
    try {
      await ref
          .read(managementServiceProvider)
          .updateCosmeticDetails(cosmeticId, data);
      ref.invalidate(cosmeticOptionsProvider);
    } finally {
      state = false;
    }
  }

  Future<void> uploadCosmeticImage(
    String cosmeticId,
    Uint8List bytes,
    String filename,
  ) async {
    if (!ref.read(authProvider).isAdmin) throw Exception('관리자 권한이 필요합니다.');
    if (state) throw Exception('이미 처리 중입니다.');
    state = true;
    try {
      await ref
          .read(managementServiceProvider)
          .uploadCosmeticImage(cosmeticId, bytes, filename);
      ref.invalidate(cosmeticImageProvider(cosmeticId));
      ref.invalidate(storageImagesProvider);
      ref.read(cosmeticImagesRevisionProvider.notifier).refresh();
      ref.invalidate(distinctCosmeticsPageProvider);
    } finally {
      state = false;
    }
  }
}

final managementActionsProvider = NotifierProvider<ManagementActions, bool>(
  ManagementActions.new,
);

// 변경 내용(2026-10-30): 관리자 이미지 업로드 성공 후 공용 Firebase 목록과 이미지 표시를 갱신한다.
