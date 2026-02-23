import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/app/routing/app_router.dart';
import 'package:mugen_ui/app/routing/route_ids.dart';
import 'package:mugen_ui/features/auth/presentation/widgets/auth_guard.dart';

void main() {
  test('AppRouter handles configured routes and unknown fallbacks', () {
    final appRoute = AppRouter.onGenerateRoute(
      const RouteSettings(name: RouteIds.app),
    );
    expect(appRoute, isA<MaterialPageRoute<dynamic>>());
    expect(appRoute?.settings.name, '/');

    final loginRoute = AppRouter.onGenerateRoute(
      const RouteSettings(name: RouteIds.login),
    );
    expect(loginRoute, isA<MaterialPageRoute<dynamic>>());
    expect(loginRoute?.settings.name, RouteIds.login);

    final rootRoute = AppRouter.onGenerateRoute(const RouteSettings(name: '/'));
    expect(rootRoute, isNull);

    final unknownRoute = AppRouter.onGenerateRoute(
      const RouteSettings(name: '/unknown'),
    );
    expect(unknownRoute, isA<MaterialPageRoute<dynamic>>());
    expect(unknownRoute?.settings.name, '/');
  });

  testWidgets('AppRouter unknown-route builder resolves AuthGuard shell', (
    WidgetTester tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (ctx) {
            context = ctx;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    final unknownRoute =
        AppRouter.onGenerateRoute(
              const RouteSettings(name: '/another-unknown'),
            )!
            as MaterialPageRoute<dynamic>;
    final built = unknownRoute.builder(context);
    expect(built, isA<AuthGuard>());
  });
}
