import 'package:flutter_riverpod/flutter_riverpod.dart';

class PickupQueryNotifier extends Notifier<String> {
  @override
  String build() => '';
  void change(String query) => state = query.trim().toLowerCase();
}

final pickupQueryProvider =
    NotifierProvider.autoDispose<PickupQueryNotifier, String>(
      PickupQueryNotifier.new,
    );
