import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mugen_ui/app/providers.dart';
import 'package:mugen_ui/app/routing/route_ids.dart';
import 'package:mugen_ui/features/auth/presentation/providers/auth_providers.dart';
import 'package:mugen_ui/features/tenant_invite/domain/repositories/tenant_invitation_redeem_repository.dart';
import 'package:mugen_ui/features/tenant_invite/infrastructure/repositories/tenant_invitation_redeem_repository_impl.dart';
import 'package:mugen_ui/features/tenant_invite/presentation/providers/pending_invite_providers.dart';
import 'package:mugen_ui/shared/domain/failure.dart';

final tenantInvitationRedeemRepositoryProvider =
    Provider<TenantInvitationRedeemRepository>((ref) {
      return TenantInvitationRedeemRepositoryImpl(
        appConfig: ref.watch(appConfigProvider),
        cookieStore: ref.watch(cookieStoreProvider),
        authenticatedHttpClient: ref.watch(authenticatedHttpClientProvider),
      );
    });

enum InviteRedeemStatus {
  idle,
  loading,
  success,
  forbidden,
  notFound,
  conflict,
  invalidLink,
  sessionExpired,
  failure,
}

class InviteRedeemState {
  const InviteRedeemState({
    required this.status,
    required this.hasAttempted,
    this.message,
  });

  final InviteRedeemStatus status;
  final bool hasAttempted;
  final String? message;

  InviteRedeemState copyWith({
    InviteRedeemStatus? status,
    bool? hasAttempted,
    String? message,
    bool clearMessage = false,
  }) {
    return InviteRedeemState(
      status: status ?? this.status,
      hasAttempted: hasAttempted ?? this.hasAttempted,
      message: clearMessage ? null : (message ?? this.message),
    );
  }
}

final inviteRedeemControllerProvider =
    StateNotifierProvider<InviteRedeemController, InviteRedeemState>((ref) {
      return InviteRedeemController(ref);
    });

class InviteRedeemController extends StateNotifier<InviteRedeemState> {
  InviteRedeemController(this.ref)
    : super(
        const InviteRedeemState(
          status: InviteRedeemStatus.idle,
          hasAttempted: false,
        ),
      );

  final Ref ref;

  Future<void> redeem(InviteRouteMatch routeMatch) async {
    if (state.hasAttempted) {
      return;
    }

    final token = _resolveToken(routeMatch);
    if (token == null || token.isEmpty) {
      state = state.copyWith(
        status: InviteRedeemStatus.invalidLink,
        hasAttempted: true,
        message: 'Invite token is missing or invalid.',
      );
      return;
    }

    state = state.copyWith(
      status: InviteRedeemStatus.loading,
      hasAttempted: true,
      clearMessage: true,
    );

    final response = await ref
        .read(tenantInvitationRedeemRepositoryProvider)
        .redeemAuthenticated(
          tenantId: routeMatch.tenantId,
          invitationId: routeMatch.invitationId,
          token: token,
        );

    if (response.isFailure) {
      if (response.failure is SessionExpiredFailure) {
        ref.read(authControllerProvider.notifier).refreshSession();
        state = state.copyWith(
          status: InviteRedeemStatus.sessionExpired,
          message: 'Session expired. Redirecting to login.',
        );
        return;
      }

      state = state.copyWith(
        status: InviteRedeemStatus.failure,
        message: response.failure?.message ?? 'Redeem failed.',
      );
      return;
    }

    final result = response.data!;
    switch (result.outcome) {
      case InviteRedeemOutcome.success:
        state = state.copyWith(
          status: InviteRedeemStatus.success,
          message: 'Invitation redeemed successfully. Redirecting to app...',
        );
      case InviteRedeemOutcome.forbidden:
        state = state.copyWith(
          status: InviteRedeemStatus.forbidden,
          message:
              'This invite token is invalid for the active user or tenant.',
        );
      case InviteRedeemOutcome.notFound:
        state = state.copyWith(
          status: InviteRedeemStatus.notFound,
          message: 'The invitation link could not be found.',
        );
      case InviteRedeemOutcome.conflict:
        state = state.copyWith(
          status: InviteRedeemStatus.conflict,
          message:
              'This invitation can no longer be redeemed (expired, used, or revoked).',
        );
    }
  }

  String? _resolveToken(InviteRouteMatch routeMatch) {
    final routeToken = routeMatch.token?.trim();
    if (routeToken != null && routeToken.isNotEmpty) {
      ref.read(pendingInviteControllerProvider.notifier).clear();
      return routeToken;
    }

    final pending = ref
        .read(pendingInviteControllerProvider.notifier)
        .consumeFor(
          tenantId: routeMatch.tenantId,
          invitationId: routeMatch.invitationId,
        );
    final pendingToken = pending?.token?.trim();
    if (pendingToken == null || pendingToken.isEmpty) {
      return null;
    }

    return pendingToken;
  }
}
