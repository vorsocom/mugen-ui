import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mugen_ui/app/app.dart';
import 'package:mugen_ui/app/config/app_config.dart';
import 'package:mugen_ui/app/providers.dart';

void main() {
  testWidgets('MugenApp uses browser title when configured', (
    WidgetTester tester,
  ) async {
    final config = AppConfig.defaults().merge(
      const AppConfigurationOverride(
        appName: 'Redcell',
        browserTitle: 'Redcell Wargaming Console',
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[appConfigProvider.overrideWith((ref) => config)],
        child: const MugenApp(),
      ),
    );

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.title, 'Redcell Wargaming Console');
  });

  testWidgets('smoke test navigates unauthenticated users to login', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: MugenApp()));

    await tester.pumpAndSettle();

    expect(find.text('Log in'), findsOneWidget);
  });
}
