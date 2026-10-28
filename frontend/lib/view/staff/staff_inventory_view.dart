import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../model/staff/staff_cosmetic.dart';
import '../../model/staff/staff_product_inventory.dart';
import '../../model/staff/staff_inventory_status.dart';
import '../../vm/staff/staff_inventory_vm.dart';

/// 태블릿 / 휴대폰 공용 재고 화면.
/// 화면의 넓이에 따라 정보 밀도만 변경하며 API, 인증, 지연 조회 로직은 변경하지 않습니다.
class StaffInventoryView extends ConsumerWidget {
  const StaffInventoryView({super.key});

  static const double _tabletBreakpoint = 680;
  static const double _maxContentWidth = 1120;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isTablet = MediaQuery.sizeOf(context).width >= _tabletBreakpoint;
    final mode = ref.watch(staffInventoryDisplayProvider);
    final statusMode = mode == StaffInventoryDisplayMode.status;
    final descending = ref.watch(staffInventoryStatusDescendingProvider);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: isTablet ? 72 : 56,
        titleSpacing: isTablet ? 32 : 16,
        title: Text(
          '직원 재고 관리',
          style: TextStyle(
            fontSize: isTablet ? 23 : 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          if (statusMode)
            IconButton(
              tooltip: descending ? '현재 내림차순 (오름차순으로 변경)' : '현재 오름차순 (내림차순으로 변경)',
              onPressed: () => ref
                  .read(staffInventoryStatusDescendingProvider.notifier)
                  .toggle(),
              icon: Icon(descending ? Icons.south : Icons.north),
            ),
          Padding(
            padding: EdgeInsets.only(right: isTablet ? 32 : 12),
            child: TextButton.icon(
              onPressed: () => ref.read(staffInventoryDisplayProvider.notifier).toggle(),
              icon: const Icon(Icons.swap_horiz),
              label: Text(statusMode ? '화장품별' : '상태별'),
            ),
          ),
        ],
      ),
      // 두 페이지의 provider는 선택된 모드에서만 watch됩니다.
      body: statusMode
          ? const _StatusInventoryPage()
          : const _CosmeticsInventoryPage(),
    );
  }
}

