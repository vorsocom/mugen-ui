import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/shared/presentation/theme/app_form_style.dart';

void main() {
  testWidgets('appFormInputDecoration renders help tooltip with suffix icon', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: TextField(decoration: InputDecoration())),
      ),
    );

    final decoration = appFormInputDecoration(
      labelText: 'Search',
      suffixIcon: const Icon(Icons.search),
      helpText: 'Use stable backend identifiers when searching.',
      helpKey: const Key('search-help'),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: TextField(decoration: decoration)),
      ),
    );

    final tooltip = tester.widget<Tooltip>(
      find.byKey(const Key('search-help')),
    );
    expect(tooltip.message, 'Use stable backend identifiers when searching.');
    expect(find.byIcon(Icons.search), findsOneWidget);
  });

  testWidgets('appFieldLabelWithHelp omits tooltip for blank help text', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: appFieldLabelWithHelp(
            labelText: 'Name',
            helpText: '  ',
            helpKey: const Key('name-help'),
          ),
        ),
      ),
    );

    expect(find.text('Name'), findsOneWidget);
    expect(find.byKey(const Key('name-help')), findsNothing);
  });

  testWidgets('appFieldLabelWithHelp renders tooltip for nonblank help text', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: appFieldLabelWithHelp(
            labelText: 'Provider',
            helpText: 'Choose managed for tenant-owned secrets.',
            helpKey: const Key('provider-help'),
          ),
        ),
      ),
    );

    final tooltip = tester.widget<Tooltip>(
      find.byKey(const Key('provider-help')),
    );
    expect(tooltip.message, 'Choose managed for tenant-owned secrets.');
  });

  testWidgets(
    'appFormInputDecoration renders help tooltip without suffix icon',
    (WidgetTester tester) async {
      final decoration = appFormInputDecoration(
        labelText: 'Key',
        helpText: 'Use a stable schema key.',
        helpKey: const Key('key-help'),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TextField(decoration: decoration)),
        ),
      );

      final tooltip = tester.widget<Tooltip>(find.byKey(const Key('key-help')));
      expect(tooltip.message, 'Use a stable schema key.');
    },
  );
}
