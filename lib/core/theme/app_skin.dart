import 'package:flutter/material.dart';

/// 外观氛围包。默认澄波可跟浅/深与壁纸色；致敬包锁深色、自带种子。
enum AppSkinId { chengbo, wasteland, tokyo3, nightCity }

enum SkinOverlayKind { none, scanline, hex, glitch }

abstract final class AppSkinLogic {
  static AppSkinId parse(String? raw) => switch (raw) {
        'wasteland' => AppSkinId.wasteland,
        'tokyo3' => AppSkinId.tokyo3,
        'nightCity' => AppSkinId.nightCity,
        _ => AppSkinId.chengbo,
      };

  static String persist(AppSkinId id) => switch (id) {
        AppSkinId.chengbo => 'chengbo',
        AppSkinId.wasteland => 'wasteland',
        AppSkinId.tokyo3 => 'tokyo3',
        AppSkinId.nightCity => 'nightCity',
      };

  static AppSkinPack pack(AppSkinId id) => switch (id) {
        AppSkinId.chengbo => AppSkinPack.chengbo,
        AppSkinId.wasteland => AppSkinPack.wasteland,
        AppSkinId.tokyo3 => AppSkinPack.tokyo3,
        AppSkinId.nightCity => AppSkinPack.nightCity,
      };
}

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

@immutable
class AppSkinPack {
  const AppSkinPack({
    required this.id,
    required this.displayName,
    required this.subtitle,
    required this.lockDark,
    required this.seed,
    required this.overlay,
    required this.playerRadius,
    required this.copy,
  });

  final AppSkinId id;
  final String displayName;
  final String subtitle;
  final bool lockDark;
  final Color seed;
  final SkinOverlayKind overlay;
  final double playerRadius;
  final SkinCopy copy;

  bool get isDefault => id == AppSkinId.chengbo;

  static const chengbo = AppSkinPack(
    id: AppSkinId.chengbo,
    displayName: '澄波',
    subtitle: '默认静水，跟随系统浅色、深色',
    lockDark: false,
    seed: Color(0xFF1565C0),
    overlay: SkinOverlayKind.none,
    playerRadius: 12,
    copy: SkinCopy(
      emptyStations: '当前没有可播放的电台',
      emptyStationsDetail: '连不上的台去设置「电台管理」里更换地址。要重新测全部源，下拉或点重新检测',
      probing: '正在检测可用电台',
      updatingCatalog: '正在更新电台列表',
      emptyFavorites: '还没有收藏电台',
      emptyFavoritesDetail: '在电台列表点爱心，就会出现在这里',
    ),
  );

  static const wasteland = AppSkinPack(
    id: AppSkinId.wasteland,
    displayName: '废土终端',
    subtitle: '磷光屏、扫描线；固定深色',
    lockDark: true,
    seed: Color(0xFF3DFF1A),
    overlay: SkinOverlayKind.scanline,
    playerRadius: 8,
    copy: SkinCopy(
      emptyStations: '未检测到可播放的源',
      emptyStationsDetail: '连不上的台去设置「电台管理」里更换地址。要重新测全部源，下拉或点重新检测',
      probing: '正在扫描信号',
      updatingCatalog: '正在刷新目录',
      emptyFavorites: '没有锁定的电台',
      emptyFavoritesDetail: '在电台列表点爱心，就会出现在这里',
    ),
  );

  static const tokyo3 = AppSkinPack(
    id: AppSkinId.tokyo3,
    displayName: '第三新东京',
    subtitle: '紫黑舱、眼绿；固定深色',
    lockDark: true,
    seed: Color(0xFF7C4DFF),
    overlay: SkinOverlayKind.hex,
    playerRadius: 6,
    copy: SkinCopy(
      emptyStations: '没有同步到可播放的源',
      emptyStationsDetail: '连不上的台去设置「电台管理」里更换地址。要重新测全部源，下拉或点重新检测',
      probing: '正在同步',
      updatingCatalog: '正在更新目录',
      emptyFavorites: '还没有收藏电台',
      emptyFavoritesDetail: '在电台列表点爱心，就会出现在这里',
    ),
  );

  static const nightCity = AppSkinPack(
    id: AppSkinId.nightCity,
    displayName: '夜之城',
    subtitle: '酸黄故障；固定深色',
    lockDark: true,
    seed: Color(0xFFE8DE00),
    overlay: SkinOverlayKind.glitch,
    playerRadius: 4,
    copy: SkinCopy(
      emptyStations: '没有可用的频道',
      emptyStationsDetail: '连不上的台去设置「电台管理」里更换地址。要重新测全部源，下拉或点重新检测',
      probing: '正在检索信号',
      updatingCatalog: '正在刷新目录',
      emptyFavorites: '还没有收藏电台',
      emptyFavoritesDetail: '在电台列表点爱心，就会出现在这里',
    ),
  );