class _CosmeticsInventoryPage extends ConsumerWidget {
  const _CosmeticsInventoryPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(distinctCosmeticsProvider);
    return result.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => _Failed(
        message: '화장품 목록을 불러오지 못했습니다.\n$error',
        onRetry: () => ref.invalidate(distinctCosmeticsProvider),
      ),
      data: (cosmetics) {
        if (cosmetics.isEmpty) {
          return const Center(child: Text('보유중인 화장품이 없습니다'));
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            final tablet = constraints.maxWidth >= StaffInventoryView._tabletBreakpoint;
            final horizontal = tablet ? 32.0 : 12.0;
            final vertical = tablet ? 24.0 : 12.0;
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: StaffInventoryView._maxContentWidth),
                child: Scrollbar(
                  child: ListView.separated(
                    padding: EdgeInsets.fromLTRB(
                      horizontal,
                      vertical,
                      horizontal,
                      vertical + MediaQuery.paddingOf(context).bottom,
                    ),
                    itemCount: cosmetics.length + 1,
                    separatorBuilder: (_, index) => SizedBox(height: tablet ? 12 : 8),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return _ListHeader(total: cosmetics.length, isTablet: tablet);
                      }
                      return _CosmeticRow(
                        cosmetic: cosmetics[index - 1],
                        isTablet: tablet,
                      );
                    },
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ListHeader extends StatelessWidget {
  const _ListHeader({required this.total, required this.isTablet});

  final int total;
  final bool isTablet;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(isTablet ? 4 : 2, 2, 4, isTablet ? 8 : 4),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [
          Text(
            '화장품 목록',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: isTablet ? 22 : 18,
            ),
          ),
          Text(
            '총 $total종 · 항목을 눌러 옵션과 재고 확인',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _CosmeticRow extends ConsumerWidget {
  const _CosmeticRow({required this.cosmetic, required this.isTablet});

  final RootCosmetics cosmetic;
  final bool isTablet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = 'cosmetic:${cosmetic.categoryName}:${cosmetic.name}';
    final expanded = ref.watch(
      inventoryExpansionProvider.select((items) => items.contains(key)),
    );
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isTablet ? 16 : 12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => ref.read(inventoryExpansionProvider.notifier).toggle(key),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 22 : 14,
                vertical: isTablet ? 19 : 13,
              ),
              child: Row(
                children: [
                  Icon(
                    expanded ? Icons.folder_open_outlined : Icons.folder_outlined,
                    size: isTablet ? 29 : 25,
                    color: theme.colorScheme.primary,
                  ),
                  SizedBox(width: isTablet ? 18 : 12),
                  Expanded(
                    child: isTablet
                        ? Row(
                            children: [
                              Expanded(
                                child: Text(
                                  cosmetic.name,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              _CategoryTag(category: cosmetic.categoryName),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                cosmetic.name,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                cosmetic.categoryName,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                  ),
                  SizedBox(width: isTablet ? 16 : 8),
                  Icon(expanded ? Icons.expand_less : Icons.expand_more),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            Divider(height: 1, color: theme.colorScheme.outlineVariant),
            _OptionsBody(cosmeticName: cosmetic.name, isTablet: isTablet),
          ],
        ],
      ),
    );
  }
}

class _CategoryTag extends StatelessWidget {
  const _CategoryTag({required this.category});

  final String category;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        category,
        style: TextStyle(
          color: scheme.onSecondaryContainer,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _OptionsBody extends ConsumerWidget {
  const _OptionsBody({required this.cosmeticName, required this.isTablet});

  final String cosmeticName;
  final bool isTablet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(cosmeticOptionsProvider(cosmeticName));
    final theme = Theme.of(context);

    return Container(
      color: theme.colorScheme.surfaceContainerLowest,
      padding: EdgeInsets.fromLTRB(
        isTablet ? 32 : 12,
        isTablet ? 16 : 8,
        isTablet ? 22 : 12,
        isTablet ? 18 : 10,
      ),
      child: result.when(
        loading: () => const _LoadingRow(),
        error: (error, stack) => _Failed(
          message: '옵션 조회 실패\n$error',
          onRetry: () => ref.invalidate(cosmeticOptionsProvider(cosmeticName)),
        ),
        data: (options) => options.isEmpty
            ? const _EmptyRow('보유중인 옵션이 없습니다')
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isTablet)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                      child: Text(
                        '옵션 ${options.length}개',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  for (var i = 0; i < options.length; i++) ...[
                    if (i > 0) SizedBox(height: isTablet ? 10 : 6),
                    _OptionRow(option: options[i], isTablet: isTablet),
                  ],
                ],
              ),
      ),
    );
  }
}

class _OptionRow extends ConsumerWidget {
  const _OptionRow({required this.option, required this.isTablet});

  final OptionCosmetics option;
  final bool isTablet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = 'option:${option.cosmeticId}';
    final expanded = ref.watch(
      inventoryExpansionProvider.select((items) => items.contains(key)),
    );
    final theme = Theme.of(context);
    final title = option.volumeText?.isNotEmpty == true
        ? option.volumeText!
        : option.cosmeticId;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () => ref.read(inventoryExpansionProvider.notifier).toggle(key),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 18 : 12,
                vertical: isTablet ? 17 : 12,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: isTablet ? 25 : 22,
                    color: theme.colorScheme.secondary,
                  ),
                  SizedBox(width: isTablet ? 14 : 10),
                  Expanded(
                    child: isTablet
                        ? Row(
                            children: [
                              Expanded(
                                flex: 4,
                                child: _OptionTitle(title: title, id: option.cosmeticId),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: _InfoCell(label: '판매가', value: '${_formatNumber(option.salePrice)}원'),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: _InfoCell(label: '최소 재고', value: '${_formatNumber(option.minStock)}개'),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: _InfoCell(label: '목표 재고', value: '${_formatNumber(option.targetStock)}개'),
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _OptionTitle(title: title, id: option.cosmeticId),
                              const SizedBox(height: 8),
                              Text(
                                '${_formatNumber(option.salePrice)}원 · 최소 ${option.minStock} / 목표 ${option.targetStock}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                  ),
                  SizedBox(width: isTablet ? 12 : 6),
                  Icon(expanded ? Icons.expand_less : Icons.expand_more),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            Divider(height: 1, color: theme.colorScheme.outlineVariant),
            _InventoryBody(cosmeticId: option.cosmeticId, isTablet: isTablet),
          ],
        ],
      ),
    );
  }
}

class _OptionTitle extends StatelessWidget {
  const _OptionTitle({required this.title, required this.id});

  final String title;
  final String id;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        if (title != id) ...[
          const SizedBox(height: 3),
          Text(
            id,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _InventoryBody extends ConsumerWidget {
  const _InventoryBody({required this.cosmeticId, required this.isTablet});

  final String cosmeticId;
  final bool isTablet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(cosmeticInventoryProvider(cosmeticId));
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      color: theme.colorScheme.surfaceContainerLow,
      padding: EdgeInsets.fromLTRB(
        isTablet ? 20 : 10,
        isTablet ? 12 : 6,
        isTablet ? 18 : 10,
        isTablet ? 12 : 8,
      ),
      child: result.when(
        loading: () => const _LoadingRow(),
        error: (error, stack) => _Failed(
          message: '재고 조회 실패\n$error',
          onRetry: () => ref.invalidate(cosmeticInventoryProvider(cosmeticId)),
        ),
        data: (inventory) => inventory.isEmpty
            ? const _EmptyRow('보유중인 재고가 없습니다')
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isTablet)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 2, 8, 10),
                      child: Text(
                        '입고 재고 ${inventory.length}건',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  for (var i = 0; i < inventory.length; i++) ...[
                    if (i > 0) const Divider(height: 16),
                    _InventoryRow(batch: inventory[i], isTablet: isTablet),
                  ],
                ],
              ),
      ),
    );
  }
}

