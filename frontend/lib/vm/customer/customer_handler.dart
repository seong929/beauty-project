import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:beauty_project/model/customer/customers.dart';
import 'package:beauty_project/service/customer/customer_auth_service.dart';
import 'customer_providers.dart';
import 'cart_handler.dart';
import 'cart_persistence_handler.dart';
import 'product_search_handler.dart';

// 첨부 Riverpod 예제처럼 AsyncValue가 로딩·성공·실패 상태를 관리한다.
// data(null): 비로그인, data(Customers): 로그인한 고객 정보.
class CustomerHandler extends AsyncNotifier<Customers?> {
  @override
  FutureOr<Customers?> build() => null;

  Future<bool> login({
    required String loginId,
    required String password,
  }) async {
    if (state.isLoading) return false;
    state = const AsyncLoading();
    final service = ref.read(customerAuthServiceProvider);
    final result = await AsyncValue.guard(() async {
      final customer = await service.login(
        loginId: loginId.trim(),
        password: password,
      );
      if (customer.customerId.trim().isEmpty ||
          customer.loginId != loginId.trim()) {
        throw const CustomerAuthException('로그인한 고객 정보를 확인할 수 없습니다.');
      }
      // 비밀번호를 로그인 상태에 보관하지 않는다.
      return Customers.fromJson(customer.toJson());
    });
    if (!ref.mounted) return false;
    state = result;
    return !result.hasError;
  }

  void clearError() {
    if (!state.isLoading && state.hasError) state = const AsyncData(null);
  }

  Future<void> updateProfile({
    required String name,
    required String email,
    required String phone,
    required String address,
    String? gender,
    bool updateDemographics = false,
  }) async {
    final customer = state.value;
    if (customer == null) throw const CustomerAuthException('다시 로그인해 주세요.');
    final updated = Customers.fromJson({
      ...customer.toJson(),
      'customer_name': name.trim(),
      'email': email.trim(),
      'phone': phone.trim(),
      'address': address.trim(),
      if (updateDemographics) 'gender': gender ?? 'UNDISCLOSED',
    });
    await ref.read(customerServiceProvider).updateCustomer(updated);
    if (!ref.mounted || state.value?.customerId != customer.customerId) return;
    state = AsyncData(
      Customers.fromJson({
        ...state.value!.toJson(),
        'customer_name': updated.name,
        'email': updated.email,
        'phone': updated.phone,
        'address': updated.address,
        'gender': updated.gender,
      }),
    );
  }

  void updatePointsBalance(int balance) {
    final customer = state.value;
    if (customer != null && balance >= 0) {
      state = AsyncData(
        Customers.fromJson({...customer.toJson(), 'points_balance': balance}),
      );
    }
  }

  Future<void> withdraw() async {
    final customer = state.value;
    if (customer == null) throw const CustomerAuthException('다시 로그인해 주세요.');
    await ref.read(customerServiceProvider).deleteCustomer(customer.customerId);
    if (ref.mounted && state.value?.customerId == customer.customerId) logout();
  }

  void logout() {
    if (!state.isLoading) {
      state = const AsyncData(null);
      ref.invalidate(cartHandlerProvider);
      ref.invalidate(cartPersistenceProvider);
      ref.invalidate(recentProductSearchesProvider);
    }
  }
}

final customerHandlerProvider =
    AsyncNotifierProvider<CustomerHandler, Customers?>(CustomerHandler.new);

// 변경 내용(2026-10-30): 인구통계 수정 값을 저장하고 삭제된 찜 상태 초기화는 제거한다.
