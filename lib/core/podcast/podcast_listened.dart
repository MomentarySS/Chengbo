/// 单集已听完标记：持久化已听完的 episode GUID，供过滤与展示。
abstract final class PodcastListenedLogic {
  static const maxListened = 500;

  /// 把一集标记为已听完。
  static Set<String> markAsPlayed(
    Set<String> current, {
    required String episodeGuid,
  }) {
    if (episodeGuid.isEmpty) return current;
    final next = {...current, episodeGuid};
    if (next.length > maxListened) {
      // 超出上限时去掉最旧的
      final list = next.toList();
      return list.sublist(list.length - maxListened).toSet();
    }
    return next;
  }

  /// 把一集标记为未听完。
  static Set<String> markAsNotPlayed(
    Set<String> current, {
    required String episodeGuid,
  }) {
    if (episodeGuid.isEmpty) return current;
    final next = {...current};
    next.remove(episodeGuid);
    return next;
  }
}