class _InventoryRow extends StatelessWidget {
  const _InventoryRow({required this.batch, required this.isTablet});

  final StaffProductInventory batch;
  final bool isTablet;

  static String _date(DateTime? date) => date == null
      ? '미설정'
      : '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final id = batch.inventoryId;
    final quantity = '${_formatNumber(batch.stockQuantity)}개';

    if (!isTablet) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.layers_outlined, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$id · $quantity', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 5),
                  Text(
                    '${batch.inventoryStatus.name} / ${batch.saleOption.name}\n'
                    '입고 ${_date(batch.receivedOn)} · 만료 ${_date(batch.expiresOn)}',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: Row(
        children: [
          Icon(Icons.layers_outlined, size: 22, color: theme.colorScheme.secondary),
          const SizedBox(width: 12),
          Expanded(flex: 4, child: _InfoCell(label: '재고 번호', value: id)),
          const SizedBox(width: 12),
          Expanded(flex: 2, child: _InfoCell(label: '수량', value: quantity)),
          const SizedBox(width: 12),
          Expanded(flex: 3, child: _InfoCell(label: '상태', value: '${batch.inventoryStatus.name} / ${batch.saleOption.name}')),
          const SizedBox(width: 12),
          Expanded(flex: 3, child: _InfoCell(label: '입고일', value: _date(batch.receivedOn))),
          const SizedBox(width: 12),
          Expanded(flex: 3, child: _InfoCell(label: '유통기한', value: _date(batch.expiresOn))),
        ],
      ),
    );
  }
}

/// 상태별 목록은 단일 FastAPI API로 전체 상태를 가져옵니다.
/// DISCARD를 처음부터 볼 수 있도록 기본 정렬은 내림차순입니다.
class _StatusInventoryPage extends ConsumerWidget {
  const _StatusInventoryPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(inventoryStatusOverviewProvider);
    final descending = ref.watch(staffInventoryStatusDescendingProvider);

