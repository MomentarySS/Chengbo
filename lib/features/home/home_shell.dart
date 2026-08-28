import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audio/podcast_download.dart';
import '../../core/network/new_episode_checker.dart';
import '../../core/platform/desk_widget_sync.dart';
import '../../shared/widgets/desk_mini_bar.dart';
import '../../core/platform/notification_permission.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme.dart';
import '../listening/listening_screen.dart';
import '../podcast/podcast_providers.dart';
import '../podcast/podcast_screen.dart';
import '../radio/radio_providers.dart';
import '../radio/radio_screen.dart';
import '../radio/station_catalog_setup_screen.dart';
import '../settings/settings_screen.dart';
import '../../shared/widgets/mini_player.dart';
import '../../shared/widgets/now_playing_route.dart';
import '../../shared/widgets/offline_banner.dart';
import '../../shared/widgets/shake_sleep_listener.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await requestPlaybackNotificationPermission();
      if (!mounted) return;
      final storage = await ref.read(appStorageProvider.future);
      if (!await storage.getStationCatalogConfigured() && mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            fullscreenDialog: true,
            builder: (_) => const StationCatalogSetupScreen(firstLaunch: true),
          ),
        );
      }
      if (!mounted) return;
      await ref.read(playerControllerProvider).restoreLastSession();
      if (!mounted) return;
      await handleDeskWidgetLaunch(ref);
      if (!mounted) return;
      await ref.read(newEpisodeCheckerProvider).checkIfDue();
    });
  }

  static const _destinations = [
    NavigationDestination(
      icon: Icon(Icons.radio_outlined),
      selectedIcon: Icon(Icons.radio),
      label: '电台',
    ),
    NavigationDestination(
      icon: Icon(Icons.podcasts_outlined),
      selectedIcon: Icon(Icons.podcasts),
      label: '播客',
    ),
    NavigationDestination(
      icon: Icon(Icons.headphones_outlined),
      selectedIcon: Icon(Icons.headphones),
      label: '收听',
    ),
    NavigationDestination(
      icon: Icon(Icons.settings_outlined),
      selectedIcon: Icon(Icons.settings),
      label: '设置',
    ),
  ];

  static const _pages = [
    RadioScreen(),
    PodcastScreen(),
    ListeningScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    ref.listen(sleepTimerProvider, (previous, next) {
      if (next.stoppedByTimer) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已按定时停止播放')),
        );
      }
    });
    ref.listen(podcastDownloadsProvider, (previous, next) {
      if (!PodcastDownloadLogic.shouldShowFailureNotice(
        previousSeq: previous?.failureSeq,
        nextSeq: next.failureSeq,
        title: next.lastFailureTitle,
      )) {
        return;
      }
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text('「${next.lastFailureTitle}」下载失败')),
      );
    });
    ref.listen(isOfflineProvider, (previous, next) {
      final wasOffline = previous?.value ?? false;
      final offline = next.value ?? false;
      if (wasOffline && !offline) {
        ref.read(stationsProvider.notifier).reload();
      }
    });

    ref.watch(autoBrowseSyncProvider);
    ref.watch(podcastQueueSyncProvider);
    ref.watch(deskWidgetSyncProvider);
    ref.watch(podcastSkipStepProvider);
    ref.watch(lastSleepValueProvider);
    final deskCompact = ref.watch(deskCompactProvider).value ?? false;
    final useRail = MediaQuery.sizeOf(context).width >= ChengboTheme.railBreakpoint;

    void openNowPlaying() {
      Navigator.of(context).push(NowPlayingPageRoute());
    }

    final body = SafeArea(
      bottom: false,
      child: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: IndexedStack(
              index: _index,
              children: _pages,
            ),
          ),
          MiniPlayer(onExpand: openNowPlaying),
        ],
      ),
    );

    if (deskCompact) {
      return ShakeSleepListener(
        child: Material(
          type: MaterialType.transparency,
          child: DeskMiniBar(
            onExit: () => ref.read(deskCompactProvider.notifier).setEnabled(false),
          ),
        ),
      );
    }

    if (useRail) {
      return ShakeSleepListener(
        child: Scaffold(
          body: Row(
            children: [
              NavigationRail(
                selectedIndex: _index,
                onDestinationSelected: (value) => setState(() => _index = value),
                labelType: NavigationRailLabelType.all,
                destinations: _destinations
                    .map(
                      (item) => NavigationRailDestination(
                        icon: item.icon,
                        selectedIcon: item.selectedIcon,
                        label: Text(item.label),
                      ),
                    )
                    .toList(),
              ),
              const VerticalDivider(width: 1),
              Expanded(child: body),
            ],
          ),
        ),
      );
    }

    return ShakeSleepListener(
      child: Scaffold(
        body: body,
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (value) => setState(() => _index = value),
          destinations: _destinations,
        ),
      ),
    );
  }
}
