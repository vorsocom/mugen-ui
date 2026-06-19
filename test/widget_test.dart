import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mugen_ui/app/app.dart';
import 'package:mugen_ui/app/browser_chrome.dart';
import 'package:mugen_ui/app/config/app_config.dart';
import 'package:mugen_ui/app/providers.dart';

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
}

class _RecordingBrowserChrome implements BrowserChrome {
  final List<String?> faviconHrefs = <String?>[];

  @override
  void setFaviconHref(String? href) {
    faviconHrefs.add(href);
  }
}
