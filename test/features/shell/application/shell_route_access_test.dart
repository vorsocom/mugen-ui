import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mugen_ui/app/definition/app_definition.dart';
import 'package:mugen_ui/app/routing/route_ids.dart';
import 'package:mugen_ui/features/shell/application/shell_route_access.dart';

void main() {
  test(
    'resolveShellRouteAccess redirects unauthorized routes to allowed default',
    () {
      final access = resolveShellRouteAccess(
        shellRoutes: _routeAccessRoutes(),
        defaultShellRouteId: RouteIds.chat,
        sessionRoles: const <String>[
          'com.vorsocomputing.mugen.acp:authenticated',
        ],
        requestedRoute: RouteIds.localUsers,
      );

      expect(access.isKnownRoute, isTrue);
      expect(access.isUnauthorizedKnownRoute, isTrue);
      expect(access.shouldRedirect, isTrue);
      expect(access.displayedRouteId, RouteIds.chat);
      expect(access.canonicalRouteId, RouteIds.chat);
    },
  );

  test(
    'resolveShellRouteAccess falls back to first allowed route when default is unauthorized',
    () {
      final access = resolveShellRouteAccess(
        shellRoutes: _routeAccessRoutes(),
        defaultShellRouteId: RouteIds.localUsers,
        sessionRoles: const <String>[
          'com.vorsocomputing.mugen.acp:authenticated',
        ],
        requestedRoute: RouteIds.localUsers,
      );

      expect(access.shouldRedirect, isTrue);
      expect(access.displayedRouteId, RouteIds.chat);
      expect(access.fallbackRoute?.id, RouteIds.chat);
    },
  );

  test('resolveShellRouteAccess preserves unknown routes', () {
    final access = resolveShellRouteAccess(
      shellRoutes: _routeAccessRoutes(),
      defaultShellRouteId: RouteIds.chat,
      sessionRoles: const <String>[
        'com.vorsocomputing.mugen.acp:authenticated',
      ],
      requestedRoute: 'mystery-route',
    );

    expect(access.isKnownRoute, isFalse);
    expect(access.shouldRedirect, isFalse);
    expect(access.displayedRouteId, 'mystery-route');
    expect(access.showLockedOutState, isFalse);
  });

  test(
    'resolveShellRouteAccess returns locked-out state when no routes are allowed',
    () {
      final access = resolveShellRouteAccess(
        shellRoutes: const <ShellRouteDefinition>[
          ShellRouteDefinition(
            id: RouteIds.runtimeControl,
            title: 'Runtime Control',
            icon: Icons.settings_input_component_outlined,
            requiredRoles: <String>[
              'com.vorsocomputing.mugen.acp:administrator',
            ],
            builder: _buildPlaceholderPage,
          ),
        ],
        defaultShellRouteId: RouteIds.runtimeControl,
        sessionRoles: const <String>[
          'com.vorsocomputing.mugen.acp:authenticated',
        ],
        requestedRoute: RouteIds.runtimeControl,
      );

      expect(access.shouldRedirect, isFalse);
      expect(access.showLockedOutState, isTrue);
      expect(access.displayedRouteId, isNull);
      expect(access.allowedRoutes, isEmpty);
    },
  );
}

List<ShellRouteDefinition> _routeAccessRoutes() {
  return const <ShellRouteDefinition>[
    ShellRouteDefinition(
      id: RouteIds.chat,
      title: 'AI Assist',
      icon: Icons.chat_bubble_outline,
      builder: _buildPlaceholderPage,
    ),
    ShellRouteDefinition(
      id: RouteIds.localUsers,
      title: 'LocalUsers',
      icon: Icons.groups_outlined,
      requiredRoles: <String>['com.vorsocomputing.mugen.acp:administrator'],
      builder: _buildPlaceholderPage,
    ),
  ];
}

Widget _buildPlaceholderPage(BuildContext context) {
  return const SizedBox.shrink();
}
