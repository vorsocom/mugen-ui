import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/shared/presentation/navigation/app_navigator.dart';

void main() {
  testWidgets(
    'AppNavigator can push, pop, replace routes, and report context',
    (WidgetTester tester) async {
      final navigator = AppNavigator();

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator.navigatorKey,
          initialRoute: '/',
          routes: <String, WidgetBuilder>{
            '/': (_) => const Scaffold(body: Text('home')),
            '/next': (_) => const Scaffold(body: Text('next')),
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(navigator.currentContext(), isNotNull);
      expect(navigator.currentRoute(), '/');

      final pushFuture = navigator.pushRoute(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: '/pushed'),
          builder: (_) => const Scaffold(body: Text('pushed')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('pushed'), findsOneWidget);
      expect(navigator.currentRoute(), '/pushed');

      navigator.pop();
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
      expect(navigator.currentRoute(), '/');
      await pushFuture;

      final navigateFuture = navigator.navigateTo('/next');
      await tester.pumpAndSettle();
      expect(find.text('next'), findsOneWidget);
      expect(navigator.currentRoute(), '/next');

      navigator.pop();
      await tester.pumpAndSettle();
      await navigateFuture;
    },
  );
}