    return result.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => _Failed(
        message: '재고 상태별 목록을 불러오지 못했습니다.\n$error',
        onRetry: () => ref.invalidate(inventoryStatusOverviewProvider),
      ),
      data: (overview) => LayoutBuilder(
        builder: (context, constraints) {
          final tablet = constraints.maxWidth >= StaffInventoryView._tabletBreakpoint;
          final statuses = <InventoryStatus>[
            InventoryStatus.DISCARD,
            InventoryStatus.HOLD,
            InventoryStatus.MAINTAIN,
          ];
          final orderedStatuses =
              descending ? statuses : statuses.reversed.toList();

          // API 측 정렬과 무관하게 상태 그룹 순서를 명확히 보장합니다.
          final byStatus = <InventoryStatus, List<StaffProductInventory>>{
            for (final status in orderedStatuses) status: <StaffProductInventory>[],
          };
          for (final item in overview.inventories) {
            byStatus[item.inventoryStatus]?.add(item);
          }

          // 위젯은 ListView.builder에서 화면에 보이는 항목만 생성합니다.
          final entries = <Object?>[null]; // 요약 헤더
          for (final status in orderedStatuses) {
            entries.add(status);
            final stocks = byStatus[status]!;
            if (stocks.isEmpty) {
              entries.add(_EmptyStatusGroup(status));
            } else {
              entries.addAll(stocks);
            }
          }

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: StaffInventoryView._maxContentWidth),
              child: Scrollbar(
                child: RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(inventoryStatusOverviewProvider);
                    await ref.read(inventoryStatusOverviewProvider.future);
                  },
                  child: ListView.builder(
                    padding: EdgeInsets.fromLTRB(
                      tablet ? 32 : 12,
                      tablet ? 24 : 12,
                      tablet ? 32 : 12,
                      24 + MediaQuery.paddingOf(context).bottom,
                    ),
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      if (entry == null) {
                        return _StatusOverviewHeader(
                          overview: overview,
                          descending: descending,
                          isTablet: tablet,
                        );
                      }
                      if (entry is InventoryStatus) {
                        return _StatusGroupHeader(
                          status: entry,
                          summary: overview.summary[entry]!,
                          isTablet: tablet,
                        );
                      }
                      if (entry is _EmptyStatusGroup) {
                        return const Padding(
                          padding: EdgeInsets.fromLTRB(14, 0, 14, 16),
                          child: _EmptyRow('해당 상태의 재고가 없습니다'),
                        );
                      }
                      final batch = entry as StaffProductInventory;
                      return Padding(
                        padding: EdgeInsets.only(bottom: tablet ? 10 : 8),
                        child: _StatusInventoryCard(
                          batch: batch,
                          cosmeticName: overview.cosmeticNames[batch.cosmeticId] ?? batch.cosmeticId,
                          isTablet: tablet,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EmptyStatusGroup {
  const _EmptyStatusGroup(this.status);
  final InventoryStatus status;
}

String _statusKorean(InventoryStatus status) => switch (status) {
  InventoryStatus.DISCARD => '폐기 대상',
  InventoryStatus.HOLD => '보류',
  InventoryStatus.MAINTAIN => '정상 유지',
};

Color _statusColor(BuildContext context, InventoryStatus status) {
  final theme = Theme.of(context).colorScheme;
  return switch (status) {
    InventoryStatus.DISCARD => theme.error,
    InventoryStatus.HOLD => const Color(0xFF996300),
    InventoryStatus.MAINTAIN => theme.primary,
  };
}

class _StatusOverviewHeader extends StatelessWidget {
  const _StatusOverviewHeader({
    required this.overview,
    required this.descending,
    required this.isTablet,
  });

  final InventoryStatusOverview overview;
  final bool descending;
  final bool isTablet;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final discard = overview.summary[InventoryStatus.DISCARD]!;
    return Padding(
      padding: EdgeInsets.only(bottom: isTablet ? 20 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 6,
            children: [
              Text('재고 상태별 목록', style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: isTablet ? 22 : 18,
              )),
              Text(
                descending ? '기본 정렬: 폐기 → 보류 → 유지' : '정렬: 유지 → 보류 → 폐기',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.report_problem_outlined, size: 19, color: theme.colorScheme.error),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  '폐기 대상: ${_formatNumber(discard.inventoryCount)}건 · ${_formatNumber(discard.totalQuantity)}개',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusGroupHeader extends StatelessWidget {
  const _StatusGroupHeader({
    required this.status,
    required this.summary,
    required this.isTablet,
  });

  final InventoryStatus status;
  final InventoryStatusSummary summary;
  final bool isTablet;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(context, status);
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(2, isTablet ? 10 : 8, 2, 12),
      child: Row(
        children: [
          Container(
            width: 5,
            height: isTablet ? 34 : 30,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              runSpacing: 3,
              children: [
                Text(
                  '${status.name} · ${_statusKorean(status)}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: isTablet ? 18 : 16,
                  ),
                ),
                Text(
                  '${_formatNumber(summary.inventoryCount)}건 / 총 ${_formatNumber(summary.totalQuantity)}개',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusInventoryCard extends StatelessWidget {
  const _StatusInventoryCard({
    required this.batch,
    required this.cosmeticName,
    required this.isTablet,
  });

  final StaffProductInventory batch;
  final String cosmeticName;
  final bool isTablet;

  static String _date(DateTime? date) => date == null
      ? '미설정'
      : '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _statusColor(context, batch.inventoryStatus);
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isTablet ? 12 : 10),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isTablet ? 20 : 14,
          vertical: isTablet ? 15 : 12,
        ),
        child: isTablet
            ? Row(
                children: [
                  Icon(Icons.inventory_2_outlined, color: color, size: 24),
                  const SizedBox(width: 14),
                  Expanded(
                    flex: 5,
                    child: _InfoCell(
                      label: '화장품 이름',
                      value: cosmeticName,
                      secondary: '옵션 ID: ${batch.cosmeticId}',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(flex: 4, child: _InfoCell(label: '재고 번호', value: batch.inventoryId)),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: _InfoCell(label: '수량', value: '${_formatNumber(batch.stockQuantity)}개')),
                  const SizedBox(width: 12),
                  Expanded(flex: 3, child: _InfoCell(label: '판매 상태', value: batch.saleOption.name)),
                  const SizedBox(width: 12),
                  Expanded(flex: 3, child: _InfoCell(label: '입고일', value: _date(batch.receivedOn))),
                  const SizedBox(width: 12),
                  Expanded(flex: 3, child: _InfoCell(label: '유통기한', value: _date(batch.expiresOn))),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(cosmeticName,
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('옵션 ID: ${batch.cosmeticId}',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 4),
                  Text('재고 ${batch.inventoryId} · ${_formatNumber(batch.stockQuantity)}개',
                      style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 4),
                  Text(
                    '${batch.saleOption.name} · 입고 ${_date(batch.receivedOn)} · 만료 ${_date(batch.expiresOn)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _InfoCell extends StatelessWidget {
  const _InfoCell({required this.label, required this.value, this.secondary});

  final String label;
  final String value;
  final String? secondary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 4),
        Text(value, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        if (secondary != null) ...[
          const SizedBox(height: 3),
          Text(secondary!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ],
    );
  }
}

String _formatNumber(int number) {
  final sign = number < 0 ? '-' : '';
  final digits = number.abs().toString();
  return '$sign${digits.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => ',')}';
}

class _LoadingRow extends StatelessWidget {
  const _LoadingRow();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(16),
    child: Row(
      children: [
        SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
        SizedBox(width: 12),
        Text('조회 중...'),
      ],
    ),
  );
}

class _EmptyRow extends StatelessWidget {
  const _EmptyRow(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(18),
    child: Text(
      message,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
    ),
  );
}

class _Failed extends StatelessWidget {
  const _Failed({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [
          Text(message),
          TextButton(onPressed: onRetry, child: const Text('재시도')),
        ],
      ),
    ),
  );
}
