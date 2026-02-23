import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mugen_ui/app/providers.dart';
import 'package:mugen_ui/app/routing/app_router.dart';
import 'package:mugen_ui/app/routing/route_ids.dart';
import 'package:mugen_ui/shared/presentation/theme/app_ui_palette.dart';

class MugenApp extends ConsumerWidget {
  const MugenApp({super.key}); // coverage:ignore-line

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final navigator = ref.watch(appNavigatorProvider);
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: AppUiPalette.accent,
          brightness: Brightness.light,
          surface: AppUiPalette.background,
        ).copyWith(
          primary: AppUiPalette.accent,
          onPrimary: Colors.white,
          surface: AppUiPalette.background,
          onSurface: AppUiPalette.textPrimary,
          onSurfaceVariant: AppUiPalette.textSecondary,
          outline: AppUiPalette.border,
          outlineVariant: AppUiPalette.borderStrong,
          error: AppUiPalette.danger,
          onError: Colors.white,
        );

    return MaterialApp(
      title: config.appName,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: AppUiPalette.background,
        dividerTheme: const DividerThemeData(
          color: AppUiPalette.border,
          thickness: 1,
        ),
        cardTheme: CardThemeData(
          color: AppUiPalette.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppUiPalette.border),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppUiPalette.background,
          elevation: 0,
          foregroundColor: AppUiPalette.textPrimary,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: AppUiPalette.border,
              width: 0.8,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: AppUiPalette.borderStrong,
              width: 1.0,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppUiPalette.danger),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppUiPalette.danger),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: AppUiPalette.textPrimary,
          contentTextStyle: const TextStyle(color: Colors.white),
          actionTextColor: Colors.white,
          closeIconColor: Colors.white,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      initialRoute: RouteIds.app,
      onGenerateRoute: AppRouter.onGenerateRoute,
      navigatorKey: navigator.navigatorKey,
    );
  }
}
