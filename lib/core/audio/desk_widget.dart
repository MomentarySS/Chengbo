import 'dart:convert';

import '../models/radio_station.dart';
import '../podcast/feed_cache.dart';

/// Android 桌面小组件要显示的字段。
class DeskWidgetSnapshot {
  const DeskWidgetSnapshot({
    required this.title,
    required this.subtitle,
    required this.playing,
    required this.hasItem,
    required this.useDynamicColor,
  });

  final String title;
  final String subtitle;
  final bool playing;
  final bool hasItem;
  final bool useDynamicColor;

  static const empty = DeskWidgetSnapshot(
    title: '澄波',
    subtitle: '点此打开',
    playing: false,
    hasItem: false,
    useDynamicColor: false,
  );
}

enum DeskWidgetAction { open, toggle, next, resume, play, none }

enum DeskWidgetResumeTarget { continueEpisode, lastSession, none }

/// Android 桌面小组件：播停、下一台、续播。
abstract final class DeskWidgetLogic {
  static const androidName = 'ChengboWidgetProvider';
  static const titleKey = 'widget_title';
  static const subtitleKey = 'widget_subtitle';
  static const playingKey = 'widget_playing';
  static const openHost = 'open';
  static const toggleHost = 'toggle';
  static const nextHost = 'next';
  static const resumeHost = 'resume';
  static const playHost = 'play';

  // ----- B2 待听 widget ---------------------------------------------------
  /// 改这里必须同步 `ChengboWidgetEpisodesProvider.kt` 第 N 行的字面量
  /// (计划 §5 #8 跨语言契约)。
  static const episodesKey = 'widget_episodes';
  static const episodesAndroidName = 'ChengboWidgetEpisodesProvider';

  /// 字面量字符串用于 Kotlin 端空态兜底；正式运行时优先走
  /// `R.string.widget_episodes_empty_title` / `widget_episodes_empty_subtitle`
  ///（Android 端本地化路径）。Dart 常量仅作 fallback / 单测断言用。
  static const episodesEmptyTitle = '暂无未听单集';
  static const episodesEmptySubtitle = '点此打开澄波';

  /// 4×2 cell 容纳 4 行；`FeedCacheLogic.maxInboxItems = 20` 是 inbox 上限，
  /// widget 取前 4（计划 §3.3.1）。
  static const maxEpisodes = 4;

  /// B1 动态色开关的数据键。改这里必须同步 `ChengboWidgetProvider.kt`
  /// 第 N 行的字符串字面量（计划 §5 第 8 条）。
  static const useDynamicColorKey = 'widget_use_dynamic_color';

  static DeskWidgetSnapshot snapshot({
    required PlaybackItem? item,
    required bool playing,
    required bool useDynamicColor,
  }) {
    // 无 item 时：useDynamicColor=false 走 empty 常量（保留 identity 语义，测试断言仍可用）；
    // useDynamicColor=true 构造新实例，背景仍跟随系统配色，但内容为「点此打开」空态。
    if (item == null) {
      if (!useDynamicColor) return DeskWidgetSnapshot.empty;
      return DeskWidgetSnapshot(
        title: DeskWidgetSnapshot.empty.title,
        subtitle: DeskWidgetSnapshot.empty.subtitle,
        playing: DeskWidgetSnapshot.empty.playing,
        hasItem: DeskWidgetSnapshot.empty.hasItem,
        useDynamicColor: useDynamicColor,
      );
    }
    return DeskWidgetSnapshot(
      title: item.title,
      subtitle: item.subtitle,
      playing: playing,
      hasItem: true,
      useDynamicColor: useDynamicColor,
    );
  }

  /// 序列化为 JSON 字符串。空列表返回 `[]`（原生侧据此显示空态）。
  /// `take(max)` 语义：超过 max 截断。
  static String episodesPayload(List<InboxItem> items, {int max = maxEpisodes}) {
    final rows = items.take(max).map((item) => {
          'title': item.episode.title,
          'subtitle': item.feed.title,
          'guid': item.episode.guid,
        },);
    return jsonEncode(rows.toList());
  }

  static DeskWidgetAction actionForUri(Uri? uri) {
    return switch (uri?.host) {
      openHost => DeskWidgetAction.open,
      toggleHost => DeskWidgetAction.toggle,
      nextHost => DeskWidgetAction.next,
      resumeHost => DeskWidgetAction.resume,
      playHost => DeskWidgetAction.play,
      _ => DeskWidgetAction.none,
    };
  }

  static bool isToggleUri(Uri? uri) => actionForUri(uri) == DeskWidgetAction.toggle;

  static DeskWidgetResumeTarget resumeTarget({
    required bool hasContinueEpisode,
    required bool hasLastItem,
  }) {
    if (hasContinueEpisode) return DeskWidgetResumeTarget.continueEpisode;
    if (hasLastItem) return DeskWidgetResumeTarget.lastSession;
    return DeskWidgetResumeTarget.none;
  }

  static const launchDedupeWindow = Duration(milliseconds: 800);

  /// 冷启动只处理一条 URI，避免 Activity 与 HomeWidget 各触发一次播停/切台。
  static Uri? initialLaunchUri({Uri? activityUri, Uri? homeWidgetUri}) {
    if (actionForUri(activityUri) != DeskWidgetAction.none) return activityUri;
    if (actionForUri(homeWidgetUri) != DeskWidgetAction.none) return homeWidgetUri;
    return null;
  }

  static bool isDuplicateLaunch({
    required String? previous,
    required DateTime? previousAt,
    required String? next,
    required DateTime now,
    Duration window = launchDedupeWindow,
  }) {
    if (next == null || next.isEmpty) return false;
    if (previous != next || previousAt == null) return false;
    final elapsed = now.difference(previousAt);
    return elapsed >= Duration.zero && elapsed < window;
  }
}
