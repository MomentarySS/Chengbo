import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/category/station_category_resolver.dart';
import '../../core/models/radio_station.dart';
import '../../core/audio/auto_browse.dart';
import '../../core/audio/playback_logic.dart';
import '../../core/audio/radio_audio_handler.dart';
import '../../core/network/catalog_fetch_logic.dart';
import '../../core/network/radio_browser_client.dart';
import '../../core/network/station_probe.dart';
import '../../core/network/station_repository.dart';
import '../../core/network/stream_url_tester.dart';
import '../../core/providers/app_providers.dart';
import '../../core/station/custom_stations_backup.dart';
import '../../core/station/station_hide.dart';
import '../../core/station/station_catalog_selection.dart';
import '../../core/station/station_patch.dart';
import '../../core/station/station_region.dart';
import '../../core/station/station_skip.dart';

final radioBrowserClientProvider = Provider<RadioBrowserClient>((ref) => RadioBrowserClient());

final curatedStationsRepositoryProvider =
    Provider<CuratedStationsRepository>((ref) => CuratedStationsRepository());

final stationRepositoryProvider = Provider<StationRepository>((ref) {
  return StationRepository(
    curatedRepository: ref.watch(curatedStationsRepositoryProvider),
  );
});

final streamUrlTesterProvider = Provider<StreamUrlTester>(
  (ref) => StreamUrlTester.forLaunchProbe(),
);

final stationProbeProgressProvider =
    StateProvider<StationProbeProgress>((ref) => const StationProbeProgress());

final radioBrowserDiscoveryProvider =
    StateNotifierProvider<RadioBrowserDiscoveryNotifier, AsyncValue<bool>>((ref) {
  return RadioBrowserDiscoveryNotifier(ref);
});

class RadioBrowserDiscoveryNotifier extends StateNotifier<AsyncValue<bool>> {
  RadioBrowserDiscoveryNotifier(this._ref) : super(const AsyncLoading()) {
    _load();
  }

  final Ref _ref;

  Future<void> _load() async {
    final storage = await _ref.read(appStorageProvider.future);
    state = AsyncData(await storage.getRadioBrowserDiscoveryEnabled());
  }

  Future<void> setEnabled(bool enabled) async {
    state = AsyncData(enabled);
    final storage = await _ref.read(appStorageProvider.future);
    await storage.setRadioBrowserDiscoveryEnabled(enabled);
    await _ref.read(stationsProvider.notifier).reload();
  }
}

final overseasStationsEnabledProvider =
    StateNotifierProvider<OverseasStationsEnabledNotifier, AsyncValue<bool>>((ref) {
  return OverseasStationsEnabledNotifier(ref);
});

final stationCatalogSelectionProvider =
    StateNotifierProvider<StationCatalogSelectionNotifier, AsyncValue<StationCatalogSelection>>((ref) {
  return StationCatalogSelectionNotifier(ref);
});

class StationCatalogSelectionNotifier
    extends StateNotifier<AsyncValue<StationCatalogSelection>> {
  StationCatalogSelectionNotifier(this._ref) : super(const AsyncLoading()) {
    _load();
  }

  final Ref _ref;

  Future<void> _load() async {
    final storage = await _ref.read(appStorageProvider.future);
    state = AsyncData(await storage.getStationCatalogSelection());
  }

  Future<void> applySelection(StationCatalogSelection selection) async {
    state = AsyncData(selection);
    final storage = await _ref.read(appStorageProvider.future);
    await storage.setStationCatalogSelection(selection);
    await storage.setStationCatalogConfigured(true);
    await storage.setStationProbeCompleted(false);
    await _ref.read(stationsProvider.notifier).reload(forceProbe: true);
  }
}

class OverseasStationsEnabledNotifier extends StateNotifier<AsyncValue<bool>> {
  OverseasStationsEnabledNotifier(this._ref) : super(const AsyncLoading()) {
    _load();
  }

  final Ref _ref;

  Future<void> _load() async {
    final storage = await _ref.read(appStorageProvider.future);
    state = AsyncData(await storage.getOverseasStationsEnabled());
  }

  Future<void> setEnabled(bool enabled) async {
    state = AsyncData(enabled);
    final storage = await _ref.read(appStorageProvider.future);
    await storage.setOverseasStationsEnabled(enabled);
  }
}

