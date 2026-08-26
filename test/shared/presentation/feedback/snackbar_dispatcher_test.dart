import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/shared/presentation/feedback/snackbar_dispatcher.dart';
import 'package:mugen_ui/shared/presentation/navigation/app_navigator.dart';

void main() {
  testWidgets(
    'SnackBarDispatcher.show delegates to current navigator context',
    (WidgetTester tester) async {
      late BuildContext scaffoldContext;
      final dispatcher = const SnackBarDispatcher();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                scaffoldContext = context;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final navigator = _ContextNavigator(scaffoldContext);
      dispatcher.show(navigator, 'Saved successfully');
      await tester.pump();

      expect(find.text('Saved successfully'), findsOneWidget);
    },
  );

  testWidgets('SnackBarDispatcher strips HTML from downstream messages', (
    WidgetTester tester,
  ) async {
    final dispatcher = const SnackBarDispatcher();
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (value) {
              context = value;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    dispatcher.showInContext(
      context,
      '<html><h1>Gateway failed</h1><p>Try again.</p></html>',
    );
    await tester.pump();

    expect(find.text('Gateway failed: Try again.'), findsOneWidget);
    expect(find.textContaining('<html>'), findsNothing);
  });
}

class _ContextNavigator extends AppNavigator {
  _ContextNavigator(this._context);

  final BuildContext _context;

  @override
  BuildContext? currentContext() => _context;
}
