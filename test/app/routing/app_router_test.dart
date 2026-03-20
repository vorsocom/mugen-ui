import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/app/definition/app_definition.dart';
import 'package:mugen_ui/app/routing/app_router.dart';
import 'package:mugen_ui/app/routing/route_ids.dart';

void main() {
  test('AppRouter handles configured routes and unknown fallbacks', () {
    final routes = <TopLevelRouteDefinition>[
      TopLevelRouteDefinition.exact(
        id: 'shell.app',
        path: AppRoutePaths.app,
        builder: _buildShellMarker,
      ),
      TopLevelRouteDefinition.exact(
        id: 'auth.login',
        path: AppRoutePaths.login,
        builder: _buildLoginMarker,
      ),
      TopLevelRouteDefinition.parsed<InviteRouteMatch>(
        id: 'invite.redeem',
        parse: AppRoutePaths.parseInviteRoute,
        canonicalLocation: (inviteRoute) => AppRoutePaths.buildInviteRoute(
          tenantId: inviteRoute.tenantId,
          invitationId: inviteRoute.invitationId,
        ),
        builder: (context, inviteRoute) =>
            Text('Invite ${inviteRoute.tenantId}/${inviteRoute.invitationId}'),
      ),
    ];

    final appRoute = AppRouter.onGenerateRouteWithDefinitions(
      settings: const RouteSettings(name: AppRoutePaths.app),
      topLevelRoutes: routes,
      fallbackRoutePath: AppRoutePaths.app,
    );
    expect(appRoute, isA<MaterialPageRoute<dynamic>>());
    expect(appRoute?.settings.name, AppRoutePaths.app);

    final loginRoute = AppRouter.onGenerateRouteWithDefinitions(
      settings: const RouteSettings(name: AppRoutePaths.login),
      topLevelRoutes: routes,
      fallbackRoutePath: AppRoutePaths.app,
    );
    expect(loginRoute, isA<MaterialPageRoute<dynamic>>());
    expect(loginRoute?.settings.name, AppRoutePaths.login);

    final rootRoute = AppRouter.onGenerateRouteWithDefinitions(
      settings: const RouteSettings(name: '/'),
      topLevelRoutes: routes,
      fallbackRoutePath: AppRoutePaths.app,
    );
    expect(rootRoute, isNull);

    final unknownRoute = AppRouter.onGenerateRouteWithDefinitions(
      settings: const RouteSettings(name: '/unknown'),
      topLevelRoutes: routes,
      fallbackRoutePath: AppRoutePaths.app,
    );
    expect(unknownRoute, isA<MaterialPageRoute<dynamic>>());
    expect(unknownRoute?.settings.name, AppRoutePaths.app);

    final inviteRoute = AppRouter.onGenerateRouteWithDefinitions(
      settings: const RouteSettings(
        name: '/invite/tenant-1/invite-2?token=abc',
      ),
      topLevelRoutes: routes,
      fallbackRoutePath: AppRoutePaths.app,
    );
    expect(inviteRoute, isA<MaterialPageRoute<dynamic>>());
    expect(inviteRoute?.settings.name, '/invite/tenant-1/invite-2');
  });

  testWidgets(
    'AppRouter resolves a downstream exact route without core edits',
    (WidgetTester tester) async {
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

      final route =
          AppRouter.onGenerateRouteWithDefinitions(
                settings: const RouteSettings(name: '/reports'),
                topLevelRoutes: <TopLevelRouteDefinition>[
                  TopLevelRouteDefinition.exact(
                    id: 'shell.app',
                    path: AppRoutePaths.app,
                    builder: _buildShellMarker,
                  ),
                  TopLevelRouteDefinition.exact(
                    id: 'downstream.reports',
                    path: '/reports',
                    builder: _buildReportsMarker,
                  ),
                ],
                fallbackRoutePath: AppRoutePaths.app,
              )!
              as MaterialPageRoute<dynamic>;

      expect(route.settings.name, '/reports');
      expect(route.builder(context), isA<Text>());
      expect((route.builder(context) as Text).data, 'Reports');
    },
  );

  testWidgets('AppRouter resolves a parsed downstream route', (
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

    final route =
        AppRouter.onGenerateRouteWithDefinitions(
              settings: const RouteSettings(name: '/tenant/acme/orders/42'),
              topLevelRoutes: <TopLevelRouteDefinition>[
                TopLevelRouteDefinition.exact(
                  id: 'shell.app',
                  path: AppRoutePaths.app,
                  builder: _buildShellMarker,
                ),
                TopLevelRouteDefinition.parsed<_OrderRouteMatch>(
                  id: 'downstream.orders.detail',
                  parse: _parseOrderRoute,
                  canonicalLocation: (match) => match.location,
                  builder: (context, match) =>
                      Text('Order ${match.tenantId}/${match.orderId}'),
                ),
              ],
              fallbackRoutePath: AppRoutePaths.app,
            )!
            as MaterialPageRoute<dynamic>;

    expect(route.settings.name, '/tenant/acme/orders/42');
    expect((route.builder(context) as Text).data, 'Order acme/42');
  });

  test('AppRoutePaths invite helpers parse and canonicalize invite links', () {
    final parsed = AppRoutePaths.parseInviteRoute('/invite/t1/i1?token=abc123');
    expect(parsed, isNotNull);
    expect(parsed?.tenantId, 't1');
    expect(parsed?.invitationId, 'i1');
    expect(parsed?.token, 'abc123');
    expect(parsed?.hasToken, isTrue);

    expect(AppRoutePaths.parseInviteRoute('/invite/t1'), isNull);
    expect(AppRoutePaths.parseInviteRoute('/another/path'), isNull);
    expect(
      AppRoutePaths.buildInviteRoute(
        tenantId: 'tenant',
        invitationId: 'invite',
      ),
      '/invite/tenant/invite',
    );
    expect(
      AppRoutePaths.buildInviteRoute(
        tenantId: 'tenant',
        invitationId: 'invite',
        token: 'a b',
      ),
      '/invite/tenant/invite?token=a+b',
    );
  });

  test('RouteIds invite helpers remain compatible aliases', () {
    expect(
      RouteIds.buildInviteRoute(tenantId: 'tenant', invitationId: 'invite'),
      '/invite/tenant/invite',
    );
    expect(RouteIds.parseInviteRoute('/invite/t1/i1?token=abc')?.token, 'abc');
  });

  test('AppRouter throws when fallback route cannot match itself', () {
    expect(
      () => AppRouter.onGenerateRouteWithDefinitions(
        settings: const RouteSettings(name: '/unknown'),
        topLevelRoutes: <TopLevelRouteDefinition>[
          TopLevelRouteDefinition(
            id: 'bad.fallback',
            exactPath: AppRoutePaths.app,
            match: (_) => null,
            builder: (context, match) => const SizedBox.shrink(),
          ),
        ],
        fallbackRoutePath: AppRoutePaths.app,
      ),
      throwsStateError,
    );
  });
}

class _OrderRouteMatch {
  const _OrderRouteMatch({required this.tenantId, required this.orderId});

  final String tenantId;
  final String orderId;

  String get location => '/tenant/$tenantId/orders/$orderId';
}

_OrderRouteMatch? _parseOrderRoute(String? routeName) {
  final uri = Uri.tryParse(routeName ?? '');
  if (uri == null) {
    return null;
  }

  final segments = uri.pathSegments;
  if (segments.length != 4 ||
      segments[0] != 'tenant' ||
      segments[2] != 'orders') {
    return null;
  }

  return _OrderRouteMatch(tenantId: segments[1], orderId: segments[3]);
}

Widget _buildShellMarker(BuildContext context) => const Text('Shell');

Widget _buildLoginMarker(BuildContext context) => const Text('Login');

Widget _buildReportsMarker(BuildContext context) => const Text('Reports');
