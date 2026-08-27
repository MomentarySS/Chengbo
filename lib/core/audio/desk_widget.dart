import '../models/radio_station.dart';

/// Android 桌面小组件要显示的字段。
class DeskWidgetSnapshot {
  const DeskWidgetSnapshot({
    required this.title,
    required this.subtitle,
    required this.playing,
    required this.hasItem,
  });

  final String title;
  final String subtitle;
  final bool playing;
  final bool hasItem;

  static const empty = DeskWidgetSnapshot(
    title: '澄波',
    subtitle: '点此打开',
    playing: false,
    hasItem: false,
  );
}

abstract final class DeskWidgetLogic {
  static const androidName = 'ChengboWidgetProvider';
  static const titleKey = 'widget_title';
  static const subtitleKey = 'widget_subtitle';
  static const playingKey = 'widget_playing';
  static const toggleHost = 'toggle';

  static DeskWidgetSnapshot snapshot({
    required PlaybackItem? item,
    required bool playing,
  }) {
    if (item == null) return DeskWidgetSnapshot.empty;
    return DeskWidgetSnapshot(
      title: item.title,
      subtitle: item.subtitle,
      playing: playing,
      hasItem: true,
    );
  }

  static bool isToggleUri(Uri? uri) => uri?.host == toggleHost;
}
