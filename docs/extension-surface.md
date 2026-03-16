# Extension Surface Guide

The project exposes two first-class extension points under `lib/extension/`.

## Extension Files

1. `lib/extension/configuration.dart`
2. `lib/extension/provider_overrides.dart`

`lib/app/providers.dart` and `lib/app/bootstrap.dart` consume these files during app startup.

## 1) Typed Configuration Override

Use `configurationOverride` to customize compile-time app behavior without dynamic maps.

```dart
import 'package:flutter/material.dart';
import 'package:mugen_ui/app/config/app_config.dart';
import 'package:mugen_ui/app/routing/route_ids.dart';

const AppConfigurationOverride configurationOverride = AppConfigurationOverride(
  appName: 'muGen UI (ACME)',
  appVersion: '1.2.3',
  api: ApiConfigOverride(
    baseUrl: 'https://acme.example.com/api',
  ),
  drawerItems: <DrawerItemConfig>[
    DrawerItemConfig(
      title: 'Dashboard',
      icon: Icons.home_outlined,
      route: RouteIds.dashboard,
    ),
    DrawerItemConfig(
      title: 'Chat',
      icon: Icons.chat_bubble_outline,
      route: RouteIds.chat,
    ),
    DrawerItemConfig(
      title: 'Tenant Management',
      icon: Icons.apartment_outlined,
      route: RouteIds.tenantManagement,
      section: 'Platform Configuration',
      roles: <String>['com.vorsocomputing.mugen.acp:administrator'],
    ),
    DrawerItemConfig(
      title: 'Role & Permission Management',
      icon: Icons.admin_panel_settings_outlined,
      route: RouteIds.rolePermissionManagement,
      section: 'Platform Configuration',
      roles: <String>['com.vorsocomputing.mugen.acp:administrator'],
    ),
    DrawerItemConfig(
      title: 'Runtime Control',
      icon: Icons.settings_input_component_outlined,
      route: RouteIds.runtimeControl,
      section: 'Platform Configuration',
      roles: <String>['com.vorsocomputing.mugen.acp:administrator'],
    ),
    DrawerItemConfig(
      title: 'Channel Orchestration',
      icon: Icons.alt_route_outlined,
      route: RouteIds.channelOrchestration,
      section: 'Platform Configuration',
      roles: <String>['com.vorsocomputing.mugen.acp:administrator'],
    ),
    DrawerItemConfig(
      title: 'Context Engine',
      icon: Icons.hub_outlined,
      route: RouteIds.contextEngine,
      section: 'Platform Configuration',
      roles: <String>['com.vorsocomputing.mugen.acp:administrator'],
    ),
    DrawerItemConfig(
      title: 'ACP Console',
      icon: Icons.data_object_outlined,
      route: RouteIds.acpConsole,
      section: 'Platform Configuration',
      roles: <String>['com.vorsocomputing.mugen.acp:administrator'],
    ),
  ],
  spaDefaultRoute: RouteIds.dashboard,
  spaRoutes: <SpaRouteConfig>[
    SpaRouteConfig(id: RouteIds.dashboard, title: 'Dashboard'),
    SpaRouteConfig(id: RouteIds.chat, title: 'Chat'),
    SpaRouteConfig(
      id: RouteIds.tenantManagement,
      title: 'Tenant Management',
    ),
    SpaRouteConfig(
      id: RouteIds.rolePermissionManagement,
      title: 'Role & Permission Management',
    ),
    SpaRouteConfig(id: RouteIds.runtimeControl, title: 'Runtime Control'),
    SpaRouteConfig(
      id: RouteIds.channelOrchestration,
      title: 'Channel Orchestration',
    ),
    SpaRouteConfig(id: RouteIds.contextEngine, title: 'Context Engine'),
    SpaRouteConfig(id: RouteIds.acpConsole, title: 'ACP Console'),
  ],
);
```

### What You Can Override

- app metadata: `appName`, `appVersion`
- API config: `api.baseUrl` and endpoint paths (including ACP base path, tenant management, and invite redeem endpoints)
- role catalog: `activeRoles`
- navigation structure: `drawerItems`, `spaDefaultRoute`, `spaRoutes`
- settings UX: `settingsPanels`

Endpoint keys available in `ApiEndpointsOverride`:

- `acpBase`
- `tenant`, `tenantDomain`, `tenantInvitation`, `tenantMembership`
- `tenantActionDeactivate`, `tenantActionReactivate`
- `tenantInvitationActionResend`, `tenantInvitationActionRevoke`
- `tenantMembershipActionSuspend`, `tenantMembershipActionUnsuspend`, `tenantMembershipActionRemove`
- `rbacGlobalRole`, `rbacTenantRole`
- `rbacTenantRoleActionDeprecate`, `rbacTenantRoleActionReactivate`
- `rbacPermissionObject`, `rbacPermissionObjectActionDeprecate`, `rbacPermissionObjectActionReactivate`
- `rbacPermissionType`, `rbacPermissionTypeActionDeprecate`, `rbacPermissionTypeActionReactivate`
- `rbacGlobalPermissionEntry`, `rbacTenantPermissionEntry`
- `auditEvent`, `auditEventTenant`
- `authTenantInvitationRedeem`
- `authDeleteUser`, `refreshTokenActionRevoke`

Built-in route IDs available in `RouteIds` now include:

- `chat`
- `localUsers`
- `tenantManagement`
- `rolePermissionManagement`
- `auditManagement`
- `runtimeControl`
- `channelOrchestration`
- `contextEngine`
- `acpConsole`

### Merge Semantics

`AppConfig.defaults().merge(configurationOverride)` is used at runtime:

1. Omitted fields keep defaults.
2. Provided fields replace defaults.
3. Nested API endpoint overrides are merged field-by-field.

## 2) Riverpod Provider Overrides

Use `providerOverrides` for dependency replacement in the composition root.

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:mugen_ui/app/providers.dart';

List<Override> get providerOverrides => <Override>[
      appLoggerProvider.overrideWithValue(Logger('mugen-ui.custom')),
    ];
```

This list is passed to `ProviderScope` in `lib/app/bootstrap.dart`.

### Typical Uses

1. Replace infrastructure adapters for tenant-specific behavior.
2. Swap logging/navigation integrations.
3. Provide fake/stub dependencies for integration-style local runs.

## Choosing the Right Extension Point

1. Use `configurationOverride` when changing typed app settings (routes, roles, endpoint strings, labels).
2. Use `providerOverrides` when changing implementation wiring (repositories, clients, adapters, side effects).

## Compatibility Guidance

When customizing, preserve these externally visible contracts unless intentionally changing behavior:

1. Route names used by auth flow (`/app`, `/login`).
2. ACP payload/field casing expected by backend endpoints.
3. Auth refresh/logout behavior tied to the configured endpoint paths.
4. Invite route shape and parser assumptions (`/invite/{tenant_id}/{invitation_id}`).

## ACP Console Note

`ACP Console` is a static descriptor-driven surface. Extend it by changing the descriptor code in `lib/features/acp_console/application/` rather than expecting backend-driven widget discovery.