final catalogStationsProvider = StateProvider<List<RadioStation>>((ref) => const []);

final stationsProvider =
    StateNotifierProvider<StationsNotifier, AsyncValue<List<RadioStation>>>((ref) {
  return StationsNotifier(ref);
});

class StationsNotifier extends StateNotifier<AsyncValue<List<RadioStation>>> {
  StationsNotifier(this._ref) : super(const AsyncLoading()) {
    // 不能在 provider 初始化同步改别的 provider，否则 debug 断言会把首次 reload 打断。
    Future.microtask(() {
      if (mounted) reload();
    });
  }

  final Ref _ref;

  /// 重新拉目录。默认沿用首次能播的 id；[forceProbe] 才测全部源。
  /// 返回是否实际探测了直播地址。
  Future<bool> reload({bool forceProbe = false}) async {
    state = const AsyncLoading();
    await Future<void>.value();
    if (!mounted) return false;
    _ref.read(stationProbeProgressProvider.notifier).state =
        StationProbeProgress(probing: forceProbe);
    try {
      await _waitForCatalogInputs();
      final repository = _ref.read(stationRepositoryProvider);
      final client = _ref.read(radioBrowserClientProvider);
      final tester = _ref.read(streamUrlTesterProvider);
      final storage = await _ref.read(appStorageProvider.future);
      final configured = await storage.getStationCatalogConfigured();
      if (!configured) {
        if (!mounted) return false;
        state = const AsyncData([]);
        _ref.read(stationProbeProgressProvider.notifier).state =
            const StationProbeProgress();
        return false;
      }
      final discoveryEnabled = _ref.read(radioBrowserDiscoveryProvider).value ?? true;
      final catalogSelection = _ref.read(stationCatalogSelectionProvider).value ??
          const StationCatalogSelection();
      final offline = await _ref.read(networkMonitorProvider).isOffline;
      final probeCompleted = await storage.getStationProbeCompleted();
      final cachedIds = (await storage.getReachableStationIds()).toSet();

      final loaded = CatalogFetchLogic.useRadioBrowser(
            offline: offline,
            discoveryEnabled: discoveryEnabled,
          )
          ? await repository.loadAll(
              fetchApi: () => client.fetchChinaCatalog(selection: catalogSelection),
            )
          : await repository.loadAll(fetchApi: () async => []);
      final custom = _ref.read(customStationsProvider).value ?? [];
      final merged = StationRepository.prependCustom(custom, loaded);
      final patches = _ref.read(stationPatchesProvider).value ?? {};
      final patched = StationPatchLogic.applyAll(merged, patches);
      final catalog = StationCatalogSelectionLogic.apply(patched, catalogSelection);
      if (!mounted) return false;
      _ref.read(catalogStationsProvider.notifier).state = catalog;

      final probe = StationProbeLogic.shouldProbe(
        force: forceProbe,
        offline: offline,
        probeCompleted: probeCompleted,
      );
      if (!probe) {
        if (!mounted) return false;
        _ref.read(stationProbeProgressProvider.notifier).state =
            const StationProbeProgress();
        state = AsyncData(
          StationProbeLogic.keepCached(
            catalog: catalog,
            cachedIds: cachedIds,
            patchedIds: {
              for (final patch in patches.values)
                if (patch.changesUrl) patch.stationId,
            },
          ),
        );
        return false;
      }

      _ref.read(stationProbeProgressProvider.notifier).state =
          const StationProbeProgress(probing: true);
      final probed = await tester.keepReachable(
        catalog,
        onProgress: (done, total) {
          if (!mounted) return;
          _ref.read(stationProbeProgressProvider.notifier).state =
              StationProbeProgress(done: done, total: total, probing: true);
        },
      );
      await storage.setReachableStationIds(StationProbeLogic.idsOf(probed).toList());
      await storage.setStationProbeCompleted(true);
      if (!mounted) return false;
      state = AsyncData(probed);
      return true;
    } catch (error, stackTrace) {
      if (!mounted) return false;
      state = AsyncError(error, stackTrace);
      return false;
    }
  }

