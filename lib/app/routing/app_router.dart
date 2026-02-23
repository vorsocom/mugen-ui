import 'package:flutter/material.dart';

import 'package:mugen_ui/app/routing/route_ids.dart';
import 'package:mugen_ui/features/auth/presentation/pages/login_page.dart';
import 'package:mugen_ui/features/auth/presentation/widgets/auth_guard.dart';
import 'package:mugen_ui/features/shell/presentation/pages/shell_page.dart';

class AppRouter {
  const AppRouter._();

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
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
