import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum OperationsSection {
  overview,
  inventory,
  orders,
  approvals,
  purchases,
  manufacturers,
  inbound,
  outbound,
  deliveries,
  returns,
}

@immutable
class OperationsWorkspaceState {
  final OperationsSection section;
  const OperationsWorkspaceState({this.section = OperationsSection.overview});
  OperationsWorkspaceState copyWith({OperationsSection? section}) =>
      OperationsWorkspaceState(section: section ?? this.section);
}

class OperationsWorkspaceNotifier extends Notifier<OperationsWorkspaceState> {
  @override
  OperationsWorkspaceState build() => const OperationsWorkspaceState();
  void select(OperationsSection section) =>
      state = state.copyWith(section: section);
}

final operationsWorkspaceProvider =
    NotifierProvider.autoDispose<
      OperationsWorkspaceNotifier,
      OperationsWorkspaceState
    >(OperationsWorkspaceNotifier.new);
