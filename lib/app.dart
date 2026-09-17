import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:system_theme/system_theme.dart';

import 'core/brand.dart';
import 'core/platform/desk_compact.dart';
import 'core/providers/app_providers.dart';
import 'core/theme.dart';
import 'features/home/home_shell.dart';
import 'shared/widgets/desk_hotkey_scope.dart';

class ChengboApp extends ConsumerWidget {
  const ChengboApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final useDynamic = ref.watch(dynamicColorProvider).value ?? true;
    final pack = AppSkinLogic.pack(ref.watch(appSkinProvider));
    final dynamicEnabled = pack.isDefault && useDynamic;
    final effectiveMode = pack.lockDark ? ThemeMode.dark : themeMode;

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        final accent = SystemTheme.accentColor.accent;
        final light = ChengboTheme.light(
          pack: pack,
          scheme: DynamicThemeLogic.resolve(
            brightness: Brightness.light,
            enabled: dynamicEnabled,
            platformScheme: lightDynamic?.harmonized(),
            accent: accent,
          ),
        );
        final dark = ChengboTheme.dark(
          pack: pack,
          scheme: DynamicThemeLogic.resolve(
            brightness: Brightness.dark,
            enabled: dynamicEnabled,
            platformScheme: darkDynamic?.harmonized(),
            accent: accent,
          ),
        );

        return AnimatedTheme(
          data: switch (effectiveMode) {
            ThemeMode.light => light,
            ThemeMode.dark => dark,
            ThemeMode.system =>
              WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark
                  ? dark
                  : light,
          },
          curve: Curves.easeInOut,
          duration: const Duration(milliseconds: 200),
          child: MaterialApp(
            title: AppBrand.displayName,
            debugShowCheckedModeBanner: false,
            color: DeskCompactLogic.offeredOnThisPlatform ? const Color(0x00000000) : null,
            themeMode: effectiveMode,
            theme: light,
            darkTheme: dark,
            builder: (context, child) {
              final theme = Theme.of(context);
              return DeskHotkeyScope(
                child: AnnotatedRegion<SystemUiOverlayStyle>(
                  value: ChengboTheme.overlayFor(theme.brightness, theme.colorScheme.surface),
                  child: child ?? const SizedBox.shrink(),
                ),
              );
            },
            home: const HomeShell(),
          ),
        );
      },
    );
  }
}
