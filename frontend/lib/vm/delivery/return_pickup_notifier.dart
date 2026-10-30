import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/carrier_auth_notifier.dart';
import 'delivery_notifier.dart';
import 'return_pickup_state.dart';

final returnPickupProvider =
    NotifierProvider.autoDispose<ReturnPickupNotifier, ReturnPickupState>(
      ReturnPickupNotifier.new,
    );

class ReturnPickupNotifier extends Notifier<ReturnPickupState> {
  @override
  ReturnPickupState build() {
    ref.watch(carrierAuthProvider);
    Future.microtask(() {
      if (ref.mounted) fetchPickups();
    });
    return ReturnPickupState();
  }

  String get _token {
    final token = ref.read(carrierAuthProvider).accessToken;
    if (token == null || token.isEmpty) {
      throw Exception('배송업체 로그인이 필요합니다.');
    }
    return token;
  }

  void changeFilter(String filter) {
    if ({'ALL', 'SCHEDULED', 'COLLECTED'}.contains(filter)) {
      state = state.copyWith(selectedFilter: filter);
    }
  }

  Future<void> fetchPickups() async {
    if (state.isLoading || state.isProcessing) return;
    state = state.copyWith(isLoading: true, clearMessages: true);
    try {
      final pickups = await ref
          .read(deliveryServiceProvider)
          .fetchReturnPickups(accessToken: _token);
      if (ref.mounted) {
        state = state.copyWith(pickups: pickups, isLoading: false);
      }
    } catch (e) {
      if (ref.mounted) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: e.toString().replaceFirst('Exception: ', ''),
        );
      }
    }
  }

  Future<void> completePickup(String returnId) async {
    if (state.isLoading ||
        state.isProcessing ||
        !state.pickups.any((p) => p.returnId == returnId && p.canComplete)) {
      return;
    }
    state = state.copyWith(isProcessing: true, clearMessages: true);
    var completed = false;
    try {
      final service = ref.read(deliveryServiceProvider);
      final token = _token;
      await service.completeReturnPickup(
        accessToken: token,
        returnId: returnId,
      );
      completed = true;
      final pickups = await service.fetchReturnPickups(accessToken: token);
      if (ref.mounted) {
        state = state.copyWith(
          pickups: pickups,
          isProcessing: false,
          successMessage: '수거 완료 처리되었습니다.',
        );
      }
    } catch (e) {
      if (ref.mounted) {
        state = state.copyWith(
          isProcessing: false,
          pickups: completed ? [] : null,
          errorMessage: completed
              ? '수거 완료는 저장되었으나 목록 갱신에 실패했습니다. 새로고침해 주세요.'
              : e.toString().replaceFirst('Exception: ', ''),
        );
      }
    }
  }
}
