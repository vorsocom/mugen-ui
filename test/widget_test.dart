import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mugen_ui/app/app.dart';
import 'package:mugen_ui/app/browser_chrome.dart';
import 'package:mugen_ui/app/config/app_config.dart';
import 'package:mugen_ui/app/providers.dart';
import 'package:mugen_ui/shared/presentation/admin/admin_components.dart';
import 'package:mugen_ui/shared/presentation/theme/app_ui_palette.dart';

void main() {
  testWidgets('MugenApp applies configured browser chrome', (
    WidgetTester tester,
  ) async {
    final browserChrome = _RecordingBrowserChrome();
    final config = AppConfig.defaults().merge(
      const AppConfigurationOverride(
        appName: 'Redcell',
        browserTitle: 'Redcell Wargaming Console',
        faviconHref: 'assets/branding/redcell-favicon.svg',
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appConfigProvider.overrideWith((ref) => config),
          browserChromeProvider.overrideWithValue(browserChrome),
        ],
        child: const MugenApp(),
      ),
    );

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.title, 'Redcell Wargaming Console');
    final theme = app.theme!;
    expect(theme.textTheme.bodyMedium?.fontFamily, 'Inter');
    expect(theme.textTheme.labelLarge?.fontFamily, 'Inter');
    expect(AppUiPalette.background, Colors.white);
    expect(AppUiPalette.userBar, Colors.white);
    expect(AppUiPalette.surface, Colors.white);
    expect(AppUiPalette.surfaceMuted, const Color(0xFFF5F5F5));
    expect(AppUiPalette.surfaceStrong, const Color(0xFFE5E5E5));
    expect(AppUiPalette.border, const Color(0xFFD4D4D4));
    expect(AppUiPalette.borderStrong, const Color(0xFFA3A3A3));
    expect(AppUiPalette.textPrimary, const Color(0xFF262626));
    expect(AppUiPalette.textSecondary, const Color(0xFF525252));
    expect(AppUiPalette.textMuted, const Color(0xFF737373));
    expect(AppUiPalette.textDisabled, const Color(0xFFA3A3A3));
    expect(AppUiPalette.drawerText, const Color(0xFFE5E5E5));
    expect(AppUiPalette.drawerTextMuted, const Color(0xFFA3A3A3));
    expect(theme.scaffoldBackgroundColor, AppUiPalette.background);
    expect(theme.drawerTheme.scrimColor, const Color(0x8F262626));
    expect(theme.colorScheme.primary, AppUiPalette.accent);
    expect(AppUiPalette.accent, AppUiPalette.buttonPrimary);
    expect(AppUiPalette.accent, const Color(0xFF40546A));
    expect(theme.drawerTheme.backgroundColor, AppUiPalette.drawer);
    expect(theme.dialogTheme.backgroundColor, AppUiPalette.surface);
    expect(
      (theme.inputDecorationTheme.focusedBorder! as OutlineInputBorder)
          .borderSide
          .color,
      AppUiPalette.accent,
    );
    expect(
      theme.filledButtonTheme.style?.backgroundColor?.resolve(<WidgetState>{}),
      AppUiPalette.buttonPrimary,
    );
    expect(
      theme.dataTableTheme.dataRowColor?.resolve(<WidgetState>{
        WidgetState.selected,
      }),
      AppUiPalette.accentSoft,
    );
    expect(
      theme.dataTableTheme.dataRowColor?.resolve(<WidgetState>{
        WidgetState.hovered,
      }),
      AppUiPalette.userBar,
    );
    expect(
      theme.dataTableTheme.dataRowColor?.resolve(<WidgetState>{}),
      AppUiPalette.surface,
    );
    expect(
      theme.checkboxTheme.fillColor?.resolve(<WidgetState>{
        WidgetState.selected,
      }),
      AppUiPalette.accent,
    );
    expect(
      theme.checkboxTheme.fillColor?.resolve(<WidgetState>{}),
      Colors.transparent,
    );
    expect(
      theme.radioTheme.fillColor?.resolve(<WidgetState>{WidgetState.selected}),
      AppUiPalette.accent,
    );
    expect(
      theme.radioTheme.fillColor?.resolve(<WidgetState>{}),
      AppUiPalette.textMuted,
    );
    expect(
      theme.switchTheme.thumbColor?.resolve(<WidgetState>{
        WidgetState.selected,
      }),
      AppUiPalette.surface,
    );
    expect(
      theme.switchTheme.thumbColor?.resolve(<WidgetState>{}),
      AppUiPalette.textDisabled,
    );
    expect(
      theme.switchTheme.trackColor?.resolve(<WidgetState>{
        WidgetState.selected,
      }),
      AppUiPalette.accent,
    );
    expect(
      theme.switchTheme.trackColor?.resolve(<WidgetState>{}),
      AppUiPalette.surfaceStrong,
    );
    expect(
      browserChrome.faviconHrefs,
      contains('assets/branding/redcell-favicon.svg'),
    );
  });

  testWidgets('smoke test navigates unauthenticated users to login', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: MugenApp()));

    await tester.pumpAndSettle();

    expect(find.text('Log in'), findsOneWidget);
  });

  testWidgets('screen tabs use a graphite underline and neutral count badges', (
    WidgetTester tester,
  ) async {
    var selectedPrices = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminTabs(
            items: <AdminTabItem>[
              AdminTabItem(
                key: const Key('products-tab'),
                label: 'Products',
                count: 4,
                selected: true,
                onSelected: () {},
              ),
              AdminTabItem(
                key: const Key('prices-tab'),
                label: 'Prices',
                count: 8,
                selected: false,
                onSelected: () => selectedPrices = true,
              ),
            ],
          ),
        ),
      ),
    );

    final tabs = find.byType(AdminTabs);
    final tabDecorations = tester
        .widgetList<AnimatedContainer>(
          find.descendant(of: tabs, matching: find.byType(AnimatedContainer)),
        )
        .map((widget) => widget.decoration! as BoxDecoration)
        .toList(growable: false);
    expect(
      (tabDecorations.first.border! as Border).bottom.color,
      AppUiPalette.accent,
    );
    expect(
      (tabDecorations.last.border! as Border).bottom.color,
      Colors.transparent,
    );
    expect(
      tester.widget<Text>(find.text('Products')).style?.color,
      AppUiPalette.accent,
    );
    expect(
      tester.widget<Text>(find.text('Prices')).style?.color,
      AppUiPalette.textSecondary,
    );

    await tester.tap(find.byKey(const Key('prices-tab')));
    expect(selectedPrices, isTrue);
  });

  testWidgets('admin surfaces clip children and keep their border above them', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AdminSurface(
            padding: EdgeInsets.zero,
            child: ColoredBox(
              color: AppUiPalette.surfaceMuted,
              child: SizedBox(width: 240, height: 80),
            ),
          ),
        ),
      ),
    );

    final surface = tester.widget<Container>(
      find.descendant(
        of: find.byType(AdminSurface),
        matching: find.byType(Container),
      ),
    );
    expect(surface.clipBehavior, Clip.antiAlias);
    final foreground = surface.foregroundDecoration! as BoxDecoration;
    expect(foreground.borderRadius, BorderRadius.circular(adminRadius));
    expect((foreground.border! as Border).top.color, AppUiPalette.border);
  });
}

class _RecordingBrowserChrome implements BrowserChrome {
  final List<String?> faviconHrefs = <String?>[];

  @override
  void setFaviconHref(String? href) {
    faviconHrefs.add(href);
  }
}
