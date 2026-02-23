import 'package:flutter/material.dart';

import 'package:mugen_ui/app/routing/route_ids.dart';
import 'package:mugen_ui/features/auth/presentation/pages/login_page.dart';
import 'package:mugen_ui/features/auth/presentation/widgets/auth_guard.dart';
import 'package:mugen_ui/features/shell/presentation/pages/shell_page.dart';
import 'package:mugen_ui/features/tenant_invite/presentation/pages/invite_redeem_page.dart';

class AppRouter {
  const AppRouter._(); // coverage:ignore-line

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    final inviteRoute = RouteIds.parseInviteRoute(settings.name);
    if (inviteRoute != null) {
      return MaterialPageRoute<dynamic>(
        builder: (_) =>
            AuthGuard(child: InviteRedeemPage(inviteRoute: inviteRoute)),
        settings: RouteSettings(
          name: RouteIds.buildInviteRoute(
            tenantId: inviteRoute.tenantId,
            invitationId: inviteRoute.invitationId,
          ),
        ),
      );
    }

    switch (settings.name) {
      case RouteIds.app:
        return MaterialPageRoute<dynamic>(
          builder: (_) => const AuthGuard(child: ShellPage()),
          settings: const RouteSettings(name: '/'),
        );
      case RouteIds.login:
        return MaterialPageRoute<dynamic>(
          builder: (_) => const AuthGuard(child: LoginPage()),
          settings: settings,
        );
      case '/':
        return null;
      default:
        return MaterialPageRoute<dynamic>(
          builder: (_) => const AuthGuard(child: ShellPage()),
          settings: const RouteSettings(name: '/'),
        );
    }
  }
}