  static const List<AppSkinPack> all = [chengbo, wasteland, tokyo3, nightCity];

  ColorScheme colorScheme(Brightness brightness) {
    if (isDefault) {
      return ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
    }
    return switch (id) {
      AppSkinId.wasteland => _wastelandScheme,
      AppSkinId.tokyo3 => _tokyo3Scheme,
      AppSkinId.nightCity => _nightCityScheme,
      AppSkinId.chengbo => ColorScheme.fromSeed(seedColor: seed, brightness: brightness),
    };
  }

  OutlinedBorder get controlShape => switch (id) {
        AppSkinId.chengbo => const StadiumBorder(),
        AppSkinId.wasteland =>
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        AppSkinId.tokyo3 => const BeveledRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(6)),
          ),
        AppSkinId.nightCity =>
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
      };

  OutlinedBorder get chipShape => switch (id) {
        AppSkinId.chengbo => RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        AppSkinId.wasteland =>
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        AppSkinId.tokyo3 => const BeveledRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(5)),
          ),
        AppSkinId.nightCity =>
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
      };
}

const _wastelandScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: Color(0xFF4CFF2A),
  onPrimary: Color(0xFF041204),
  primaryContainer: Color(0xFF1A4A12),
  onPrimaryContainer: Color(0xFFB8FF9A),
  secondary: Color(0xFF7CB86A),
  onSecondary: Color(0xFF041204),
  secondaryContainer: Color(0xFF1A3314),
  onSecondaryContainer: Color(0xFFC5E8B8),
  tertiary: Color(0xFF9FD48A),
  onTertiary: Color(0xFF041204),
  error: Color(0xFFFFB4AB),
  onError: Color(0xFF690005),
  errorContainer: Color(0xFF93000A),
  onErrorContainer: Color(0xFFFFDAD6),
  surface: Color(0xFF070B07),
  onSurface: Color(0xFFD2E8C8),
  onSurfaceVariant: Color(0xFF8FBB82),
  outline: Color(0xFF547A4A),
  outlineVariant: Color(0xFF2A3F26),
  inverseSurface: Color(0xFFD2E8C8),
  onInverseSurface: Color(0xFF121810),
  inversePrimary: Color(0xFF216B14),
  surfaceContainerLowest: Color(0xFF050705),
  surfaceContainerLow: Color(0xFF0C120C),
  surfaceContainer: Color(0xFF101810),
  surfaceContainerHigh: Color(0xFF141E14),
  surfaceContainerHighest: Color(0xFF1A281A),
);

const _tokyo3Scheme = ColorScheme(
  brightness: Brightness.dark,
  primary: Color(0xFFC6FF2A),
  onPrimary: Color(0xFF1A1020),
  primaryContainer: Color(0xFF3D2A55),
  onPrimaryContainer: Color(0xFFE4D4F5),
  secondary: Color(0xFF9B6DCF),
  onSecondary: Color(0xFF1A1020),
  secondaryContainer: Color(0xFF3D1F54),
  onSecondaryContainer: Color(0xFFE8DCEF),
  tertiary: Color(0xFFB388FF),
  onTertiary: Color(0xFF1A1020),
  error: Color(0xFFFFB4AB),
  onError: Color(0xFF690005),
  errorContainer: Color(0xFF93000A),
  onErrorContainer: Color(0xFFFFDAD6),
  surface: Color(0xFF12081A),
  onSurface: Color(0xFFE8DCEF),
  onSurfaceVariant: Color(0xFFB9A4C9),
  outline: Color(0xFF7A628C),
  outlineVariant: Color(0xFF3D2A4A),
  inverseSurface: Color(0xFFE8DCEF),
  onInverseSurface: Color(0xFF1A1020),
  inversePrimary: Color(0xFF5B3D8C),
  surfaceContainerLowest: Color(0xFF0C0612),
  surfaceContainerLow: Color(0xFF180E22),
  surfaceContainer: Color(0xFF1E1428),
  surfaceContainerHigh: Color(0xFF241A30),
  surfaceContainerHighest: Color(0xFF2C2138),
);

