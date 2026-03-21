import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mugen_ui/app/app.dart';

void main() {
  testWidgets('smoke test navigates unauthenticated users to login', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: MugenApp()));

    await tester.pumpAndSettle();

    expect(find.text('Log in'), findsOneWidget);
  });
}
