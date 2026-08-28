/// 本机 GUID 集合：已听完、收藏单集共用同一套上限与增删。
abstract final class PodcastGuidSetLogic {
  static const maxItems = 500;

  static Set<String> add(Set<String> current, {required String guid}) {
    if (guid.isEmpty) return current;
    final next = {...current, guid};
    if (next.length > maxItems) {
      final list = next.toList();
      return list.sublist(list.length - maxItems).toSet();
    }
    return next;
  }

  static Set<String> remove(Set<String> current, {required String guid}) {
    if (guid.isEmpty) return current;
    final next = {...current};
    next.remove(guid);
    return next;
  }
}

/// 单集已听完标记：持久化已听完的 episode GUID，供过滤与展示。
abstract final class PodcastListenedLogic {
  static const maxListened = PodcastGuidSetLogic.maxItems;

  /// 把一集标记为已听完。
  static Set<String> markAsPlayed(
    Set<String> current, {
    required String episodeGuid,
  }) {
    return PodcastGuidSetLogic.add(current, guid: episodeGuid);
  }

  /// 把一集标记为未听完。
  static Set<String> markAsNotPlayed(
    Set<String> current, {
    required String episodeGuid,
  }) {
    return PodcastGuidSetLogic.remove(current, guid: episodeGuid);
  }
}

/// 收藏单集：独立于电台收藏，上限与已听相同。
abstract final class PodcastStarredLogic {
  static const maxStarred = PodcastGuidSetLogic.maxItems;

  static Set<String> star(Set<String> current, {required String episodeGuid}) {
    return PodcastGuidSetLogic.add(current, guid: episodeGuid);
  }

  static Set<String> unstar(Set<String> current, {required String episodeGuid}) {
    return PodcastGuidSetLogic.remove(current, guid: episodeGuid);
  }
}
