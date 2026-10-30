import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@immutable
class OperationsReturnFilters {
  final String query, pickup, refund;
  const OperationsReturnFilters({
    this.query = '',
    this.pickup = 'ALL',
    this.refund = 'ALL',
  });
  OperationsReturnFilters copyWith({
    String? query,
    String? pickup,
    String? refund,
  }) => OperationsReturnFilters(
    query: query ?? this.query,
    pickup: pickup ?? this.pickup,
    refund: refund ?? this.refund,
  );
  bool matches(Map<String, dynamic> row) =>
      (pickup == 'ALL' || row['pickup_status'] == pickup) &&
      (refund == 'ALL' || row['refund_status'] == refund) &&
      [
        row['return_id'],
        row['order_id'],
        row['customer_id'],
        row['order_item_id'],
      ].any(
        (value) =>
            value?.toString().toLowerCase().contains(
              query.trim().toLowerCase(),
            ) ??
            false,
      );
}

class OperationsReturnFiltersNotifier
    extends Notifier<OperationsReturnFilters> {
  @override
  OperationsReturnFilters build() => const OperationsReturnFilters();
  void setQuery(String query) => state = state.copyWith(query: query);
  void setPickup(String pickup) => state = state.copyWith(pickup: pickup);
  void setRefund(String refund) => state = state.copyWith(refund: refund);
}

final operationsReturnFiltersProvider =
    NotifierProvider.autoDispose<
      OperationsReturnFiltersNotifier,
      OperationsReturnFilters
    >(OperationsReturnFiltersNotifier.new);
