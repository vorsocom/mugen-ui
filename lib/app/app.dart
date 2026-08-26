import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mugen_ui/app/providers.dart';
import 'package:mugen_ui/app/routing/app_router.dart';
import 'package:mugen_ui/app/routing/route_ids.dart';
import 'package:mugen_ui/shared/presentation/admin/admin_components.dart';
import 'package:mugen_ui/shared/presentation/theme/app_ui_palette.dart';

class MugenApp extends ConsumerWidget {
  const MugenApp({super.key}); // coverage:ignore-line

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final navigator = ref.watch(appNavigatorProvider);
    ref.watch(browserChromeProvider).setFaviconHref(config.faviconHref);
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: AppUiPalette.accent,
          brightness: Brightness.light,
          surface: AppUiPalette.surface,
        ).copyWith(
          primary: AppUiPalette.accent,
          onPrimary: AppUiPalette.surface,
          primaryContainer: AppUiPalette.accentSoft,
          onPrimaryContainer: AppUiPalette.textPrimary,
          surface: AppUiPalette.surface,
          surfaceContainerLowest: AppUiPalette.userBar,
          surfaceContainerLow: AppUiPalette.background,
          surfaceContainer: AppUiPalette.surfaceMuted,
          surfaceContainerHigh: AppUiPalette.surfaceStrong,
          onSurface: AppUiPalette.textPrimary,
          onSurfaceVariant: AppUiPalette.textSecondary,
          outline: AppUiPalette.border,
          outlineVariant: AppUiPalette.borderStrong,
          error: AppUiPalette.danger,
          onError: AppUiPalette.surface,
        );
    final baseTextTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: 'Inter',
    ).textTheme;
    final textTheme = baseTextTheme
        .apply(
          bodyColor: AppUiPalette.textPrimary,
          displayColor: AppUiPalette.textPrimary,
        )
        .copyWith(
          headlineSmall: baseTextTheme.headlineSmall?.copyWith(
            fontSize: 26,
            height: 1.2,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.35,
          ),
          titleLarge: baseTextTheme.titleLarge?.copyWith(
            fontSize: 24,
            height: 1.2,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
          titleMedium: baseTextTheme.titleMedium?.copyWith(
            fontSize: 17,
            height: 1.3,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
          ),
          titleSmall: baseTextTheme.titleSmall?.copyWith(
            fontSize: 14,
            height: 1.35,
            fontWeight: FontWeight.w600,
          ),
          bodyLarge: baseTextTheme.bodyLarge?.copyWith(
            fontSize: 15,
            height: 1.45,
          ),
          bodyMedium: baseTextTheme.bodyMedium?.copyWith(
            fontSize: 14,
            height: 1.4,
          ),
          bodySmall: baseTextTheme.bodySmall?.copyWith(
            fontSize: 12,
            height: 1.4,
            color: AppUiPalette.textSecondary,
          ),
          labelLarge: baseTextTheme.labelLarge?.copyWith(
            fontSize: 14,
            height: 1.2,
            fontWeight: FontWeight.w600,
          ),
          labelMedium: baseTextTheme.labelMedium?.copyWith(
            fontSize: 12,
            height: 1.25,
            fontWeight: FontWeight.w600,
          ),
          labelSmall: baseTextTheme.labelSmall?.copyWith(
            fontSize: 11,
            height: 1.25,
            fontWeight: FontWeight.w600,
          ),
        );
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(adminRadius),
      borderSide: const BorderSide(color: AppUiPalette.border),
    );

    return MaterialApp(
      title: config.browserTitle ?? config.appName,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Inter',
        colorScheme: colorScheme,
        textTheme: textTheme,
        scaffoldBackgroundColor: AppUiPalette.background,
        canvasColor: AppUiPalette.surface,
        focusColor: AppUiPalette.focusRing,
        hoverColor: AppUiPalette.accent.withValues(alpha: 0.06),
        splashColor: AppUiPalette.accent.withValues(alpha: 0.08),
        highlightColor: AppUiPalette.accent.withValues(alpha: 0.04),
        materialTapTargetSize: MaterialTapTargetSize.padded,
        visualDensity: VisualDensity.standard,
        dividerTheme: const DividerThemeData(
          color: AppUiPalette.border,
          thickness: 1,
          space: 1,
        ),
        cardTheme: CardThemeData(
          color: AppUiPalette.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(adminRadius),
            side: const BorderSide(color: AppUiPalette.border),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppUiPalette.userBar,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          foregroundColor: AppUiPalette.textPrimary,
        ),
        drawerTheme: const DrawerThemeData(
          backgroundColor: AppUiPalette.drawer,
          surfaceTintColor: Colors.transparent,
          scrimColor: Color(0x8F262626),
          elevation: 0,
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: AppUiPalette.surface,
          surfaceTintColor: Colors.transparent,
          barrierColor: AppUiPalette.drawer.withValues(alpha: 0.62),
          elevation: 18,
          shadowColor: AppUiPalette.drawer.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppUiPalette.border),
          ),
        ),
        popupMenuTheme: PopupMenuThemeData(
          color: AppUiPalette.surface,
          surfaceTintColor: Colors.transparent,
          elevation: 10,
          shadowColor: AppUiPalette.drawer.withValues(alpha: 0.22),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppUiPalette.border),
          ),
        ),
        menuTheme: MenuThemeData(
          style: MenuStyle(
            backgroundColor: const WidgetStatePropertyAll(AppUiPalette.surface),
            surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
            side: const WidgetStatePropertyAll(
              BorderSide(color: AppUiPalette.border),
            ),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
        listTileTheme: const ListTileThemeData(
          iconColor: AppUiPalette.textSecondary,
          textColor: AppUiPalette.textPrimary,
          selectedColor: AppUiPalette.accent,
          selectedTileColor: AppUiPalette.accentSoft,
          minTileHeight: 44,
        ),
        dataTableTheme: DataTableThemeData(
          decoration: const BoxDecoration(color: AppUiPalette.surface),
          headingRowColor: const WidgetStatePropertyAll(
            AppUiPalette.surfaceMuted,
          ),
          dataRowColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppUiPalette.accentSoft;
            }
            if (states.contains(WidgetState.hovered)) {
              return AppUiPalette.userBar;
            }
            return AppUiPalette.surface;
          }),
          dividerThickness: 0.8,
          headingTextStyle: textTheme.labelMedium?.copyWith(
            color: AppUiPalette.textSecondary,
          ),
          dataTextStyle: textTheme.bodyMedium,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppUiPalette.surface,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
          hintStyle: textTheme.bodyMedium?.copyWith(
            color: AppUiPalette.textDisabled,
          ),
          labelStyle: textTheme.bodyMedium?.copyWith(
            color: AppUiPalette.textSecondary,
          ),
          floatingLabelStyle: textTheme.bodySmall?.copyWith(
            color: AppUiPalette.accent,
            fontWeight: FontWeight.w600,
          ),
          errorStyle: textTheme.bodySmall?.copyWith(color: AppUiPalette.danger),
          enabledBorder: inputBorder,
          disabledBorder: inputBorder.copyWith(
            borderSide: const BorderSide(color: AppUiPalette.surfaceStrong),
          ),
          focusedBorder: inputBorder.copyWith(
            borderSide: const BorderSide(
              color: AppUiPalette.accent,
              width: 1.5,
            ),
          ),
          errorBorder: inputBorder.copyWith(
            borderSide: const BorderSide(color: AppUiPalette.danger),
          ),
          focusedErrorBorder: inputBorder.copyWith(
            borderSide: const BorderSide(
              color: AppUiPalette.danger,
              width: 1.5,
            ),
          ),
          prefixIconColor: AppUiPalette.textMuted,
          suffixIconColor: AppUiPalette.textMuted,
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: AppUiPalette.drawerRaised,
          contentTextStyle: const TextStyle(color: AppUiPalette.drawerText),
          actionTextColor: AppUiPalette.drawerText,
          closeIconColor: AppUiPalette.drawerText,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, adminControlHeight),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(adminCompactRadius),
            ),
            backgroundColor: AppUiPalette.buttonPrimary,
            foregroundColor: AppUiPalette.surface,
            disabledBackgroundColor: AppUiPalette.surfaceStrong,
            disabledForegroundColor: AppUiPalette.textDisabled,
            overlayColor: AppUiPalette.surface.withValues(alpha: 0.12),
            elevation: 0,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, adminControlHeight),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(adminCompactRadius),
            ),
            side: const BorderSide(color: AppUiPalette.border),
            foregroundColor: AppUiPalette.textPrimary,
            disabledForegroundColor: AppUiPalette.textDisabled,
            backgroundColor: AppUiPalette.surface,
            overlayColor: AppUiPalette.accent.withValues(alpha: 0.06),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            minimumSize: const Size(0, adminControlHeight),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(adminCompactRadius),
            ),
            foregroundColor: AppUiPalette.textPrimary,
            disabledForegroundColor: AppUiPalette.textDisabled,
            overlayColor: AppUiPalette.accent.withValues(alpha: 0.06),
          ),
        ),
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(
            minimumSize: const Size(32, 32),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(adminCompactRadius),
            ),
            foregroundColor: AppUiPalette.textPrimary,
            disabledForegroundColor: AppUiPalette.textDisabled,
            overlayColor: AppUiPalette.accent.withValues(alpha: 0.07),
          ),
        ),
        checkboxTheme: CheckboxThemeData(
          fillColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppUiPalette.accent;
            }
            return Colors.transparent;
          }),
          checkColor: const WidgetStatePropertyAll(AppUiPalette.surface),
          side: const BorderSide(color: AppUiPalette.borderStrong),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        radioTheme: RadioThemeData(
          fillColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.selected)
                ? AppUiPalette.accent
                : AppUiPalette.textMuted;
          }),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.selected)
                ? AppUiPalette.surface
                : AppUiPalette.textDisabled;
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.selected)
                ? AppUiPalette.accent
                : AppUiPalette.surfaceStrong;
          }),
        ),
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: AppUiPalette.accent,
          selectionColor: AppUiPalette.focusRing,
          selectionHandleColor: AppUiPalette.accent,
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: AppUiPalette.accent,
          linearTrackColor: AppUiPalette.surfaceStrong,
        ),
        scrollbarTheme: ScrollbarThemeData(
          thumbColor: WidgetStatePropertyAll(
            AppUiPalette.textMuted.withValues(alpha: 0.42),
          ),
          trackColor: const WidgetStatePropertyAll(Colors.transparent),
          radius: const Radius.circular(999),
          thickness: const WidgetStatePropertyAll(7),
        ),
        tooltipTheme: TooltipThemeData(
          decoration: BoxDecoration(
            color: AppUiPalette.drawerRaised,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppUiPalette.drawerBorder),
          ),
          textStyle: textTheme.bodySmall?.copyWith(
            color: AppUiPalette.drawerText,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          waitDuration: const Duration(milliseconds: 350),
        ),
      ),
      initialRoute: AppRoutePaths.portal,
      onGenerateRoute: AppRouter.onGenerateRoute,
      navigatorKey: navigator.navigatorKey,
    );
  }
}
