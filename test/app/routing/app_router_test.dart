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

    final inviteRoute = AppRouter.onGenerateRoute(
      const RouteSettings(name: '/invite/tenant-1/invite-2?token=abc'),
    );
    expect(inviteRoute, isA<MaterialPageRoute<dynamic>>());
    expect(inviteRoute?.settings.name, '/invite/tenant-1/invite-2');
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

  testWidgets('AppRouter invite-route builder resolves AuthGuard invite page', (
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

    final inviteRoute =
        AppRouter.onGenerateRoute(
              const RouteSettings(name: '/invite/t1/i1?token=abc'),
            )!
            as MaterialPageRoute<dynamic>;
    final built = inviteRoute.builder(context);
    expect(built, isA<AuthGuard>());
  });

  test('RouteIds invite helpers parse and canonicalize invite links', () {
    final parsed = RouteIds.parseInviteRoute('/invite/t1/i1?token=abc123');
    expect(parsed, isNotNull);
    expect(parsed?.tenantId, 't1');
    expect(parsed?.invitationId, 'i1');
    expect(parsed?.token, 'abc123');
    expect(parsed?.hasToken, isTrue);

    expect(RouteIds.parseInviteRoute('/invite/t1'), isNull);
    expect(RouteIds.parseInviteRoute('/another/path'), isNull);
    expect(
      RouteIds.buildInviteRoute(tenantId: 'tenant', invitationId: 'invite'),
      '/invite/tenant/invite',
    );
    expect(
      RouteIds.buildInviteRoute(
        tenantId: 'tenant',
        invitationId: 'invite',
        token: 'a b',
      ),
      '/invite/tenant/invite?token=a+b',
    );
  });
}
