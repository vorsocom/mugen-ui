import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mugen_ui/app/providers.dart';
import 'package:mugen_ui/app/routing/route_ids.dart';
import 'package:mugen_ui/features/auth/presentation/providers/auth_providers.dart';
import 'package:mugen_ui/features/auth/presentation/widgets/auth_guard.dart';
import 'package:mugen_ui/features/tenant_invite/presentation/providers/pending_invite_providers.dart';
import 'package:mugen_ui/shared/domain/value_objects/auth_session.dart';
import 'package:mugen_ui/shared/presentation/navigation/app_navigator.dart';

void main() {
  testWidgets('AuthGuard redirects authenticated users away from login route', (
    WidgetTester tester,
  ) async {
    final authController = _TestAuthController(
      initialState: const AuthControllerState(
        isLoading: false,
        session: AuthSession(
          accessToken: 'a',
          refreshToken: 'r',
          userId: 'u1',
          roles: <String>[],
        ),
      ),
    );
    final navigator = _FakeNavigator(route: RouteIds.login);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          authControllerProvider.overrideWith(() => authController),
          appNavigatorProvider.overrideWith((ref) => navigator),
        ],
        child: const MaterialApp(home: AuthGuard(child: Text('guarded-child'))),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const Key('auth-guard-loading-indicator')),
      findsOneWidget,
    );
    await tester.pump();
    expect(navigator.lastRoute, RouteIds.app);
  });

  testWidgets(
    'AuthGuard redirects authenticated login route to pending invite route',
    (WidgetTester tester) async {
      final authController = _TestAuthController(
        initialState: const AuthControllerState(
          isLoading: false,
          session: AuthSession(
            accessToken: 'a',
            refreshToken: 'r',
            userId: 'u1',
            roles: <String>[],
          ),
        ),
      );
      final navigator = _FakeNavigator(route: RouteIds.login);
      final pendingInviteController = PendingInviteController()
        ..setPending(
          const InviteRouteMatch(
            tenantId: 'tenant-1',
            invitationId: 'invite-2',
            token: 'token-1',
          ),
        );

      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            authControllerProvider.overrideWith(() => authController),
            appNavigatorProvider.overrideWith((ref) => navigator),
            pendingInviteControllerProvider.overrideWith(
              (ref) => pendingInviteController,
            ),
          ],
          child: const MaterialApp(
            home: AuthGuard(child: Text('guarded-child')),
          ),
        ),
      );
      await tester.pump();

      expect(navigator.lastRoute, '/invite/tenant-1/invite-2');
    },
  );

  testWidgets(
    'AuthGuard captures unauthenticated invite and redirects to login',
    (WidgetTester tester) async {
      final authController = _TestAuthController(
        initialState: const AuthControllerState(
          isLoading: false,
          session: null,
        ),
      );
      final navigator = _FakeNavigator(
        route: '/invite/tenant-1/invite-2?token=abc',
      );
      final pendingInviteController = PendingInviteController();

      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            authControllerProvider.overrideWith(() => authController),
            appNavigatorProvider.overrideWith((ref) => navigator),
            pendingInviteControllerProvider.overrideWith(
              (ref) => pendingInviteController,
            ),
          ],
          child: const MaterialApp(
            home: AuthGuard(child: Text('guarded-child')),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(navigator.lastRoute, RouteIds.login);
      final pending = pendingInviteController.state;
      expect(pending, isNotNull);
      expect(pending?.tenantId, 'tenant-1');
      expect(pending?.invitationId, 'invite-2');
      expect(pending?.token, 'abc');
    },
  );

  testWidgets('AuthGuard canonicalizes authenticated invite route with token', (
    WidgetTester tester,
  ) async {
    final authController = _TestAuthController(
      initialState: const AuthControllerState(
        isLoading: false,
        session: AuthSession(
          accessToken: 'a',
          refreshToken: 'r',
          userId: 'u1',
          roles: <String>[],
        ),
      ),
    );
    final navigator = _FakeNavigator(route: '/invite/t1/i1?token=tok');
    final pendingInviteController = PendingInviteController();

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          authControllerProvider.overrideWith(() => authController),
          appNavigatorProvider.overrideWith((ref) => navigator),
          pendingInviteControllerProvider.overrideWith(
            (ref) => pendingInviteController,
          ),
        ],
        child: const MaterialApp(home: AuthGuard(child: Text('guarded-child'))),
      ),
    );

    await tester.pump();
    await tester.pump();

    expect(navigator.lastRoute, '/invite/t1/i1');
    expect(pendingInviteController.state?.token, 'tok');
  });

  testWidgets('AuthGuard renders child for authenticated non-login route', (
    WidgetTester tester,
  ) async {
    final authController = _TestAuthController(
      initialState: const AuthControllerState(
        isLoading: false,
        session: AuthSession(
          accessToken: 'a',
          refreshToken: 'r',
          userId: 'u1',
          roles: <String>[],
        ),
      ),
    );
    final navigator = _FakeNavigator(route: RouteIds.app);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          authControllerProvider.overrideWith(() => authController),
          appNavigatorProvider.overrideWith((ref) => navigator),
        ],
        child: const MaterialApp(home: AuthGuard(child: Text('guarded-child'))),
      ),
    );
    await tester.pump();

    expect(find.text('guarded-child'), findsOneWidget);
    expect(find.byKey(const Key('auth-guard-loading-indicator')), findsNothing);
    expect(navigator.lastRoute, isNull);
  });
}

class _TestAuthController extends AuthController {
  _TestAuthController({required this.initialState});

  final AuthControllerState initialState;

  @override
  AuthControllerState build() => initialState;

  @override
  Future<bool> login({
    required String username,
    required String password,
  }) async {
    return true;
  }

  @override
  Future<bool> logout() async => true;

  @override
  bool hasRoles(List<String> roles, {String operator = 'and'}) => true;
}

class _FakeNavigator extends AppNavigator {
  _FakeNavigator({required this.route});

  final String route;
  String? lastRoute;

  @override
  String? currentRoute() => route;

  @override
  Future<void> navigateTo(String routeName) async {
    lastRoute = routeName;
  }
}
