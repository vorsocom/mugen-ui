import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/app/routing/route_ids.dart';
import 'package:mugen_ui/features/auth/presentation/providers/auth_providers.dart';
import 'package:mugen_ui/features/tenant_invite/domain/repositories/tenant_invitation_redeem_repository.dart';
import 'package:mugen_ui/features/tenant_invite/infrastructure/repositories/tenant_invitation_redeem_repository_impl.dart';
import 'package:mugen_ui/features/tenant_invite/presentation/providers/invite_redeem_providers.dart';
import 'package:mugen_ui/features/tenant_invite/presentation/providers/pending_invite_providers.dart';
import 'package:mugen_ui/shared/domain/failure.dart';
import 'package:mugen_ui/shared/domain/result.dart';

void main() {
  test(
    'invite providers build default repository and support state helpers',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        container.read(tenantInvitationRedeemRepositoryProvider),
        isA<TenantInvitationRedeemRepositoryImpl>(),
      );

      const baseState = InviteRedeemState(
        status: InviteRedeemStatus.idle,
        hasAttempted: false,
        message: 'keep',
      );
      final updated = baseState.copyWith(
        status: InviteRedeemStatus.loading,
        hasAttempted: true,
      );
      expect(updated.status, InviteRedeemStatus.loading);
      expect(updated.hasAttempted, isTrue);
      expect(updated.message, 'keep');

      final cleared = baseState.copyWith(clearMessage: true);
      expect(cleared.message, isNull);

      final pendingController = PendingInviteController()
        ..setPending(
          const InviteRouteMatch(
            tenantId: 't',
            invitationId: 'i',
            token: 'tok',
          ),
        );
      final consumed = pendingController.consume();
      expect(consumed?.tenantId, 't');
      expect(consumed?.invitationId, 'i');
      expect(pendingController.state, isNull);
    },
  );

  test(
    'InviteRedeemController maps success and consumes pending token',
    () async {
      final repository = _FakeRedeemRepository();
      final pendingController = PendingInviteController()
        ..setPending(
          const InviteRouteMatch(
            tenantId: 'tenant-1',
            invitationId: 'invite-1',
            token: 'pending-token',
          ),
        );
      final container = ProviderContainer(
        overrides: <Override>[
          tenantInvitationRedeemRepositoryProvider.overrideWithValue(
            repository,
          ),
          pendingInviteControllerProvider.overrideWith(
            (ref) => pendingController,
          ),
          authControllerProvider.overrideWith(() => _TestAuthController()),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(inviteRedeemControllerProvider.notifier)
          .redeem(
            const InviteRouteMatch(
              tenantId: 'tenant-1',
              invitationId: 'invite-1',
            ),
          );

      final state = container.read(inviteRedeemControllerProvider);
      expect(state.status, InviteRedeemStatus.success);
      expect(state.hasAttempted, isTrue);
      expect(repository.lastToken, 'pending-token');
      expect(pendingController.state, isNull);
    },
  );

  test(
    'InviteRedeemController maps forbidden/notFound/conflict outcomes',
    () async {
      final forbiddenRepo = _FakeRedeemRepository()
        ..nextResult = const Result<InviteRedeemResult>.success(
          InviteRedeemResult(
            outcome: InviteRedeemOutcome.forbidden,
            statusCode: 403,
          ),
        );
      final forbiddenContainer = ProviderContainer(
        overrides: <Override>[
          tenantInvitationRedeemRepositoryProvider.overrideWithValue(
            forbiddenRepo,
          ),
          authControllerProvider.overrideWith(() => _TestAuthController()),
        ],
      );
      addTearDown(forbiddenContainer.dispose);
      await forbiddenContainer
          .read(inviteRedeemControllerProvider.notifier)
          .redeem(
            const InviteRouteMatch(
              tenantId: 'tenant',
              invitationId: 'invite',
              token: 't',
            ),
          );
      expect(
        forbiddenContainer.read(inviteRedeemControllerProvider).status,
        InviteRedeemStatus.forbidden,
      );

      final notFoundRepo = _FakeRedeemRepository()
        ..nextResult = const Result<InviteRedeemResult>.success(
          InviteRedeemResult(
            outcome: InviteRedeemOutcome.notFound,
            statusCode: 404,
          ),
        );
      final notFoundContainer = ProviderContainer(
        overrides: <Override>[
          tenantInvitationRedeemRepositoryProvider.overrideWithValue(
            notFoundRepo,
          ),
          authControllerProvider.overrideWith(() => _TestAuthController()),
        ],
      );
      addTearDown(notFoundContainer.dispose);
      await notFoundContainer
          .read(inviteRedeemControllerProvider.notifier)
          .redeem(
            const InviteRouteMatch(
              tenantId: 'tenant',
              invitationId: 'invite',
              token: 't',
            ),
          );
      expect(
        notFoundContainer.read(inviteRedeemControllerProvider).status,
        InviteRedeemStatus.notFound,
      );

      final conflictRepo = _FakeRedeemRepository()
        ..nextResult = const Result<InviteRedeemResult>.success(
          InviteRedeemResult(
            outcome: InviteRedeemOutcome.conflict,
            statusCode: 409,
          ),
        );
      final conflictContainer = ProviderContainer(
        overrides: <Override>[
          tenantInvitationRedeemRepositoryProvider.overrideWithValue(
            conflictRepo,
          ),
          authControllerProvider.overrideWith(() => _TestAuthController()),
        ],
      );
      addTearDown(conflictContainer.dispose);
      await conflictContainer
          .read(inviteRedeemControllerProvider.notifier)
          .redeem(
            const InviteRouteMatch(
              tenantId: 'tenant',
              invitationId: 'invite',
              token: 't',
            ),
          );
      expect(
        conflictContainer.read(inviteRedeemControllerProvider).status,
        InviteRedeemStatus.conflict,
      );
    },
  );

  test(
    'InviteRedeemController handles invalid links, session expiry, and generic failures',
    () async {
      final missingTokenContainer = ProviderContainer(
        overrides: <Override>[
          tenantInvitationRedeemRepositoryProvider.overrideWithValue(
            _FakeRedeemRepository(),
          ),
          authControllerProvider.overrideWith(() => _TestAuthController()),
        ],
      );
      addTearDown(missingTokenContainer.dispose);
      await missingTokenContainer
          .read(inviteRedeemControllerProvider.notifier)
          .redeem(
            const InviteRouteMatch(tenantId: 'tenant', invitationId: 'invite'),
          );
      expect(
        missingTokenContainer.read(inviteRedeemControllerProvider).status,
        InviteRedeemStatus.invalidLink,
      );

      final authController = _TestAuthController();
      final sessionRepo = _FakeRedeemRepository()
        ..nextResult = const Result<InviteRedeemResult>.failure(
          SessionExpiredFailure(),
        );
      final sessionContainer = ProviderContainer(
        overrides: <Override>[
          tenantInvitationRedeemRepositoryProvider.overrideWithValue(
            sessionRepo,
          ),
          authControllerProvider.overrideWith(() => authController),
        ],
      );
      addTearDown(sessionContainer.dispose);
      await sessionContainer
          .read(inviteRedeemControllerProvider.notifier)
          .redeem(
            const InviteRouteMatch(
              tenantId: 'tenant',
              invitationId: 'invite',
              token: 't',
            ),
          );
      expect(
        sessionContainer.read(inviteRedeemControllerProvider).status,
        InviteRedeemStatus.sessionExpired,
      );
      expect(authController.refreshCallCount, 1);

      final failureRepo = _FakeRedeemRepository()
        ..nextResult = const Result<InviteRedeemResult>.failure(
          UnexpectedFailure('boom'),
        );
      final failureContainer = ProviderContainer(
        overrides: <Override>[
          tenantInvitationRedeemRepositoryProvider.overrideWithValue(
            failureRepo,
          ),
          authControllerProvider.overrideWith(() => _TestAuthController()),
        ],
      );
      addTearDown(failureContainer.dispose);
      final notifier = failureContainer.read(
        inviteRedeemControllerProvider.notifier,
      );
      await notifier.redeem(
        const InviteRouteMatch(
          tenantId: 'tenant',
          invitationId: 'invite',
          token: 't',
        ),
      );
      await notifier.redeem(
        const InviteRouteMatch(
          tenantId: 'tenant',
          invitationId: 'invite',
          token: 'other',
        ),
      );
      expect(
        failureContainer.read(inviteRedeemControllerProvider).status,
        InviteRedeemStatus.failure,
      );
      expect(failureRepo.callCount, 1);
    },
  );
}

class _FakeRedeemRepository implements TenantInvitationRedeemRepository {
  Result<InviteRedeemResult> nextResult =
      const Result<InviteRedeemResult>.success(
        InviteRedeemResult(
          outcome: InviteRedeemOutcome.success,
          statusCode: 204,
        ),
      );
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
    return nextResult;
  }
}

class _TestAuthController extends AuthController {
  int refreshCallCount = 0;

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
  void refreshSession() {
    refreshCallCount += 1;
  }

  @override
  bool hasRoles(List<String> roles, {String operator = 'and'}) => true;
}
