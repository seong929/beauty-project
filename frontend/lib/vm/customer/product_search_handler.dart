import 'package:flutter_riverpod/flutter_riverpod.dart';

class RecentProductSearches extends Notifier<List<String>> {
  @override
  List<String> build() => const [];

  void add(String query) {
    final value = query.trim();
    if (value.isEmpty) return;
    state = [value, ...state.where((item) => item != value)].take(5).toList();
  }

  void clear() => state = const [];
}

final recentProductSearchesProvider =
    NotifierProvider<RecentProductSearches, List<String>>(
      RecentProductSearches.new,
    );

// 변경 내용(2026-10-30): 최근 검색만 유지하고 찜 상태·캐시 관리 기능을 제거했다.
