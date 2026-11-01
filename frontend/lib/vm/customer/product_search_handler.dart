// 기능: 중복을 정리한 최근 상품 검색어.
// 상태 계층: 변경은 Notifier/AsyncNotifier에서 발행하고 View는 watch, 동작은 read로 연결한다.

import 'package:flutter_riverpod/flutter_riverpod.dart';

class RecentProductSearches extends Notifier<List<String>> {
  /// Function: Provider가 처음 구독될 때 초기 상태 또는 초기 조회 결과를 준비한다.
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
