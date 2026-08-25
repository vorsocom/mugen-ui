import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mugen_ui/app/config/app_config.dart';
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
          webPlatformAccessRole,
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
          webPlatformAccessRole,
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
        webPlatformAccessRole,
      ],
      requestedRoute: 'mystery-route',
    );

    expect(access.isKnownRoute, isFalse);
    expect(access.shouldRedirect, isFalse);
    expect(access.displayedRouteId, 'mystery-route');
    expect(access.showLockedOutState, isFalse);
  });

  test(
    'resolveShellRouteAccess returns locked-out state when chat permission is missing',
    () {
      final access = resolveShellRouteAccess(
        shellRoutes: _routeAccessRoutes(),
        defaultShellRouteId: RouteIds.chat,
        sessionRoles: const <String>[
          'com.vorsocomputing.mugen.acp:authenticated',
        ],
        requestedRoute: RouteIds.chat,
      );

      expect(access.isKnownRoute, isTrue);
      expect(access.isUnauthorizedKnownRoute, isTrue);
      expect(access.shouldRedirect, isFalse);
      expect(access.showLockedOutState, isTrue);
      expect(access.displayedRouteId, isNull);
      expect(access.allowedRoutes, isEmpty);
    },
  );

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

  test('runtime availability hides pending and unavailable routes', () {
    const pending = ShellRouteAvailability.pending();
    const available = ShellRouteAvailability.available();
    const unavailable = ShellRouteAvailability.unavailable(
      'Billing extension is disabled.',
    );
    final explicit = ShellRouteAvailability(
      status: ShellRouteAvailabilityStatus.values[1],
      message: String.fromCharCodes(<int>[114, 101, 97, 100, 121]),
    );

    expect(pending.status, ShellRouteAvailabilityStatus.pending);
    expect(pending.message, isNull);
    expect(available.status, ShellRouteAvailabilityStatus.available);
    expect(unavailable.status, ShellRouteAvailabilityStatus.unavailable);
    expect(explicit.message, 'ready');

    final pendingAccess = resolveShellRouteAccess(
      shellRoutes: _billingRoutes(),
      defaultShellRouteId: RouteIds.chat,
      sessionRoles: const <String>[webPlatformAccessRole],
      requestedRoute: RouteIds.billingCatalog,
      routeAvailabilities: const <String, ShellRouteAvailability>{
        RouteIds.billingCatalog: pending,
      },
    );
    expect(pendingAccess.isPendingKnownRoute, isTrue);
    expect(pendingAccess.isUnauthorizedKnownRoute, isFalse);
    expect(pendingAccess.shouldRedirect, isFalse);
    expect(pendingAccess.displayedRouteId, RouteIds.billingCatalog);
    expect(pendingAccess.allowedRouteIds, <String>{RouteIds.chat});

    final unavailableAccess = resolveShellRouteAccess(
      shellRoutes: _billingRoutes(),
      defaultShellRouteId: RouteIds.chat,
      sessionRoles: const <String>[webPlatformAccessRole],
      requestedRoute: RouteIds.billingCatalog,
      routeAvailabilities: const <String, ShellRouteAvailability>{
        RouteIds.billingCatalog: unavailable,
      },
    );
    expect(unavailableAccess.isPendingKnownRoute, isFalse);
    expect(unavailableAccess.isUnauthorizedKnownRoute, isTrue);
    expect(unavailableAccess.shouldRedirect, isTrue);
    expect(unavailableAccess.canonicalRouteId, RouteIds.chat);
    expect(unavailableAccess.denialMessage, 'Billing extension is disabled.');

    final availableAccess = resolveShellRouteAccess(
      shellRoutes: _billingRoutes(),
      defaultShellRouteId: RouteIds.chat,
      sessionRoles: const <String>[webPlatformAccessRole],
      requestedRoute: RouteIds.billingCatalog,
      routeAvailabilities: const <String, ShellRouteAvailability>{
        RouteIds.billingCatalog: available,
      },
    );
    expect(availableAccess.isAllowedRoute, isTrue);
    expect(availableAccess.allowedRouteIds, <String>{
      RouteIds.chat,
      RouteIds.billingCatalog,
    });
    expect(availableAccess.denialMessage, isNull);
  });

  test('pending route still requires its declared session roles', () {
    final access = resolveShellRouteAccess(
      shellRoutes: const <ShellRouteDefinition>[
        ShellRouteDefinition(
          id: RouteIds.billingCatalog,
          title: 'Billing Catalog',
          icon: Icons.payments_outlined,
          requiredRoles: <String>['billing-reader'],
          builder: _buildPlaceholderPage,
        ),
      ],
      defaultShellRouteId: RouteIds.billingCatalog,
      sessionRoles: const <String>[],
      requestedRoute: RouteIds.billingCatalog,
      routeAvailabilities: const <String, ShellRouteAvailability>{
        RouteIds.billingCatalog: ShellRouteAvailability.pending(),
      },
    );

    expect(access.isPendingKnownRoute, isFalse);
    expect(access.showLockedOutState, isTrue);
    expect(access.canonicalRouteId, RouteIds.billingCatalog);
  });
}

List<ShellRouteDefinition> _routeAccessRoutes() {
  return const <ShellRouteDefinition>[
    ShellRouteDefinition(
      id: RouteIds.chat,
      title: 'AI Assist',
      icon: Icons.chat_bubble_outline,
      requiredRoles: <String>[webPlatformAccessRole],
      builder: _buildPlaceholderPage,
    ),
    ShellRouteDefinition(
      id: RouteIds.localUsers,
      title: 'Local Users',
      icon: Icons.groups_outlined,
      requiredRoles: <String>['com.vorsocomputing.mugen.acp:administrator'],
      builder: _buildPlaceholderPage,
    ),
  ];
}

Widget _buildPlaceholderPage(BuildContext context) {
  return const SizedBox.shrink();
}

List<ShellRouteDefinition> _billingRoutes() {
  return const <ShellRouteDefinition>[
    ShellRouteDefinition(
      id: RouteIds.chat,
      title: 'AI Assist',
      icon: Icons.chat_bubble_outline,
      requiredRoles: <String>[webPlatformAccessRole],
      builder: _buildPlaceholderPage,
    ),
    ShellRouteDefinition(
      id: RouteIds.billingCatalog,
      title: 'Billing Catalog',
      icon: Icons.payments_outlined,
      builder: _buildPlaceholderPage,
    ),
  ];
}
