import 'package:beauty_project/model/delivery/return_pickup.dart';
import 'package:beauty_project/model/auth/carrier_login.dart';
import 'package:beauty_project/service/delivery/delivery_service.dart';
import 'package:beauty_project/view/delivery/return_pickup_page.dart';
import 'package:beauty_project/vm/delivery/delivery_notifier.dart';
import 'package:beauty_project/vm/delivery/return_pickup_notifier.dart';
import 'package:beauty_project/vm/delivery/return_pickup_state.dart';
import 'package:beauty_project/vm/auth/carrier_auth_notifier.dart';
import 'package:beauty_project/vm/auth/carrier_auth_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ReturnPickup pickup(String status) => ReturnPickup.fromJson({
  'return_id': 'ret_1',
  'order_id': 'ord_1',
  'order_item_id': 'oi_1',
  'shipping_address': 'Seoul',
  'return_reason': 'Damaged',
  'return_quantity': 2,
  'return_status': 'COLLECTING',
  'pickup_status': status,
  'requested_on': '2026-10-29',
  'pickup_requested_on': '2026-10-30',
  'pickup_completed_on': status == 'COLLECTED' ? '2026-10-30' : null,
});

class FakeAuth extends CarrierAuthNotifier {
  @override
  CarrierAuthState build() => const CarrierAuthState(
    carrier: CarrierLogin(
      accessToken: 'token',
      tokenType: 'bearer',
      expiresIn: 3600,
      accountId: 'ca_1',
      carrierId: 'car_1',
    ),
  );
}

class FakeService extends DeliveryService {
  FakeService() : super(baseUrl: 'http://localhost');
  String status = 'SCHEDULED';
  int reads = 0;
  @override
  Future<List<ReturnPickup>> fetchReturnPickups({
    required String accessToken,
  }) async {
    reads++;
    return [pickup(status)];
  }

  @override
  Future<void> completeReturnPickup({
    required String accessToken,
    required String returnId,
  }) async {
    status = 'COLLECTED';
  }
}

class FakeNotifier extends ReturnPickupNotifier {
  @override
  ReturnPickupState build() =>
      ReturnPickupState(pickups: [pickup('SCHEDULED')]);
}

void main() {
  test(
    'notifier loads, completes, reloads and preserves server state',
    () async {
      final service = FakeService();
      final container = ProviderContainer(
        overrides: [
          deliveryServiceProvider.overrideWithValue(service),
          carrierAuthProvider.overrideWith(FakeAuth.new),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(returnPickupProvider, (_, next) {});
      addTearDown(subscription.close);
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(returnPickupProvider).pickups.single.pickupStatus,
        'SCHEDULED',
      );
      final notifier = container.read(returnPickupProvider.notifier);
      await notifier.completePickup('ret_1');
      expect(service.reads, 2);
      expect(
        container.read(returnPickupProvider).pickups.single.pickupStatus,
        'COLLECTED',
      );
      await notifier.fetchPickups();
      expect(
        container.read(returnPickupProvider).pickups.single.pickupStatus,
        'COLLECTED',
      );
      await notifier.completePickup('ret_1');
      expect(service.reads, 3);
    },
  );
  test('JSON dates, eligibility, immutable list and filter copy', () {
    final source = [pickup('SCHEDULED')];
    final state = ReturnPickupState(pickups: source);
    source.clear();
    expect(state.pickups.single.canComplete, true);
    expect(state.pickups.single.pickupCompletedOn, isNull);
    expect(() => state.pickups.clear(), throwsUnsupportedError);
    expect(
      state.copyWith(selectedFilter: 'COLLECTED').filteredPickups,
      isEmpty,
    );
    expect(pickup('COLLECTED').canComplete, false);
    expect(
      state
          .copyWith(errorMessage: 'error')
          .copyWith(clearMessages: true)
          .errorMessage,
      isNull,
    );
  });
  testWidgets('page renders real model and filters', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [returnPickupProvider.overrideWith(FakeNotifier.new)],
        child: const MaterialApp(home: ReturnPickupPage()),
      ),
    );
    expect(find.text('ret_1'), findsOneWidget);
    await tester.tap(find.byType(ChoiceChip).last);
    await tester.pumpAndSettle();
    expect(find.text('ret_1'), findsNothing);
    await tester.tap(find.byType(ChoiceChip).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('ret_1'));
    await tester.pumpAndSettle();
    // The collection address is visible in both the summary and selected details.
    expect(find.textContaining('Seoul'), findsNWidgets(2));
    expect(find.byType(FilledButton), findsOneWidget);
  });
}
