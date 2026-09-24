import 'package:flutter/material.dart';

/// Small app-specific theme details shared by the now-playing surfaces.
@immutable
class SkinCopy {
  const SkinCopy({
    required this.emptyStations,
    required this.emptyStationsDetail,
    required this.probing,
    required this.updatingCatalog,
    required this.emptyFavorites,
    required this.emptyFavoritesDetail,
  });

  final String emptyStations;
  final String emptyStationsDetail;
  final String probing;
  final String updatingCatalog;
  final String emptyFavorites;
  final String emptyFavoritesDetail;
}

const _chengboCopy = SkinCopy(
  emptyStations: '当前没有可播放的电台',
  emptyStationsDetail: '连不上的台去设置「电台管理」里更换地址。要重新测全部源，下拉或点重新检测',
  probing: '正在检测可用电台',
  updatingCatalog: '正在更新电台列表',
  emptyFavorites: '还没有收藏电台',
  emptyFavoritesDetail: '在电台列表点爱心，就会出现在这里',
);

/// 澄波播放器页面共用的细节，避免电台与播客页面的视觉规格分叉。
@immutable
class ChengboSkinTheme extends ThemeExtension<ChengboSkinTheme> {
  const ChengboSkinTheme();

  SkinCopy get copy => _chengboCopy;
  double get playerRadius => 12;
  static const anchorMaxSide = 300.0;
  double get anchorRadius => 20;

  LinearGradient nowPlayingBackdrop({
    required Color surface,
    required Color wash,
  }) {
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [wash, wash, surface],
      stops: const [0, 0.62, 1],
    );
  }

  Color nowPlayingWash({required Color surface, required Color coverAccent}) =>
      Color.alphaBlend(coverAccent.withValues(alpha: 0.36), surface);

  TextStyle? countdownStyle(TextStyle? base, Color color) => base?.copyWith(
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  @override
  ChengboSkinTheme copyWith() => const ChengboSkinTheme();

  @override
  ChengboSkinTheme lerp(ThemeExtension<ChengboSkinTheme>? other, double t) =>
      const ChengboSkinTheme();
}

extension ChengboSkinContext on BuildContext {
  ChengboSkinTheme get chengboSkin =>
      Theme.of(this).extension<ChengboSkinTheme>() ?? const ChengboSkinTheme();
}
