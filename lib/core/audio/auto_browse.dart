import 'package:audio_service/audio_service.dart';

import '../brand.dart';
import '../models/radio_station.dart';

/// Android Auto / 车机 MediaBrowser 目录。
class AutoBrowseCatalog {
  const AutoBrowseCatalog({
    this.favorites = const [],
    this.recents = const [],
    this.stations = const [],
  });

  final List<RadioStation> favorites;
  final List<RadioStation> recents;
  final List<RadioStation> stations;
}

abstract final class AutoBrowseLogic {
  static const rootId = 'root';
  static const favoritesId = 'favorites';
  static const recentsId = 'recents';
  static const stationsId = 'stations';
  static const stationPrefix = 'station:';
  static const maxStations = 40;

  static String stationMediaId(String stationId) => '$stationPrefix$stationId';

  static String? stationIdFromMediaId(String mediaId) {
    if (!mediaId.startsWith(stationPrefix)) return null;
    final id = mediaId.substring(stationPrefix.length).trim();
    return id.isEmpty ? null : id;
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
        ];
      case favoritesId:
        return catalog.favorites.map(mediaItemFor).toList();
      case recentsId:
        return catalog.recents.map(mediaItemFor).toList();
      case stationsId:
        return catalog.stations.take(maxStations).map(mediaItemFor).toList();
      default:
        return const [];
    }
  }

  static MediaItem mediaItemFor(RadioStation station) {
    return MediaItem(
      id: stationMediaId(station.id),
      title: station.name,
      album: AppBrand.displayName,
      artist: station.category,
      artUri: station.favicon != null && station.favicon!.isNotEmpty
          ? Uri.tryParse(station.favicon!)
          : null,
      playable: true,
      extras: PlaybackItem.fromStation(station).toJson(),
    );
  }

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
    if (stationId == null) return null;
    // maxStations is 40; linear scan is fine for this size.
    for (final station in [...catalog.favorites, ...catalog.recents, ...catalog.stations]) {
      if (station.id == stationId) return PlaybackItem.fromStation(station);
    }
    return null;
  }
}
