import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/app/providers.dart';
import 'package:mugen_ui/app/routing/route_ids.dart';
import 'package:mugen_ui/features/auth/presentation/providers/auth_providers.dart';
import 'package:mugen_ui/features/tenant_invite/domain/repositories/tenant_invitation_redeem_repository.dart';
import 'package:mugen_ui/features/tenant_invite/presentation/pages/invite_redeem_page.dart';
import 'package:mugen_ui/features/tenant_invite/presentation/providers/invite_redeem_providers.dart';
import 'package:mugen_ui/features/tenant_invite/presentation/providers/pending_invite_providers.dart';
import 'package:mugen_ui/shared/domain/result.dart';
import 'package:mugen_ui/shared/presentation/navigation/app_navigator.dart';

void main() {
  testWidgets('InviteRedeemPage renders all status visuals', (
    WidgetTester tester,
  ) async {
    final navigator = _FakeNavigator();
    final cases = <InviteRedeemStatus, String>{
      InviteRedeemStatus.idle: 'Preparing Invitation',
      InviteRedeemStatus.loading: 'Redeeming Invitation',
      InviteRedeemStatus.forbidden: 'Invite Validation Failed',
      InviteRedeemStatus.notFound: 'Invitation Not Found',
      InviteRedeemStatus.conflict: 'Invitation Not Redeemable',
      InviteRedeemStatus.invalidLink: 'Invalid Invite Link',
      InviteRedeemStatus.sessionExpired: 'Session Expired',
      InviteRedeemStatus.failure: 'Redeem Failed',
    };

    for (final entry in cases.entries) {
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            appNavigatorProvider.overrideWith((ref) => navigator),
            authControllerProvider.overrideWith(() => _TestAuthController()),
            inviteRedeemControllerProvider.overrideWith(
              (ref) => _StaticInviteRedeemController(
                ref,
                InviteRedeemState(
                  status: entry.key,
                  hasAttempted: entry.key != InviteRedeemStatus.idle,
                ),
              ),
            ),
          ],
          child: const MaterialApp(
            home: InviteRedeemPage(
              inviteRoute: InviteRouteMatch(
                tenantId: 'tenant-1',
                invitationId: 'invite-2',
                token: 'token',
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text(entry.value), findsOneWidget);
      if (entry.key == InviteRedeemStatus.loading) {
        expect(find.byType(LinearProgressIndicator), findsOneWidget);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('InviteRedeemPage redeems and redirects to /app on success', (
    WidgetTester tester,
  ) async {
    final repository = _FakeRedeemRepository();
    final pendingInviteController = PendingInviteController()
      ..setPending(
        const InviteRouteMatch(
          tenantId: 'tenant-1',
          invitationId: 'invite-2',
          token: 'token-1',
        ),
      );
    final navigator = _FakeNavigator();

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          tenantInvitationRedeemRepositoryProvider.overrideWithValue(
            repository,
          ),
          pendingInviteControllerProvider.overrideWith(
            (ref) => pendingInviteController,
          ),
          appNavigatorProvider.overrideWith((ref) => navigator),
          authControllerProvider.overrideWith(() => _TestAuthController()),
        ],
        child: const MaterialApp(
          home: InviteRedeemPage(
            inviteRoute: InviteRouteMatch(
              tenantId: 'tenant-1',
              invitationId: 'invite-2',
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    expect(find.text('Invitation Accepted'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    await tester.pump(const Duration(milliseconds: 950));
    expect(navigator.lastRoute, RouteIds.app);
    expect(repository.callCount, 1);
    expect(repository.lastToken, 'token-1');
  });
}

class _StaticInviteRedeemController extends InviteRedeemController {
  _StaticInviteRedeemController(super.ref, InviteRedeemState initial) {
    state = initial;
  }

  @override
  Future<void> redeem(InviteRouteMatch routeMatch) async {}
}

class _FakeRedeemRepository implements TenantInvitationRedeemRepository {
  int callCount = 0;
  String? lastToken;

  @override
  Future<Result<InviteRedeemResult>> redeemAuthenticated({
    required String tenantId,
    required String invitationId,
    required String token,
  }) async {
    callCount += 1;
    lastToken = token;
    return const Result<InviteRedeemResult>.success(
      InviteRedeemResult(outcome: InviteRedeemOutcome.success, statusCode: 204),
    );
  }
}

class _TestAuthController extends AuthController {
  @override
  AuthControllerState build() {
    return const AuthControllerState(isLoading: false, session: null);
  }

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
  String? lastRoute;

  @override
  Future<void> navigateTo(String routeName) async {
    lastRoute = routeName;
  }
}
