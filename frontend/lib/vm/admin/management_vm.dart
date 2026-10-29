import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../service/admin/management_service.dart';
import '../auth/api_client_provider.dart';
import '../auth/auth_notifier.dart';

final managementServiceProvider = Provider<ManagementService>(
  (ref) => ManagementService(ref.watch(apiClientProvider)),
);

final returnListProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>(
      (ref) => ref.watch(managementServiceProvider).getReturns(),
    );

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
}

final managementActionsProvider = NotifierProvider<ManagementActions, bool>(
  ManagementActions.new,
);
