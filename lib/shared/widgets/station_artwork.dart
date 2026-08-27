import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class StationArtwork extends StatelessWidget {
  const StationArtwork({
    super.key,
    this.url,
    this.name,
    this.tags = const [],
    this.size = 48,
    this.icon = Icons.radio,
    this.borderRadius = 8,
  });

  final String? url;
  final String? name;
  final List<String> tags;
  final double size;
  final IconData icon;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final resolved = resolveArtworkUrl(url);
    if (resolved != null) {
      final pixelSize = (size * MediaQuery.devicePixelRatioOf(context)).round();
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: CachedNetworkImage(
          imageUrl: resolved,
          width: size,
          height: size,
          fit: BoxFit.cover,
          memCacheWidth: pixelSize,
          memCacheHeight: pixelSize,
          filterQuality: FilterQuality.medium,
          fadeInDuration: const Duration(milliseconds: 200),
          errorWidget: (_, __, ___) => _placeholder(context),
          placeholder: (_, __) => _placeholder(context),
        ),
      );
    }
    return _placeholder(context);
  }

  /// 跳过低分辨率的 favicon，避免放大后模糊。
  /// 未匹配明确后缀/域名的 URL 仍原样返回，交由 CachedNetworkImage 处理。
  static String? resolveArtworkUrl(String? raw) {
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

  Widget _placeholder(BuildContext context) {
    final label = _displayLabel();
    final colors = _gradientColors();
    final displayIcon = _pickIcon();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            displayIcon,
            size: size * 0.34,
            color: Colors.white.withValues(alpha: 0.22),
          ),
          if (label.length <= 2)
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: size * 0.34,
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            )
          else
            Padding(
              padding: EdgeInsets.all(size * 0.12),
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: size * 0.18,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _displayLabel() {
    final value = name?.trim();
    if (value == null || value.isEmpty) return 'FM';
    final stripped = value
        .replaceAll(RegExp(r'FM[\d.]+', caseSensitive: false), '')
        .replaceAll(RegExp(r'AM\d+', caseSensitive: false), '')
        .trim();
    if (stripped.isEmpty) return value.characters.take(2).toString();
    return stripped.characters.take(2).toString();
  }

  IconData _pickIcon() {
    if (tags.contains('音乐')) return Icons.music_note_rounded;
    if (tags.contains('新闻')) return Icons.newspaper_rounded;
    if (tags.contains('交通')) return Icons.directions_car_filled_rounded;
    if (tags.contains('财经')) return Icons.trending_up_rounded;
    if (tags.contains('播客') || icon == Icons.podcasts) return Icons.podcasts_rounded;
    return icon;
  }

  List<Color> _gradientColors() => gradientColors(name: name, tags: tags);

  /// 用于播放器背景取色（与封面占位渐变一致）。
  static List<Color> gradientColors({String? name, List<String> tags = const []}) {
    if (tags.contains('央广')) {
      return const [Color(0xFFB71C1C), Color(0xFFE53935)];
    }
    if (tags.contains('广东')) {
      return const [Color(0xFF00695C), Color(0xFF26A69A)];
    }
    if (tags.contains('上海')) {
      return const [Color(0xFF1565C0), Color(0xFF42A5F5)];
    }
    if (tags.contains('北京')) {
      return const [Color(0xFF4527A0), Color(0xFF7E57C2)];
    }
    if (tags.contains('江苏')) {
      return const [Color(0xFF0277BD), Color(0xFF4FC3F7)];
    }
    if (tags.contains('音乐')) {
      return const [Color(0xFF6A1B9A), Color(0xFFAB47BC)];
    }
    if (tags.contains('新闻')) {
      return const [Color(0xFF0D47A1), Color(0xFF1976D2)];
    }
    if (tags.contains('交通')) {
      return const [Color(0xFFE65100), Color(0xFFFF9800)];
    }

    final hash = Object.hash(name ?? '', tags.join());
    final base = HSLColor.fromAHSL(1, (hash % 360).toDouble(), 0.52, 0.42);
    return [base.toColor(), base.withLightness(0.55).toColor()];
  }
}