  Future<void> rememberReachable(String stationId) async {
    final storage = await _ref.read(appStorageProvider.future);
    final next = StationProbeLogic.rememberId(
      (await storage.getReachableStationIds()).toSet(),
      stationId,
    );
    await storage.setReachableStationIds(next.toList());
    await _ref.read(hiddenStationIdsProvider.notifier).unhide(stationId);
  }

  /// 本机播不出来时按用户隐藏处理，进「已隐藏的电台」。
  Future<void> hideIfUnplayable(PlaybackItem item, String message) async {
    if (!PlaybackLogic.shouldHideAfterPlayFailure(
      kind: item.kind,
      offline: await _ref.read(networkMonitorProvider).isOffline,
      errorMessage: message,
    )) {
      return;
    }
    final stationId = item.stationId ?? item.id;
    await _ref.read(hiddenStationIdsProvider.notifier).hide(stationId);
  }

  Future<void> _waitForCatalogInputs() async {
    for (var i = 0; i < 100; i++) {
      final custom = _ref.read(customStationsProvider);
      final discovery = _ref.read(radioBrowserDiscoveryProvider);
      final patches = _ref.read(stationPatchesProvider);
      final scope = _ref.read(stationCatalogSelectionProvider);
      if (!custom.isLoading &&
          !discovery.isLoading &&
          !patches.isLoading &&
          !scope.isLoading) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 30));
    }
  }
}

final unreachableStationsProvider = Provider<List<RadioStation>>((ref) {
  return StationPatchLogic.unreachable(
    catalog: ref.watch(catalogStationsProvider),
    reachable: ref.watch(stationsProvider).value ?? const [],
  );
});

final hiddenStationIdsProvider =
    StateNotifierProvider<HiddenStationIdsNotifier, AsyncValue<Set<String>>>((ref) {
  return HiddenStationIdsNotifier(ref);
});

class HiddenStationIdsNotifier extends StateNotifier<AsyncValue<Set<String>>> {
  HiddenStationIdsNotifier(this._ref) : super(const AsyncLoading()) {
    _load();
  }

  final Ref _ref;

  Future<void> _load() async {
    final storage = await _ref.read(appStorageProvider.future);
    state = AsyncData((await storage.getHiddenStationIds()).toSet());
  }

  Future<void> hide(String stationId) async {
    if (stationId.isEmpty) return;
    final next = StationHideLogic.hide(state.value ?? {}, stationId);
    await _persist(next);
    final current = _ref.read(currentPlaybackProvider);
    if (StationHideLogic.isCurrentRadio(current, stationId)) {
      await _ref.read(playerControllerProvider).stop();
    }
  }

  Future<void> unhide(String stationId) async {
    await _persist(StationHideLogic.unhide(state.value ?? {}, stationId));
  }

  Future<void> _persist(Set<String> ids) async {
    state = AsyncData(ids);
    final storage = await _ref.read(appStorageProvider.future);
    await storage.setHiddenStationIds(ids.toList());
  }
}

final hiddenStationsProvider = Provider<List<RadioStation>>((ref) {
  return StationHideLogic.onlyHidden(
    ref.watch(catalogStationsProvider),
    ref.watch(hiddenStationIdsProvider).value ?? {},
  );
});

final stationPatchesProvider =
    StateNotifierProvider<StationPatchesNotifier, AsyncValue<Map<String, StationPatch>>>((ref) {
  return StationPatchesNotifier(ref);
});

class StationPatchesNotifier extends StateNotifier<AsyncValue<Map<String, StationPatch>>> {
  StationPatchesNotifier(this._ref) : super(const AsyncLoading()) {
    _load();
  }

  final Ref _ref;

  Future<void> _load() async {
    final storage = await _ref.read(appStorageProvider.future);
    final raw = await storage.getStationPatches();
    final patches = <String, StationPatch>{};
    for (final item in raw) {
      final patch = StationPatch.fromJson(item);
      if (patch.stationId.isEmpty) continue;
      patches[patch.stationId] = patch;
    }
    state = AsyncData(patches);
  }

