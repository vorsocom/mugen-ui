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
}

class _ContextNavigator extends AppNavigator {
  _ContextNavigator(this._context);

  final BuildContext _context;

  @override
  BuildContext? currentContext() => _context;
}
