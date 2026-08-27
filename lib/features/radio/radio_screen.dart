import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/category/station_category_resolver.dart';
import '../../core/network/network_status.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme.dart';
import '../../features/radio/radio_providers.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/station_list_tile.dart';
import '../../shared/widgets/station_probe_status.dart';

/// Bitrate filter options: null = all, otherwise minimum bitrate in kbps.
const _bitrateFilters = [
  (label: '全部', floor: null),
  (label: '64k+', floor: 64),
  (label: '128k+', floor: 128),
  (label: '256k+', floor: 256),
];

class RadioScreen extends ConsumerStatefulWidget {
  const RadioScreen({super.key});

  @override
  ConsumerState<RadioScreen> createState() => _RadioScreenState();
}

class _RadioScreenState extends ConsumerState<RadioScreen> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  Timer? _searchDebounce;
  bool _showHistory = false;

  static const _searchDelay = Duration(milliseconds: 300);

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.removeListener(_onFocusChange);
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {
      _showHistory = _searchFocusNode.hasFocus && _searchController.text.isEmpty;
    });
  }

  void _setSearch(String value) {
    _searchDebounce?.cancel();
    ref.read(stationSearchProvider.notifier).state = value;
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _showHistory = _searchFocusNode.hasFocus && value.isEmpty;
    _searchDebounce = Timer(_searchDelay, () {
      if (!mounted) return;
      ref.read(stationSearchProvider.notifier).state = value;
    });
  }

  void _onSearchSubmit(String value) {
    final trimmed = value.trim();
    if (trimmed.isNotEmpty) {
      ref.read(radioSearchHistoryProvider.notifier).add(trimmed);
    }
    _showHistory = false;
  }

  void _clearFilters() {
    _searchDebounce?.cancel();
    _searchController.clear();
    _setSearch('');
    ref.read(stationCategoryProvider.notifier).state = StationCategoryResolver.all;
    ref.read(stationBitrateFloorProvider.notifier).state = null;
    ref.read(stationFavoritesOnlyProvider.notifier).state = false;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = ref.watch(filteredStationsProvider);
    final category = ref.watch(stationCategoryProvider);
    final categories = ref.watch(stationFilterCategoriesProvider);
    final query = ref.watch(stationSearchProvider);
    final bitrateFloor = ref.watch(stationBitrateFloorProvider);
    final favoritesOnly = ref.watch(stationFavoritesOnlyProvider);
    final offline = ref.watch(isOfflineProvider).value ?? false;
    final hasFilter = query.isNotEmpty ||
        category != StationCategoryResolver.all ||
        bitrateFloor != null ||
        favoritesOnly;

    return Column(
      children: [
        // --- Search bar ---
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: '搜索电台名称或标签',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (favoritesOnly)
                    Tooltip(
                      message: '显示全部',
                      child: IconButton(
                        icon: Icon(Icons.favorite, color: Theme.of(context).colorScheme.primary),
                        onPressed: () =>
                            ref.read(stationFavoritesOnlyProvider.notifier).state = false,
                      ),
                    )
                  else if (query.isEmpty)
                    IconButton(
                      tooltip: '只看收藏',
                      icon: const Icon(Icons.favorite_border),
                      onPressed: () =>
                          ref.read(stationFavoritesOnlyProvider.notifier).state = true,
                    ),
                  if (query.isNotEmpty)
                    IconButton(
                      tooltip: '清除搜索',
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _searchDebounce?.cancel();
                        _searchController.clear();
                        _showHistory = false;
                        _setSearch('');
                      },
                    ),
                ],
              ),
            ),
            onChanged: _onSearchChanged,
            onSubmitted: _onSearchSubmit,
          ),
        ),

        // --- Search history dropdown ---
        if (_showHistory)
          _SearchHistoryDropdown(
            onSelect: (q) {
              _searchController.text = q;
              _showHistory = false;
              _setSearch(q);
              ref.read(radioSearchHistoryProvider.notifier).add(q);
            },
            onClear: () {
              ref.read(radioSearchHistoryProvider.notifier).clear();
            },
          ),

        // --- Category filter chips ---
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Row(
            children: [
              for (var index = 0; index < categories.length; index++) ...[
                if (index > 0) const SizedBox(width: 8),
                FilterChip(
                  showCheckmark: false,
                  label: Text(categories[index]),
                  selected: category == categories[index],
                  onSelected: (_) =>
                      ref.read(stationCategoryProvider.notifier).state = categories[index],
                ),
              ],
            ],
          ),
        ),

        // --- Bitrate filter chips ---
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              for (final filter in _bitrateFilters) ...[
                if (filter != _bitrateFilters.first) const SizedBox(width: 8),
                FilterChip(
                  showCheckmark: false,
                  label: Text(filter.label),
                  selected: bitrateFloor == filter.floor,
                  onSelected: (_) =>
                      ref.read(stationBitrateFloorProvider.notifier).state = filter.floor,
                ),
              ],
            ],
          ),
        ),

        // --- Station list ---
        Expanded(
          child: filtered.when(
            data: (stations) {
              if (stations.isEmpty) {
                final catalogCount = ref.read(stationsProvider).value?.length ?? 0;
                final overseasHidden = catalogCount > 0 &&
                    !(ref.read(overseasStationsEnabledProvider).value ?? false);
                return AppEmptyState(
                  icon: offline && !hasFilter ? Icons.wifi_off : Icons.radio_outlined,
                  message: hasFilter
                      ? '没有找到匹配的电台'
                      : overseasHidden
                          ? '当前列表没有境内电台'
                          : offline
                              ? NetworkStatusLogic.listMessage
                              : '当前没有可播放的电台',
                  detail: hasFilter
                      ? '试试其他分类，或清除搜索'
                      : overseasHidden
                          ? '港澳台电台默认隐藏，可在设置「电台管理」中打开「显示境外电台」'
                          : offline
                              ? NetworkStatusLogic.listDetail
                              : '连不上的台去设置「电台管理」里更换地址。要重新测全部源，下拉或点重新检测',
                  actionLabel: hasFilter ? '显示全部' : '重新检测',
                  onAction: hasFilter
                      ? _clearFilters
                      : () => ref.read(stationsProvider.notifier).reload(forceProbe: true),
                );
              }
              return RefreshIndicator(
                onRefresh: () => ref.read(stationsProvider.notifier).reload(forceProbe: true),
                child: ListView.separated(
                  padding: const EdgeInsets.only(bottom: ChengboTheme.listBottomPadding),
                  itemCount: stations.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) => StationListTile(station: stations[index]),
                ),
              );
            },
            loading: () => StationProbeStatus(
              progress: ref.watch(stationProbeProgressProvider),
            ),
            error: (error, _) => AppEmptyState(
              icon: offline ? Icons.wifi_off : Icons.error_outline,
              message: NetworkStatusLogic.loadFailureMessage('电台列表加载失败', offline: offline),
              detail: NetworkStatusLogic.loadFailureDetail(error, offline: offline),
              actionLabel: '重试',
              onAction: () => ref.read(stationsProvider.notifier).reload(),
            ),
          ),
        ),
      ],
    );
  }
}

class _SearchHistoryDropdown extends ConsumerWidget {
  const _SearchHistoryDropdown({required this.onSelect, required this.onClear});

  final void Function(String query) onSelect;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(radioSearchHistoryProvider);
    final history = historyAsync.value ?? [];

    if (history.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        child: Row(
          children: [
            Icon(
              Icons.history,
              size: 18,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              '暂无搜索历史',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '搜索历史',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              GestureDetector(
                onTap: onClear,
                child: Text(
                  '清除',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              ),
            ],
          ),
          ...history.map((q) => InkWell(
                onTap: () => onSelect(q),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.history, size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text(q, style: Theme.of(context).textTheme.bodyMedium)),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }
}