const _nightCityScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: Color(0xFFE8DE00),
  onPrimary: Color(0xFF141400),
  primaryContainer: Color(0xFF3D3A00),
  onPrimaryContainer: Color(0xFFF5F0A8),
  secondary: Color(0xFFC4B800),
  onSecondary: Color(0xFF141400),
  secondaryContainer: Color(0xFF2A2800),
  onSecondaryContainer: Color(0xFFEDE6C8),
  tertiary: Color(0xFF00D4E8),
  onTertiary: Color(0xFF00333A),
  error: Color(0xFFFFB4AB),
  onError: Color(0xFF690005),
  errorContainer: Color(0xFF93000A),
  onErrorContainer: Color(0xFFFFDAD6),
  surface: Color(0xFF0A0A00),
  onSurface: Color(0xFFEDE6C8),
  onSurfaceVariant: Color(0xFFB8B08A),
  outline: Color(0xFF7A7640),
  outlineVariant: Color(0xFF3A3818),
  inverseSurface: Color(0xFFEDE6C8),
  onInverseSurface: Color(0xFF141400),
  inversePrimary: Color(0xFF5C5600),
  surfaceContainerLowest: Color(0xFF070700),
  surfaceContainerLow: Color(0xFF121200),
  surfaceContainer: Color(0xFF161600),
  surfaceContainerHigh: Color(0xFF1C1C00),
  surfaceContainerHighest: Color(0xFF242400),
);

@immutable
class ChengboSkinTheme extends ThemeExtension<ChengboSkinTheme> {
  const ChengboSkinTheme({
    required this.pack,
    required this.playerGlow,
  });

  factory ChengboSkinTheme.fromPack(AppSkinPack pack) {
    return ChengboSkinTheme(
      pack: pack,
      playerGlow: switch (pack.id) {
        AppSkinId.chengbo => pack.seed,
        AppSkinId.wasteland => const Color(0xFF4CFF2A),
        AppSkinId.tokyo3 => const Color(0xFFC6FF2A),
        AppSkinId.nightCity => const Color(0xFFE8DE00),
      },
    );
  }

  final AppSkinPack pack;
  final Color playerGlow;

  AppSkinId get id => pack.id;
  bool get isDefault => pack.isDefault;
  SkinCopy get copy => pack.copy;
  double get playerRadius => pack.playerRadius;
  SkinOverlayKind get overlay => pack.overlay;
  bool get usesMonoCountdown => !pack.isDefault;

  /// 播放器「视觉锚点」（电台台名卡 / 播客封面）的统一规格：最大边长。
  ///
  /// 两页必须共用这里，否则会各自漂移 —— 之前电台 300 / 播客 360 就是这么分叉的。
  static const anchorMaxSide = 300.0;

  /// 视觉锚点圆角：跟随当前氛围包的 `playerRadius`，避免与致敬包的小圆角语言冲突。
  double get anchorRadius => playerRadius + 8;

  /// 播放器页背景渐变（电台 / 播客共用同一个函数，避免 stops 各自漂移）。
  LinearGradient nowPlayingBackdrop({required Color surface, required Color wash}) {
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [wash, wash, surface],
      // wash 只铺到 45% 会让浅色模式下下半屏直接掉到近纯白（整页读作「白」）。
      stops: const [0, 0.62, 1],
    );
  }

  Color nowPlayingWash({required Color surface, required Color coverAccent}) {
    if (isDefault) {
      return Color.alphaBlend(coverAccent.withValues(alpha: 0.36), surface);
    }
    return Color.alphaBlend(playerGlow.withValues(alpha: 0.28), surface);
  }

  List<BoxShadow> playerGlowShadows() {
    if (isDefault) return const [];
    return [
      BoxShadow(
        color: playerGlow.withValues(alpha: 0.38),
        blurRadius: 28,
        offset: const Offset(0, 10),
      ),
    ];
  }

  TextStyle? countdownStyle(TextStyle? base, Color color) {
    return base?.copyWith(
      color: color,
      fontFamily: usesMonoCountdown ? 'monospace' : base.fontFamily,
      fontFeatures: const [FontFeature.tabularFigures()],
      letterSpacing: usesMonoCountdown ? 0.6 : base.letterSpacing,
    );
  }

  @override
  ChengboSkinTheme copyWith({AppSkinPack? pack, Color? playerGlow}) {
    return ChengboSkinTheme(
      pack: pack ?? this.pack,
      playerGlow: playerGlow ?? this.playerGlow,
    );
  }

  @override
  ChengboSkinTheme lerp(ThemeExtension<ChengboSkinTheme>? other, double t) {
    if (other is! ChengboSkinTheme) return this;
    if (t < 0.5) return this;
    return other;
  }
}

extension ChengboSkinContext on BuildContext {
  ChengboSkinTheme get chengboSkin =>
      Theme.of(this).extension<ChengboSkinTheme>() ??
      ChengboSkinTheme.fromPack(AppSkinPack.chengbo);
}
