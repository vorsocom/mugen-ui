import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/shared/presentation/theme/app_form_style.dart';

void main() {
  testWidgets('AppFormDialog shrink-wraps short form content', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpDialogLauncher(
      tester,
      dialog: const AppFormDialog(
        title: 'Short form',
        maxWidth: 520,
        maxHeight: 760,
        scrollable: false,
        body: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [TextField(decoration: InputDecoration(labelText: 'Name'))],
        ),
        actions: [Text('Cancel'), Text('Save')],
      ),
    );

    final dialogSize = tester.getSize(find.byType(AppFormPanel));
    expect(dialogSize.width, lessThanOrEqualTo(520));
    expect(dialogSize.height, lessThan(300));
    expect(find.byType(Divider), findsNWidgets(2));
    expect(find.byTooltip('Close'), findsOneWidget);
    expect(find.byKey(const Key('app-form-dialog-body-scroll')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AppFormDialog caps and scrolls tall form content', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(700, 420));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpDialogLauncher(
      tester,
      dialog: AppFormDialog(
        title: 'Tall form',
        maxWidth: 520,
        maxHeight: 760,
        body: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var index = 0; index < 12; index++) ...[
              const SizedBox(height: 12),
              SizedBox(height: 48, child: Text('Field ${index + 1}')),
            ],
          ],
        ),
        actions: const [Text('Submit', key: Key('tall-form-submit'))],
      ),
    );

    expect(
      tester.getSize(find.byType(AppFormPanel)).height,
      lessThanOrEqualTo(372),
    );
    final scrollable = find.descendant(
      of: find.byType(AppFormDialog),
      matching: find.byType(Scrollable),
    );
    final scrollableState = tester.state<ScrollableState>(scrollable);
    expect(scrollableState.position.maxScrollExtent, greaterThan(0));

    expect(
      find.byKey(const Key('tall-form-submit')).hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('AppResponsiveDialog can scroll generic constrained content', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 320));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpDialogLauncher(
      tester,
      dialog: const AppResponsiveDialog(
        maxWidth: 600,
        maxHeight: 600,
        scrollable: true,
        child: SizedBox(
          key: Key('generic-dialog-content'),
          width: 600,
          height: 600,
        ),
      ),
    );

    final dialogSize = tester.getSize(
      find.descendant(
        of: find.byType(AppResponsiveDialog),
        matching: find.byType(SingleChildScrollView),
      ),
    );
    expect(dialogSize.width, lessThanOrEqualTo(312));
    expect(dialogSize.height, lessThanOrEqualTo(272));
    expect(
      find.descendant(
        of: find.byType(AppResponsiveDialog),
        matching: find.byType(SingleChildScrollView),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

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

  testWidgets('AppErrorAlert renders and copies error details', (
    WidgetTester tester,
  ) async {
    String? copiedText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        if (call.method == 'Clipboard.setData') {
          final arguments = Map<Object?, Object?>.from(
            call.arguments as Map<Object?, Object?>,
          );
          copiedText = arguments['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppErrorAlert(
            message: '  Error details  ',
            copyButtonKey: Key('copy-error'),
          ),
        ),
      ),
    );

    expect(find.text('Error details'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.byTooltip('Copy error details'), findsOneWidget);

    await tester.tap(find.byKey(const Key('copy-error')));
    await tester.pump();

    expect(copiedText, 'Error details');
  });

  testWidgets('AppErrorAlert never renders or copies HTML markup', (
    WidgetTester tester,
  ) async {
    String? copiedText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        if (call.method == 'Clipboard.setData') {
          final arguments = Map<Object?, Object?>.from(
            call.arguments as Map<Object?, Object?>,
          );
          copiedText = arguments['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppErrorAlert(
            message:
                '<html><h1>Access denied</h1><p>Request &amp; retry.</p></html>',
            copyButtonKey: Key('copy-normalized-error'),
          ),
        ),
      ),
    );

    expect(find.text('Access denied: Request & retry.'), findsOneWidget);
    expect(find.textContaining('<html>'), findsNothing);

    await tester.tap(find.byKey(const Key('copy-normalized-error')));
    await tester.pump();

    expect(copiedText, 'Access denied: Request & retry.');
  });
}

Future<void> _pumpDialogLauncher(
  WidgetTester tester, {
  required Widget dialog,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: FilledButton(
            key: const Key('open-dialog'),
            onPressed: () =>
                showDialog<void>(context: context, builder: (_) => dialog),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const Key('open-dialog')));
  await tester.pumpAndSettle();
}
