import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:beauty_project/model/customer/customers.dart';
import 'package:beauty_project/service/customer/customer_auth_service.dart';
import '../customer_providers.dart';

// 로그인 상태와 전체 고객 목록을 분리한다. 로그인 화면에서는 이 목록을 조회하지 않는다.
class CustomerListModel extends AsyncNotifier<List<Customers>> {
  // 새로고침 실패 시에도 마지막으로 확인한 목록을 별도로 보존한다.
  List<Customers> _customers = const [];
  List<Customers> get customers => _customers;

  @override
  Future<List<Customers>> build() async {
    final customers = await ref.watch(customerServiceProvider).fetchCustomers();
    if (ref.mounted) _customers = List.unmodifiable(customers);
    return customers;
  }

  Future<void> refreshCustomers() async {
    if (state.isLoading) return;
    final service = ref.read(customerServiceProvider);
    state = const AsyncLoading();
    final result = await AsyncValue.guard(service.fetchCustomers);
    if (!ref.mounted) return;
    if (!result.hasError) _customers = List.unmodifiable(result.requireValue);
    state = result;
  }

  Future<String> insertCustomer(Customers customer) =>
      _mutate(() => ref.read(customerServiceProvider).insertCustomer(customer));

  Future<String> updateCustomer(Customers customer) =>
      _mutate(() => ref.read(customerServiceProvider).updateCustomer(customer));

  Future<String> deleteCustomer(String customerId) => _mutate(
    () => ref.read(customerServiceProvider).deleteCustomer(customerId),
  );

  Future<String> _mutate(Future<void> Function() action) async {
    if (state.isLoading) return 'BUSY';
    final service = ref.read(customerServiceProvider);
    state = const AsyncLoading();
    final changed = await AsyncValue.guard(action);
    if (!ref.mounted) return changed.hasError ? 'ERROR' : 'OK';
    if (changed.hasError) {
      state = AsyncError(changed.error!, changed.stackTrace!);
      return 'ERROR';
    }
    final refreshed = await AsyncValue.guard(service.fetchCustomers);
    if (!ref.mounted) return 'OK';
    if (refreshed.hasError) {
      state = AsyncError<List<Customers>>(
        CustomerAuthException(
          '요청은 완료되었지만 목록을 새로 불러오지 못했습니다. ${refreshed.error}',
        ),
        refreshed.stackTrace!,
      );
    } else {
      _customers = List.unmodifiable(refreshed.requireValue);
      state = refreshed;
    }
    return 'OK';
  }
}

final customerListModelProvider =
    AsyncNotifierProvider<CustomerListModel, List<Customers>>(
      CustomerListModel.new,
      // 오류는 화면에 표시하고 사용자가 새로고침할 때 다시 요청한다.
      retry: (_, _) => null,
    );
