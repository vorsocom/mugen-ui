import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mugen_ui/app/config/app_config.dart';
import 'package:mugen_ui/app/routing/route_ids.dart';
import 'package:mugen_ui/features/shell/application/shell_route_access.dart';

void main() {
  test(
    'resolveShellRouteAccess redirects unauthorized routes to allowed default',
    () {
      final config = _routeAccessConfig();

      final access = resolveShellRouteAccess(
        config: config,
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
      final config = _routeAccessConfig(spaDefaultRoute: RouteIds.localUsers);

      final access = resolveShellRouteAccess(
        config: config,
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
    final config = _routeAccessConfig();

    final access = resolveShellRouteAccess(
      config: config,
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
      final config = AppConfig.defaults().merge(
        const AppConfigurationOverride(
          drawerItems: <DrawerItemConfig>[
            DrawerItemConfig(
              title: 'Runtime Control',
              icon: Icons.settings_input_component_outlined,
              route: RouteIds.runtimeControl,
            ),
          ],
          spaDefaultRoute: RouteIds.runtimeControl,
          spaRoutes: <SpaRouteConfig>[
            SpaRouteConfig(
              id: RouteIds.runtimeControl,
              title: 'Runtime Control',
              roles: <String>['com.vorsocomputing.mugen.acp:administrator'],
            ),
          ],
        ),
      );

      final access = resolveShellRouteAccess(
        config: config,
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

AppConfig _routeAccessConfig({String spaDefaultRoute = RouteIds.chat}) {
  return AppConfig.defaults()
      .merge(
        const AppConfigurationOverride(
          drawerItems: <DrawerItemConfig>[
            DrawerItemConfig(
              title: 'AI Assist',
              icon: Icons.chat_bubble_outline,
              route: RouteIds.chat,
            ),
            DrawerItemConfig(
              title: 'LocalUsers',
              icon: Icons.groups_outlined,
              route: RouteIds.localUsers,
              section: 'Platform Configuration',
            ),
          ],
          spaRoutes: <SpaRouteConfig>[
            SpaRouteConfig(id: RouteIds.chat, title: 'AI Assist'),
            SpaRouteConfig(
              id: RouteIds.localUsers,
              title: 'LocalUsers',
              roles: <String>['com.vorsocomputing.mugen.acp:administrator'],
            ),
          ],
        ),
      )
      .merge(AppConfigurationOverride(spaDefaultRoute: spaDefaultRoute));
}
