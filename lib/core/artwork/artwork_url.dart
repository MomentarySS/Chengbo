/// 台标 / 封面 URL：丢掉低清 favicon，通知栏与列表共用。
abstract final class ArtworkUrlLogic {
  static String? resolve(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final lower = raw.toLowerCase();
    if (lower.endsWith('.ico') || lower.contains('favicon')) {
      return null;
    }
    return raw;
  }

  static Uri? mediaArtUri(String? raw) {
    final resolved = resolve(raw);
    if (resolved == null) return null;
    return Uri.tryParse(resolved);
  }
}
