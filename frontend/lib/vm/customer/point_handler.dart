// 기능: 고객 포인트 조회와 적립 예상액 계산.
// 상태 계층: 변경은 Notifier/AsyncNotifier에서 발행하고 View는 watch, 동작은 read로 연결한다.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beauty_project/model/customer/point_account.dart';
import 'package:beauty_project/service/customer/customer_point_service.dart';
import 'customer_handler.dart';
import 'customer_providers.dart';

final customerPointServiceProvider = Provider<CustomerPointService>(
  (ref) => CustomerPointService(
    client: ref.watch(customerHttpClientProvider),
    baseUrl: ref.watch(customerApiBaseUrlProvider),
  ),
);

final customerPointsProvider = FutureProvider<CustomerPointAccount>((ref) {
  final id = ref.watch(
    customerHandlerProvider.select((session) => session.value?.customerId),
  );
  if (id == null) {
    return Future.value(const CustomerPointAccount(balance: 0, history: []));
  }
  return ref.watch(customerPointServiceProvider).fetch(id);
}, retry: (_, _) => null);

int expectedPurchasePoints(double amount) => (amount * .10).floor();