  Future<String?> replaceUrl({
    required RadioStation station,
    required String streamUrl,
  }) async {
    final next = streamUrl.trim();
    if (next.isEmpty) return '请输入流地址';
    if (!next.startsWith('http://') && !next.startsWith('https://')) {
      return '流地址需以 http:// 或 https:// 开头';
    }
    final current = Map<String, StationPatch>.from(state.value ?? {});
    final draft = StationPatchLogic.draft(
      station: station,
      nextUrl: next,
      existing: current[station.id],
    );
    if (draft == null) {
      current.remove(station.id);
    } else {
      current[station.id] = draft;
    }
    await _persist(current);
    if (draft != null) {
      await _ref.read(stationsProvider.notifier).rememberReachable(station.id);
    }
    await _ref.read(stationsProvider.notifier).reload();
    return null;
  }

  Future<void> restore(String stationId) async {
    final current = Map<String, StationPatch>.from(state.value ?? {});
    if (current.remove(stationId) == null) return;
    await _persist(current);
    await _ref.read(stationsProvider.notifier).reload();
  }

  Future<void> _persist(Map<String, StationPatch> patches) async {
    state = AsyncData(patches);
    final storage = await _ref.read(appStorageProvider.future);
    await storage.setStationPatches(patches.values.map((item) => item.toJson()).toList());
  }
}

final stationSearchProvider = StateProvider<String>((ref) => '');

final stationCategoryProvider = StateProvider<String>((ref) => StationCategoryResolver.all);

/// Bitrate floor filter: null = no filter, otherwise only show stations >= this bitrate.
final stationBitrateFloorProvider = StateProvider<int?>((ref) => null);

/// When true, only show favorited stations.
final stationFavoritesOnlyProvider = StateProvider<bool>((ref) => false);

/// Recently searched queries, most recent first.
final radioSearchHistoryProvider =
    StateNotifierProvider<RadioSearchHistoryNotifier, AsyncValue<List<String>>>((ref) {
  return RadioSearchHistoryNotifier(ref);
});

class RadioSearchHistoryNotifier extends StateNotifier<AsyncValue<List<String>>> {
  RadioSearchHistoryNotifier(this._ref) : super(const AsyncLoading()) {
    _load();
  }

  final Ref _ref;
  static const _maxHistory = 5;

  Future<void> _load() async {
    final storage = await _ref.read(appStorageProvider.future);
    state = AsyncData(await storage.getRadioSearchHistory());
  }

  Future<void> add(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    final storage = await _ref.read(appStorageProvider.future);
    final current = List<String>.from(state.value ?? []);
    current.remove(trimmed);
    current.insert(0, trimmed);
    if (current.length > _maxHistory) {
      current.removeRange(_maxHistory, current.length);
    }
    await storage.setRadioSearchHistory(current);
    state = AsyncData(current);
  }

  Future<void> clear() async {
    final storage = await _ref.read(appStorageProvider.future);
    await storage.setRadioSearchHistory([]);
    state = const AsyncData([]);
  }
}

final customCategoriesProvider =
    StateNotifierProvider<CustomCategoriesNotifier, AsyncValue<List<String>>>((ref) {
  return CustomCategoriesNotifier(ref);
});

final customStationsProvider =
    StateNotifierProvider<CustomStationsNotifier, AsyncValue<List<RadioStation>>>((ref) {
  return CustomStationsNotifier(ref);
});

class CustomStationsNotifier extends StateNotifier<AsyncValue<List<RadioStation>>> {
  CustomStationsNotifier(this._ref) : super(const AsyncLoading()) {
    _load();
  }

  final Ref _ref;

  Future<void> _load() async {
    final storage = await _ref.read(appStorageProvider.future);
    final raw = await storage.getCustomStations();
    state = AsyncData(raw.map(RadioStation.fromJson).toList());
  }

