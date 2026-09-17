import 'package:audio_service/audio_service.dart';

import '../artwork/artwork_url.dart';
import '../audio/podcast_download.dart';
import '../brand.dart';
import '../models/radio_station.dart';

/// Android Auto / 车机 MediaBrowser 目录。
class AutoBrowseCatalog {
  const AutoBrowseCatalog({
    this.favorites = const [],
    this.recents = const [],
    this.stations = const [],
    this.continueListening,
    this.downloads = const [],
  });

  final List<RadioStation> favorites;
  final List<RadioStation> recents;
  final List<RadioStation> stations;
  final PlaybackItem? continueListening;
  final List<PlaybackItem> downloads;
}

abstract final class AutoBrowseLogic {
  static const rootId = 'root';
  static const favoritesId = 'favorites';
  static const recentsId = 'recents';
  static const stationsId = 'stations';
  static const continueId = 'continue';
  static const downloadsId = 'downloads';
  static const stationPrefix = 'station:';
  static const episodePrefix = 'episode:';
  static const maxStations = 40;

  static String stationMediaId(String stationId) => '$stationPrefix$stationId';

  static String episodeMediaId(String episodeGuid) => '$episodePrefix$episodeGuid';

  static String? stationIdFromMediaId(String mediaId) {
    if (!mediaId.startsWith(stationPrefix)) return null;
    final id = mediaId.substring(stationPrefix.length).trim();
    return id.isEmpty ? null : id;
  }

  static String? episodeGuidFromMediaId(String mediaId) {
    if (!mediaId.startsWith(episodePrefix)) return null;
    final id = mediaId.substring(episodePrefix.length).trim();
    return id.isEmpty ? null : id;
  }

  static List<PlaybackItem> downloadPlaybackItems({
    required Iterable<PodcastDownloadRecord> records,
    required String Function(String feedId) feedTitleFor,
    int max = maxStations,
  }) {
    final items = <PlaybackItem>[];
    for (final record in records.take(max)) {
      final feedTitle = feedTitleFor(record.feedId).trim();
      items.add(
        PlaybackItem.fromPodcastEpisode(
          podcastTitle: feedTitle.isEmpty ? record.title : feedTitle,
          episodeTitle: record.title,
          audioUrl: record.audioUrl,
          episodeGuid: record.guid,
          feedId: record.feedId.isEmpty ? null : record.feedId,
        ),
      );
    }
    return items;
  }

  static List<MediaItem> children(String parentMediaId, AutoBrowseCatalog catalog) {
    switch (parentMediaId) {
      case rootId:
      case '':
        return [
          const MediaItem(
            id: favoritesId,
            title: '收藏',
            playable: false,
          ),
          const MediaItem(
            id: recentsId,
            title: '最近播放',
            playable: false,
          ),
          const MediaItem(
            id: stationsId,
            title: '电台',
            playable: false,
          ),
          if (catalog.continueListening != null)
            const MediaItem(
              id: continueId,
              title: '继续收听',
              playable: false,
            ),
          if (catalog.downloads.isNotEmpty)
            const MediaItem(
              id: downloadsId,
              title: '已下载',
              playable: false,
            ),
        ];
      case favoritesId:
        return catalog.favorites.map(stationMediaItem).toList();
      case recentsId:
        return catalog.recents.map(stationMediaItem).toList();
      case stationsId:
        return catalog.stations.take(maxStations).map(stationMediaItem).toList();
      case continueId:
        final item = catalog.continueListening;
        return item == null ? const [] : [episodeMediaItem(item)];
      case downloadsId:
        return catalog.downloads.take(maxStations).map(episodeMediaItem).toList();
      default:
        return const [];
    }
  }

  static MediaItem stationMediaItem(RadioStation station) {
    return MediaItem(
      id: stationMediaId(station.id),
      title: station.name,
      album: AppBrand.displayName,
      artist: station.category,
      artUri: ArtworkUrlLogic.mediaArtUri(station.favicon),
      playable: true,
      extras: PlaybackItem.fromStation(station).toJson(),
    );
  }

  static MediaItem episodeMediaItem(PlaybackItem item) {
    return MediaItem(
      id: episodeMediaId(item.episodeGuid ?? item.id),
      title: item.title,
      album: AppBrand.displayName,
      artist: item.subtitle,
      artUri: ArtworkUrlLogic.mediaArtUri(item.artworkUrl),
      playable: true,
      extras: item.toJson(),
    );
  }

  /// 兼容旧测试名。
  static MediaItem mediaItemFor(RadioStation station) => stationMediaItem(station);

  static PlaybackItem? playbackItemFor({
    required String mediaId,
    required AutoBrowseCatalog catalog,
    Map<String, dynamic>? extras,
  }) {
    if (extras != null) {
      final fromExtras = PlaybackItem.tryFromJson(extras);
      if (fromExtras != null) return fromExtras;
    }
    final stationId = stationIdFromMediaId(mediaId);
    if (stationId != null) {
      for (final station in [...catalog.favorites, ...catalog.recents, ...catalog.stations]) {
        if (station.id == stationId) return PlaybackItem.fromStation(station);
      }
      return null;
    }
    final episodeGuid = episodeGuidFromMediaId(mediaId);
    if (episodeGuid == null) return null;
    final resume = catalog.continueListening;
    if (resume != null && (resume.episodeGuid ?? resume.id) == episodeGuid) {
      return resume;
    }
    for (final item in catalog.downloads) {
      if ((item.episodeGuid ?? item.id) == episodeGuid) return item;
    }
    return null;
  }
}
