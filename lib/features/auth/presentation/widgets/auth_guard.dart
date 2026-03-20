import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mugen_ui/app/providers.dart';
import 'package:mugen_ui/app/routing/route_ids.dart';
import 'package:mugen_ui/features/auth/presentation/providers/auth_providers.dart';
import 'package:mugen_ui/features/tenant_invite/presentation/providers/pending_invite_providers.dart';

const Key _authGuardLoadingIndicatorKey = Key('auth-guard-loading-indicator');

class AuthGuard extends ConsumerWidget {
  const AuthGuard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final navigator = ref.watch(appNavigatorProvider);
    final route = navigator.currentRoute();
    final inviteRoute = AppRoutePaths.parseInviteRoute(route);

    if (!authState.isAuthenticated) {
      if (inviteRoute != null) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          ref
              .read(pendingInviteControllerProvider.notifier)
              .setPending(inviteRoute);
        });
      }

      if (route != AppRoutePaths.login) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          navigator.navigateTo(AppRoutePaths.login);
        });

        return const _AuthGuardLoadingView();
      }

      return child;
    }

    if (route == AppRoutePaths.login) {
      final pendingInvite = ref.read(pendingInviteControllerProvider);
      final targetRoute = pendingInvite == null
          ? AppRoutePaths.app
          : AppRoutePaths.buildInviteRoute(
              tenantId: pendingInvite.tenantId,
              invitationId: pendingInvite.invitationId,
            );
      SchedulerBinding.instance.addPostFrameCallback((_) {
        navigator.navigateTo(targetRoute);
      });

      return const _AuthGuardLoadingView();
    }

    if (inviteRoute != null && inviteRoute.hasToken) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        ref
            .read(pendingInviteControllerProvider.notifier)
            .setPending(inviteRoute);
        navigator.navigateTo(
          AppRoutePaths.buildInviteRoute(
            tenantId: inviteRoute.tenantId,
            invitationId: inviteRoute.invitationId,
          ),
        );
      });

      return const _AuthGuardLoadingView();
    }

    return child;
  }
}

class _AuthGuardLoadingView extends StatelessWidget {
  const _AuthGuardLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            key: _authGuardLoadingIndicatorKey,
            strokeWidth: 2.2,
          ),
        ),
      ),
    );
  }
}