  Future<String?> add({
    required String name,
    required String streamUrl,
    String? favicon,
    String category = '综合',
    List<String> extraTags = const [],
  }) async {
    final trimmedName = name.trim();
    final trimmedUrl = streamUrl.trim();
    if (trimmedName.isEmpty) return '请输入电台名称';
    if (trimmedUrl.isEmpty) return '请输入流地址';
    if (!trimmedUrl.startsWith('http://') && !trimmedUrl.startsWith('https://')) {
      return '流地址需以 http:// 或 https:// 开头';
    }

    final current = List<RadioStation>.from(state.value ?? []);
    var catalog = _ref.read(stationsProvider).value ?? [];
    if (catalog.isEmpty) {
      try {
        catalog = await _ref.read(curatedStationsRepositoryProvider).loadStations();
      } catch (_) {}
    }
    final existing = [
      ...current,
      ...catalog.where((s) => !current.any((c) => c.id == s.id)),
    ];
    final conflict = RadioStation.duplicateReason(
      name: trimmedName,
      streamUrl: trimmedUrl,
      existing: existing,
    );
    if (conflict != null) return conflict;

    final tags = <String>{'自定义', category, ...extraTags.where((t) => t.trim().isNotEmpty)};
    final station = RadioStation(
      id: 'user-${DateTime.now().millisecondsSinceEpoch}',
      name: trimmedName,
      streamUrl: trimmedUrl,
      favicon: favicon?.trim().isEmpty ?? true ? null : favicon!.trim(),
      tags: tags.toList(),
      category: category,
      source: StationSource.custom,
    );

    current.insert(0, station);
    final storage = await _ref.read(appStorageProvider.future);
    await storage.setCustomStations(current.map((s) => s.toJson()).toList());
    state = AsyncData(current);
    unawaited(_ref.read(stationsProvider.notifier).reload());
    return null;
  }

  Future<void> remove(String stationId) async {
    final current = List<RadioStation>.from(state.value ?? [])..removeWhere((s) => s.id == stationId);
    final storage = await _ref.read(appStorageProvider.future);
    await storage.setCustomStations(current.map((s) => s.toJson()).toList());
    state = AsyncData(current);
    unawaited(_ref.read(stationsProvider.notifier).reload());

    final favoriteIds = List<String>.from(_ref.read(favoriteIdsProvider).value ?? [])
      ..remove(stationId);
    await storage.setFavoriteIds(favoriteIds);
    _ref.read(favoriteIdsProvider.notifier).state = AsyncData(favoriteIds);
  }

  Future<String?> update({
    required String id,
    required String name,
    required String streamUrl,
    String? favicon,
    String category = '综合',
    List<String> extraTags = const [],
  }) async {
    final trimmedName = name.trim();
    final trimmedUrl = streamUrl.trim();
    if (trimmedName.isEmpty) return '请输入电台名称';
    if (trimmedUrl.isEmpty) return '请输入流地址';
    if (!trimmedUrl.startsWith('http://') && !trimmedUrl.startsWith('https://')) {
      return '流地址需以 http:// 或 https:// 开头';
    }

    final current = List<RadioStation>.from(state.value ?? []);
    final index = current.indexWhere((s) => s.id == id);
    if (index < 0) return '未找到该电台';

    var catalog = _ref.read(stationsProvider).value ?? [];
    if (catalog.isEmpty) {
      try {
        catalog = await _ref.read(curatedStationsRepositoryProvider).loadStations();
      } catch (_) {}
    }
    final existing = [
      ...current.where((s) => s.id != id),
      ...catalog.where((s) => s.id != id && !current.any((c) => c.id == s.id)),
    ];
    final conflict = RadioStation.duplicateReason(
      name: trimmedName,
      streamUrl: trimmedUrl,
      existing: existing,
    );
    if (conflict != null) return conflict;

    final tags = <String>{'自定义', category, ...extraTags.where((t) => t.trim().isNotEmpty)};
    current[index] = RadioStation(
      id: id,
      name: trimmedName,
      streamUrl: trimmedUrl,
      favicon: favicon?.trim().isEmpty ?? true ? null : favicon!.trim(),
      tags: tags.toList(),
      category: category,
      source: StationSource.custom,
      bitrate: current[index].bitrate,
      codec: current[index].codec,
      homepage: current[index].homepage,
    );

    final storage = await _ref.read(appStorageProvider.future);
    await storage.setCustomStations(current.map((s) => s.toJson()).toList());
    state = AsyncData(current);
    unawaited(_ref.read(stationsProvider.notifier).reload());
    return null;
  }

  Future<CustomStationsImportResult> importStations(List<RadioStation> incoming) async {
    final current = List<RadioStation>.from(state.value ?? []);
    final result = CustomStationsBackup.merge(existing: current, incoming: incoming);
    final storage = await _ref.read(appStorageProvider.future);
    await storage.setCustomStations(result.stations.map((s) => s.toJson()).toList());
    state = AsyncData(result.stations);
    if (result.added > 0) {
      unawaited(_ref.read(stationsProvider.notifier).reload());
    }
    return result;
  }
}

