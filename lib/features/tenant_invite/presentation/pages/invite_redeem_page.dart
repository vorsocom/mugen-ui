import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mugen_ui/app/providers.dart';
import 'package:mugen_ui/app/routing/route_ids.dart';
import 'package:mugen_ui/features/tenant_invite/presentation/providers/invite_redeem_providers.dart';
import 'package:mugen_ui/shared/presentation/theme/app_form_style.dart';
import 'package:mugen_ui/shared/presentation/theme/app_ui_palette.dart';

class InviteRedeemPage extends ConsumerStatefulWidget {
  const InviteRedeemPage({
    // coverage:ignore-line
    super.key,
    required this.inviteRoute,
  }); // coverage:ignore-line

  final InviteRouteMatch inviteRoute;

  @override
  ConsumerState<InviteRedeemPage> createState() => _InviteRedeemPageState();
}

class _InviteRedeemPageState extends ConsumerState<InviteRedeemPage> {
  bool _queuedSuccessRedirect = false;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() {
      ref
          .read(inviteRedeemControllerProvider.notifier)
          .redeem(widget.inviteRoute);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inviteRedeemControllerProvider);
    final theme = Theme.of(context);

    if (state.status == InviteRedeemStatus.success) {
      _queueSuccessRedirect();
    }

    final statusVisuals = _statusVisuals(state.status);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: SizedBox(
            width: 520,
            child: AppFormPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: statusVisuals.backgroundColor,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          statusVisuals.icon,
                          color: statusVisuals.iconColor,
                          size: 19,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          statusVisuals.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (state.status == InviteRedeemStatus.loading)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: LinearProgressIndicator(),
                    ),
                  Text(
                    state.message ?? statusVisuals.defaultMessage,
                    key: const Key('invite-redeem-message'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppUiPalette.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _queueSuccessRedirect() {
    if (_queuedSuccessRedirect) {
      return;
    }

    _queuedSuccessRedirect = true;
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 900), () async {
        if (!mounted) {
          return;
        }

        await ref.read(appNavigatorProvider).navigateTo(AppRoutePaths.app);
      }),
    );
  }
}

class _InviteRedeemVisuals {
  const _InviteRedeemVisuals({
    required this.title,
    required this.defaultMessage,
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
  });

  final String title;
  final String defaultMessage;
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
}

_InviteRedeemVisuals _statusVisuals(InviteRedeemStatus status) {
  switch (status) {
    case InviteRedeemStatus.idle:
      return const _InviteRedeemVisuals(
        title: 'Preparing Invitation',
        defaultMessage: 'Preparing invite details.',
        icon: Icons.link,
        iconColor: AppUiPalette.textPrimary,
        backgroundColor: AppUiPalette.surfaceStrong,
      );
    case InviteRedeemStatus.loading:
      return const _InviteRedeemVisuals(
        title: 'Redeeming Invitation',
        defaultMessage: 'Please wait while we redeem your invitation.',
        icon: Icons.hourglass_top_outlined,
        iconColor: AppUiPalette.textPrimary,
        backgroundColor: AppUiPalette.surfaceStrong,
      );
    case InviteRedeemStatus.success:
      return _InviteRedeemVisuals(
        title: 'Invitation Accepted',
        defaultMessage: 'Invitation redeemed successfully. Redirecting to app.',
        icon: Icons.check_circle_outline,
        iconColor: Colors.green.shade700,
        backgroundColor: Colors.green.shade50,
      );
    case InviteRedeemStatus.forbidden:
      return _InviteRedeemVisuals(
        title: 'Invite Validation Failed',
        defaultMessage:
            'This invite token is invalid for the active user or tenant.',
        icon: Icons.block_outlined,
        iconColor: Colors.orange.shade800,
        backgroundColor: Colors.orange.shade50,
      );
    case InviteRedeemStatus.notFound:
      return _InviteRedeemVisuals(
        title: 'Invitation Not Found',
        defaultMessage: 'The invitation link could not be found.',
        icon: Icons.search_off_outlined,
        iconColor: Colors.orange.shade800,
        backgroundColor: Colors.orange.shade50,
      );
    case InviteRedeemStatus.conflict:
      return _InviteRedeemVisuals(
        title: 'Invitation Not Redeemable',
        defaultMessage:
            'This invitation can no longer be redeemed (expired, used, or revoked).',
        icon: Icons.info_outline,
        iconColor: Colors.orange.shade800,
        backgroundColor: Colors.orange.shade50,
      );
    case InviteRedeemStatus.invalidLink:
      return _InviteRedeemVisuals(
        title: 'Invalid Invite Link',
        defaultMessage: 'Invite token is missing or invalid.',
        icon: Icons.link_off_outlined,
        iconColor: Colors.red.shade700,
        backgroundColor: Colors.red.shade50,
      );
    case InviteRedeemStatus.sessionExpired:
      return _InviteRedeemVisuals(
        title: 'Session Expired',
        defaultMessage: 'Session expired. Redirecting to login.',
        icon: Icons.login_outlined,
        iconColor: Colors.red.shade700,
        backgroundColor: Colors.red.shade50,
      );
    case InviteRedeemStatus.failure:
      return _InviteRedeemVisuals(
        title: 'Redeem Failed',
        defaultMessage:
            'Unable to redeem the invitation due to a network issue.',
        icon: Icons.error_outline,
        iconColor: Colors.red.shade700,
        backgroundColor: Colors.red.shade50,
      );
  }
}
