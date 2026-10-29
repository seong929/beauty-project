import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:typed_data';

import '../../service/admin/management_service.dart';
import '../auth/api_client_provider.dart';
import '../auth/auth_notifier.dart';
import '../staff/staff_inventory_vm.dart';

final managementServiceProvider = Provider<ManagementService>(
  (ref) => ManagementService(ref.watch(apiClientProvider)),
);

final returnListProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>(
      (ref) => ref.watch(managementServiceProvider).getReturns(),
    );

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