final stationCategoryOverridesProvider =
    StateNotifierProvider<CategoryOverridesNotifier, AsyncValue<Map<String, String>>>((ref) {
  return CategoryOverridesNotifier(ref);
});

String effectiveStationCategory(
  RadioStation station,
  Map<String, String> overrides,
) {
  return StationCategoryResolver.resolve(station, overrides: overrides);
}

final visibleStationsProvider = Provider<AsyncValue<List<RadioStation>>>((ref) {
  final stationsAsync = ref.watch(stationsProvider);
  final overseasAsync = ref.watch(overseasStationsEnabledProvider);
  final hiddenAsync = ref.watch(hiddenStationIdsProvider);
  if (overseasAsync.isLoading || hiddenAsync.isLoading) {
    return const AsyncLoading();
  }
  final showOverseas = overseasAsync.value ?? false;
  final hiddenIds = hiddenAsync.value ?? {};
  return stationsAsync.whenData(
    (stations) => StationRegion.visibleCatalog(
      StationHideLogic.excludeHidden(stations, hiddenIds),
      showOverseas: showOverseas,
    ),
  );
});

final stationFilterCategoriesProvider = Provider<List<String>>((ref) {
  final stationsAsync = ref.watch(visibleStationsProvider);
  final customAsync = ref.watch(customCategoriesProvider);
  final overridesAsync = ref.watch(stationCategoryOverridesProvider);

  final stations = stationsAsync.value ?? [];
  final overrides = overridesAsync.value ?? {};
  final custom = customAsync.value ?? [];

  final effective = stations.map((s) => effectiveStationCategory(s, overrides));
  return StationCategoryResolver.visibleFilters(
    effectiveCategories: effective,
    customCategories: custom,
  );
});

final filteredStationsProvider = Provider<AsyncValue<List<RadioStation>>>((ref) {
  final stationsAsync = ref.watch(visibleStationsProvider);
  final query = ref.watch(stationSearchProvider).trim().toLowerCase();
  final category = ref.watch(stationCategoryProvider);
  final bitrateFloor = ref.watch(stationBitrateFloorProvider);
  final favoritesOnly = ref.watch(stationFavoritesOnlyProvider);
  final overrides = ref.watch(stationCategoryOverridesProvider).value ?? {};
  final favoriteIds = ref.watch(favoriteIdsProvider).value ?? [];

  return stationsAsync.whenData((stations) {
    final filtered = stations.where((station) {
      final effective = effectiveStationCategory(station, overrides);
      final matchesCategory =
          category == StationCategoryResolver.all || effective == category;
      final matchesQuery = query.isEmpty ||
          station.name.toLowerCase().contains(query) ||
          station.tags.any((tag) => tag.toLowerCase().contains(query));
      final matchesBitrate =
          bitrateFloor == null || (station.bitrate ?? 0) >= bitrateFloor;
      final matchesFavorite = !favoritesOnly || favoriteIds.contains(station.id);
      return matchesCategory && matchesQuery && matchesBitrate && matchesFavorite;
    }).toList();
    return StationSkipLogic.favoritesFirst(
      stations: filtered,
      favoriteIds: favoriteIds,
      favoritesOnly: favoritesOnly,
    );
  });
});

class CustomCategoriesNotifier extends StateNotifier<AsyncValue<List<String>>> {
  CustomCategoriesNotifier(this._ref) : super(const AsyncLoading()) {
    _load();
  }

  final Ref _ref;

  Future<void> _load() async {
    final storage = await _ref.read(appStorageProvider.future);
    state = AsyncData(await storage.getCustomCategories());
  }

  Future<void> add(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    if (StationCategoryResolver.lockedCategoryNames.contains(trimmed)) return;
    if (StationCategoryResolver.defaultFilterCategories.contains(trimmed)) return;

    final current = List<String>.from(state.value ?? []);
    if (current.contains(trimmed)) return;
    current.add(trimmed);
    final storage = await _ref.read(appStorageProvider.future);
    await storage.setCustomCategories(current);
    state = AsyncData(current);
  }

