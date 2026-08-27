import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 外观：跟随系统 / 浅色 / 深色。旧版开关会把「关」写成浅色，从此不再跟系统。
abstract final class ThemeModeLogic {
  static ThemeMode parse(String? raw) => switch (raw) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  static String persist(ThemeMode mode) => switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      };

  static String label(ThemeMode mode) => switch (mode) {
        ThemeMode.system => '跟随系统',
        ThemeMode.light => '浅色',
        ThemeMode.dark => '深色',
      };

  static String subtitle(ThemeMode mode) => switch (mode) {
        ThemeMode.system => '与系统浅色、深色同步',
        ThemeMode.light => '始终使用浅色',
        ThemeMode.dark => '始终使用深色',
      };
}

/// 壁纸 / 系统强调色 → ColorScheme。没有平台色时退回澄波蓝种子。
abstract final class DynamicThemeLogic {
  static ColorScheme fallback({required Brightness brightness}) {
    return ColorScheme.fromSeed(
      seedColor: ChengboTheme.seed,
      brightness: brightness,
    );
  }

  static ColorScheme resolve({
    required Brightness brightness,
    required bool enabled,
    ColorScheme? platformScheme,
    Color? accent,
  }) {
    if (!enabled) return fallback(brightness: brightness);
    if (platformScheme != null && platformScheme.brightness == brightness) {
      return platformScheme;
    }
    if (accent != null && isUsableAccent(accent)) {
      return ColorScheme.fromSeed(seedColor: accent, brightness: brightness);
    }
    return fallback(brightness: brightness);
  }

  static bool isUsableAccent(Color color) {
    final r = (color.r * 255).round();
    final g = (color.g * 255).round();
    final b = (color.b * 255).round();
    if (r < 8 && g < 8 && b < 8) return false;
    if (r > 247 && g > 247 && b > 247) return false;
    return true;
  }
}

/// 澄波 Material 3 主题。默认种子是澄波蓝；Android 12+ 可改用壁纸配色。
abstract final class ChengboTheme {
  static const seed = Color(0xFF1565C0);
  static const railBreakpoint = 900.0;
  static const listBottomPadding = 16.0;

  static ThemeData light({ColorScheme? scheme}) =>
      _build(scheme ?? DynamicThemeLogic.fallback(brightness: Brightness.light));

  static ThemeData dark({ColorScheme? scheme}) =>
      _build(scheme ?? DynamicThemeLogic.fallback(brightness: Brightness.dark));

  static SystemUiOverlayStyle overlayFor(Brightness brightness, Color surface) {
    final lightIcons = brightness == Brightness.dark;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: lightIcons ? Brightness.light : Brightness.dark,
      statusBarBrightness: lightIcons ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: surface,
      systemNavigationBarIconBrightness: lightIcons ? Brightness.light : Brightness.dark,
    );
  }

  static ThemeData _build(ColorScheme scheme) {
    final brightness = scheme.brightness;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        scrolledUnderElevation: 0,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        systemOverlayStyle: overlayFor(brightness, scheme.surface),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: scheme.surface,
        indicatorColor: scheme.secondaryContainer,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 24,
            color: selected ? scheme.onSecondaryContainer : scheme.onSurfaceVariant,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.secondaryContainer,
        selectedIconTheme: IconThemeData(color: scheme.onSecondaryContainer),
        unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
        selectedLabelTextStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
        unselectedLabelTextStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: scheme.onSurfaceVariant,
        ),
      ),
      listTileTheme: ListTileThemeData(
        selectedTileColor: scheme.primaryContainer.withValues(alpha: 0.55),
        textColor: scheme.onSurface,
        iconColor: scheme.onSurfaceVariant,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        border: const OutlineInputBorder(),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      chipTheme: ChipThemeData(
        selectedColor: scheme.secondaryContainer,
        checkmarkColor: scheme.onSecondaryContainer,
        labelStyle: TextStyle(color: scheme.onSurface),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        space: 1,
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(color: scheme.onInverseSurface),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        dragHandleColor: scheme.onSurface.withValues(alpha: 0.25),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
    );
  }
}
