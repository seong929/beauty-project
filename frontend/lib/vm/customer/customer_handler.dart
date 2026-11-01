// 기능: 로그인한 고객·로그인 요청·프로필·탈퇴 관리.
// 상태 계층: 변경은 Notifier/AsyncNotifier에서 발행하고 View는 watch, 동작은 read로 연결한다.

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
  /// Function: Provider가 처음 구독될 때 초기 상태 또는 초기 조회 결과를 준비한다.
  @override
  FutureOr<Customers?> build() => null;

  /// Function: 로그인 요청을 AsyncValue로 감싸 로딩·고객 정보·실패를 구분한다.
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

  /// Function: 회원 정보 저장 후 현재 로그인 고객이 같을 때만 프로필을 갱신한다.
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

  /// Function: 서버가 확인한 포인트 잔액으로 로그인 고객 정보의 새 객체를 만든다.
  void updatePointsBalance(int balance) {
    final customer = state.value;
    if (customer != null && balance >= 0) {
      state = AsyncData(
        Customers.fromJson({...customer.toJson(), 'points_balance': balance}),
      );
    }
  }

  /// Function: 로그인한 고객의 탈퇴 요청을 처리한다.
  Future<void> withdraw() async {
    final customer = state.value;
    if (customer == null) throw const CustomerAuthException('다시 로그인해 주세요.');
    await ref.read(customerServiceProvider).deleteCustomer(customer.customerId);
    if (ref.mounted && state.value?.customerId == customer.customerId) logout();
  }

  /// Function: 고객 로그인 상태와 고객별 장바구니·최근 검색 상태를 초기화한다.
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
