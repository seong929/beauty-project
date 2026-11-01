import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beauty_project/vm/customer/state/customer_screen_handler.dart';
import 'package:beauty_project/vm/customer/state/product_filter_draft_handler.dart';
import 'package:beauty_project/vm/customer/product_handler.dart';

void main() {
  late ProviderContainer container;
  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  test('form changes copy state and two screen instances stay independent', () {
    final first = customerAuthFormProvider(Object());
    final second = customerAuthFormProvider(Object());
    final before = container.read(first);
    final actions = container.read(first.notifier);
    actions.togglePassword();
    actions.selectGender('F');
    actions.attemptSubmit();
    expect(before.showPassword, isFalse);
    expect(before.gender, 'UNDISCLOSED');
    expect(container.read(first).showPassword, isTrue);
    expect(container.read(first).gender, 'F');
    expect(container.read(second).showPassword, isFalse);
    expect(container.read(second).attemptedSubmit, isFalse);
  });

  test(
    'closing a screen disposes its form instead of reusing the old choices',
    () async {
      final provider = customerAuthFormProvider(Object());
      final subscription = container.listen(provider, (_, _) {});
      container.read(provider.notifier).togglePassword();
      subscription.close();
      await container.pump();
      expect(container.read(provider).showPassword, isFalse);
      expect(container.read(provider).attemptedSubmit, isFalse);
    },
  );

  test(
    'operation locks and errors are scoped by both screen and operation',
    () {
      final owner = Object();
      final pay = customerOperationProvider((screen: owner, action: 'pay'));
      final address = customerOperationProvider((
        screen: owner,
        action: 'address',
      ));
      final initial = container.read(pay);
      final actions = container.read(pay.notifier);
      actions.begin();
      actions.fail('failed');
      actions.finish();
      expect(initial.isLoading, isFalse);
      expect(initial.error, isNull);
      expect(container.read(pay).error, 'failed');
      expect(container.read(address).isLoading, isFalse);
      expect(container.read(address).error, isNull);
      actions.begin();
      expect(container.read(pay).error, isNull);
    },
  );

  test(
    'review editing preserves earlier snapshots and rejects invalid stars',
    () {
      final key = (screen: Object(), rating: 3, content: 'before');
      final provider = customerReviewDraftProvider(key);
      final initial = container.read(provider);
      final actions = container.read(provider.notifier);
      actions.rate(5);
      actions.editContent('after');
      actions.rate(6);
      expect(initial.rating, 3);
      expect(initial.content, 'before');
      expect(container.read(provider).rating, 5);
      expect(container.read(provider).content, 'after');
    },
  );

  test('changing the returned item or reason requires confirmation again', () {
    final provider = customerReturnDraftProvider(Object());
    final actions = container.read(provider.notifier);
    actions.selectItem('line1');
    actions.selectReason('damaged');
    actions.confirm(true);
    final previous = container.read(provider);
    actions.selectItem('line2');
    expect(previous.confirmed, isTrue);
    expect(previous.itemId, 'line1');
    expect(container.read(provider).confirmed, isFalse);
    actions.confirm(true);
    actions.selectReason(null);
    expect(container.read(provider).reason, isNull);
    expect(container.read(provider).confirmed, isFalse);
  });

  test(
    'nullable shipment choices can be cleared without changing another view',
    () {
      final first = deliveryTrackingSelectionProvider((
        screen: Object(),
        initial: 'delivery1',
      ));
      final second = deliveryTrackingSelectionProvider((
        screen: Object(),
        initial: 'delivery2',
      ));
      container.read(first.notifier).select(null);
      expect(container.read(first).value, isNull);
      expect(container.read(second).value, 'delivery2');
    },
  );

  test(
    'filter drafts do not alter committed filters and reset only the draft',
    () {
      final active = container.read(productFilterProvider);
      final provider = productFilterDraftProvider((
        screen: Object(),
        initial: active,
      ));
      final actions = container.read(provider.notifier);
      actions.selectCategory('크림');
      actions.stockOnly(true);
      actions.sort(ProductSort.ratingHigh);
      expect(container.read(productFilterProvider).category, '전체');
      expect(active.sort, ProductSort.recommended);
      expect(container.read(provider).category, '크림');
      expect(container.read(provider).sort, ProductSort.ratingHigh);
      actions.reset();
      expect(container.read(provider).category, '전체');
      expect(container.read(provider).inStockOnly, isFalse);
      expect(container.read(productFilterProvider).category, '전체');
    },
  );

  test(
    'postal search retry clears errors and records result delivery once',
    () {
      final provider = customerPostalSearchProvider((
        screen: Object(),
        supported: true,
      ));
      final actions = container.read(provider.notifier);
      actions.fail('offline');
      expect(container.read(provider).loading, isFalse);
      actions.start();
      expect(container.read(provider).loading, isTrue);
      expect(container.read(provider).error, isNull);
      actions.ready();
      actions.returned();
      expect(container.read(provider).returned, isTrue);
      expect(container.read(provider).loading, isFalse);
    },
  );
}