  Future<void> remove(String name) async {
    if (StationCategoryResolver.lockedCategoryNames.contains(name)) return;
    final current = List<String>.from(state.value ?? [])..remove(name);
    final storage = await _ref.read(appStorageProvider.future);
    await storage.setCustomCategories(current);

    final overrides = Map<String, String>.from(
      _ref.read(stationCategoryOverridesProvider).value ?? {},
    )..removeWhere((_, category) => category == name);
    await storage.setStationCategoryOverrides(overrides);
    _ref.read(stationCategoryOverridesProvider.notifier).state = AsyncData(overrides);

    state = AsyncData(current);
  }
}

class CategoryOverridesNotifier extends StateNotifier<AsyncValue<Map<String, String>>> {
  CategoryOverridesNotifier(this._ref) : super(const AsyncLoading()) {
    _load();
  }

  final Ref _ref;

  Future<void> _load() async {
    final storage = await _ref.read(appStorageProvider.future);
    state = AsyncData(await storage.getStationCategoryOverrides());
  }

  Future<bool> setOverride(RadioStation station, String category) async {
    if (StationCategoryResolver.isLocked(station)) return false;
    if (StationCategoryResolver.lockedCategoryNames.contains(category)) return false;

    final storage = await _ref.read(appStorageProvider.future);
    final current = Map<String, String>.from(state.value ?? {});
    final auto = StationCategoryResolver.resolve(station, overrides: const {});

    if (category == auto) {
      current.remove(station.id);
    } else {
      current[station.id] = category;
    }

    await storage.setStationCategoryOverrides(current);
    state = AsyncData(current);
    return true;
  }

  Future<void> clearOverride(String stationId) async {
    final storage = await _ref.read(appStorageProvider.future);
    final current = Map<String, String>.from(state.value ?? {});
    current.remove(stationId);
    await storage.setStationCategoryOverrides(current);
    state = AsyncData(current);
  }
}

final favoriteIdsProvider =
    StateNotifierProvider<FavoriteIdsNotifier, AsyncValue<List<String>>>((ref) {
  return FavoriteIdsNotifier(ref);
});

class FavoriteIdsNotifier extends StateNotifier<AsyncValue<List<String>>> {
  FavoriteIdsNotifier(this._ref) : super(const AsyncLoading()) {
    _load();
  }

  final Ref _ref;

  Future<void> _load() async {
    final storage = await _ref.read(appStorageProvider.future);
    state = AsyncData(await storage.getFavoriteIds());
  }

  Future<void> toggle(String stationId) async {
    final storage = await _ref.read(appStorageProvider.future);
    final current = List<String>.from(state.value ?? []);
    if (current.contains(stationId)) {
      current.remove(stationId);
    } else {
      current.insert(0, stationId);
    }
    await storage.setFavoriteIds(current);
    state = AsyncData(current);
  }

  bool isFavorite(String stationId) => state.value?.contains(stationId) ?? false;
}

final recentIdsProvider =
    StateNotifierProvider<RecentIdsNotifier, AsyncValue<List<String>>>((ref) {
  return RecentIdsNotifier(ref);
});

class RecentIdsNotifier extends StateNotifier<AsyncValue<List<String>>> {
  RecentIdsNotifier(this._ref) : super(const AsyncLoading()) {
    _load();
  }

  final Ref _ref;

  Future<void> _load() async {
    final storage = await _ref.read(appStorageProvider.future);
    state = AsyncData(await storage.getRecentIds());
  }

  Future<void> add(String stationId) async {
    final storage = await _ref.read(appStorageProvider.future);
    final current = List<String>.from(state.value ?? []);
    current.remove(stationId);
    current.insert(0, stationId);
    if (current.length > 20) {
      current.removeRange(20, current.length);
    }
    await storage.setRecentIds(current);
    state = AsyncData(current);
  }

  Future<void> clear() async {
    final storage = await _ref.read(appStorageProvider.future);
    await storage.setRecentIds(const []);
    state = const AsyncData([]);
  }
}

