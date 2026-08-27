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

class RadioScreen extends ConsumerStatefulWidget {
  const RadioScreen({super.key});

  @override
  ConsumerState<RadioScreen> createState() => _RadioScreenState();
}

class _RadioScreenState extends ConsumerState<RadioScreen> {
  final _searchController = TextEditingController();
  Timer? _searchDebounce;

  static const _searchDelay = Duration(milliseconds: 300);

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _setSearch(String value) {
    _searchDebounce?.cancel();
    ref.read(stationSearchProvider.notifier).state = value;
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(_searchDelay, () {
      if (!mounted) return;
      ref.read(stationSearchProvider.notifier).state = value;
    });
  }

  void _clearFilters() {
    _searchDebounce?.cancel();
    _searchController.clear();
    _setSearch('');
    ref.read(stationCategoryProvider.notifier).state = StationCategoryResolver.all;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = ref.watch(filteredStationsProvider);
    final category = ref.watch(stationCategoryProvider);
    final categories = ref.watch(stationFilterCategoriesProvider);
    final query = ref.watch(stationSearchProvider);
    final hasFilter = query.isNotEmpty || category != StationCategoryResolver.all;
    final offline = ref.watch(isOfflineProvider).value ?? false;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: '搜索电台名称或标签',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: '清除搜索',
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _searchDebounce?.cancel();
                        _searchController.clear();
                        _setSearch('');
                      },
                    ),
            ),
            onChanged: _onSearchChanged,
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
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

