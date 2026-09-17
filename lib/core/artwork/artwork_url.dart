/// 台标 / 封面 URL：丢掉低清 favicon，通知栏与列表共用。
abstract final class ArtworkUrlLogic {
  static String? resolve(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final lower = raw.toLowerCase();
    if (lower.endsWith('.ico') || lower.contains('favicon')) {
      return null;
    }
    if (lower.contains('.jpg') ||
        lower.contains('.jpeg') ||
        lower.contains('.png') ||
        lower.contains('.webp') ||
        lower.contains('pic.qtfm.cn') ||
        lower.contains('qingting.fm') ||
        lower.contains('xmcdn.com')) {
      return raw;
    }
    return raw;
  }

  static Uri? mediaArtUri(String? raw) {
    final resolved = resolve(raw);
    if (resolved == null) return null;
    return Uri.tryParse(resolved);
  }
}