final favoriteStationsProvider = Provider<AsyncValue<List<RadioStation>>>((ref) {
  final stationsAsync = ref.watch(visibleStationsProvider);
  final favoriteIdsAsync = ref.watch(favoriteIdsProvider);
  if (stationsAsync.isLoading || favoriteIdsAsync.isLoading) {
    return const AsyncLoading();
  }
  if (stationsAsync.hasError) {
    return AsyncError(stationsAsync.error!, stationsAsync.stackTrace!);
  }
  final ids = favoriteIdsAsync.value ?? [];
  final stations = stationsAsync.value ?? [];
  final map = {for (final s in stations) s.id: s};
  return AsyncData(ids.map((id) => map[id]).whereType<RadioStation>().toList());
});

final stationSkipProvider = Provider<StationSkipController>((ref) {
  return StationSkipController(ref);
});

class StationSkipController {
  StationSkipController(this._ref);

  final Ref _ref;

  Future<void> skip(int delta) async {
    final current = _ref.read(currentPlaybackProvider);
    if (current == null || current.kind != PlaybackKind.radio) return;
    final currentId = current.stationId ?? current.id;
    final queue = StationSkipLogic.queue(
      currentId: currentId,
      filtered: _ref.read(filteredStationsProvider).value ?? [],
      favorites: _ref.read(favoriteStationsProvider).value ?? [],
      visible: _ref.read(visibleStationsProvider).value ?? [],
    );
    final next = StationSkipLogic.neighbor(queue, currentId, delta);
    if (next == null) return;
    await _ref.read(recentIdsProvider.notifier).add(next.id);
    if (next.source == StationSource.api) {
      unawaited(_ref.read(radioBrowserClientProvider).reportClick(next.id));
    }
    await _ref.read(playerControllerProvider).play(PlaybackItem.fromStation(next));
  }
}

/// 把收藏 / 最近 / 可见台同步给 Android Auto 浏览树，并接上车机上一台/下一台。
final autoBrowseSyncProvider = Provider<void>((ref) {
  ref.listen<AsyncValue<RadioAudioHandler>>(audioHandlerProvider, (previous, next) {
    next.whenData((handler) {
      handler.onSkipNeighbor = (delta) => ref.read(stationSkipProvider).skip(delta);
      handler.onPlayBrowseItem = (item) => ref.read(playerControllerProvider).play(item);
      handler.onPlayFailed = (item, message) =>
          ref.read(stationsProvider.notifier).hideIfUnplayable(item, message);
    });
  });
  void publish() {
    final handler = ref.read(audioHandlerProvider).value;
    if (handler == null) return;
    handler.publishBrowseCatalog(
      AutoBrowseCatalog(
        favorites: ref.read(favoriteStationsProvider).value ?? const [],
        recents: ref.read(recentStationsProvider).value ?? const [],
        stations: ref.read(visibleStationsProvider).value ?? const [],
      ),
    );
  }

  ref.listen(favoriteStationsProvider, (_, __) => publish());
  ref.listen(recentStationsProvider, (_, __) => publish());
  ref.listen(visibleStationsProvider, (_, __) => publish());
  ref.listen(audioHandlerProvider, (_, __) => publish());
});

final recentStationsProvider = Provider<AsyncValue<List<RadioStation>>>((ref) {
  final stationsAsync = ref.watch(visibleStationsProvider);
  final recentIdsAsync = ref.watch(recentIdsProvider);
  if (stationsAsync.isLoading || recentIdsAsync.isLoading) {
    return const AsyncLoading();
  }
  final ids = recentIdsAsync.value ?? [];
  final stations = stationsAsync.value ?? [];
  final map = {for (final s in stations) s.id: s};
  return AsyncData(ids.map((id) => map[id]).whereType<RadioStation>().toList());
});

final playingStationProvider = Provider<RadioStation?>((ref) {
  final current = ref.watch(currentPlaybackProvider);
  if (current == null) return null;
  final stationId = current.stationId ?? current.id;
  final stations = ref.watch(stationsProvider).value ?? [];
  for (final station in stations) {
    if (station.id == stationId) return station;
  }
  return null;
});

final stationSkipQueueProvider = Provider.family<List<RadioStation>, String>((ref, String stationId) {
  return StationSkipLogic.queue(
    currentId: stationId,
    filtered: ref.watch(filteredStationsProvider).value ?? [],
    favorites: ref.watch(favoriteStationsProvider).value ?? [],
    visible: ref.watch(visibleStationsProvider).value ?? [],
  );
});