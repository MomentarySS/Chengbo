/// 迷你条封面与 Now Playing 大封面共用的 Hero 标记。
abstract final class NowPlayingHero {
  static const flightMs = 360;

  static String tagFor(String playbackId) => 'now-playing-artwork-$playbackId';
}
