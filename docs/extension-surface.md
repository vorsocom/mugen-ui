# Extension Surface Guide

The primary downstream seam is now `lib/extension/app_definition.dart`.

`mugen-ui` remains a compile-time typed host. It does not support reflection,
JSON-driven widget discovery, or backend-driven UI assembly.

## Extension File

Create or update:

1. `lib/extension/app_definition.dart`

`lib/app/providers.dart`, `lib/app/bootstrap.dart`, and `lib/app/routing/app_router.dart`
consume this file during startup.

## App Definition

`MugenUiAppDefinition` assembles the downstream app:

- app identity/config via `AppConfig`
- the ordered module list
- the default shell route id

```dart
import 'package:mugen_ui/app/config/app_config.dart';
import 'package:mugen_ui/app/definition/app_definition.dart';
import 'package:mugen_ui/app/definition/core_modules.dart';

final MugenUiAppDefinition appDefinition = MugenUiAppDefinition(
  config: AppConfig.defaults().merge(
    const AppConfigurationOverride(
      appName: 'muGen UI (ACME)',
      appVersion: '1.2.3',
      api: ApiConfigOverride(
        baseUrl: 'https://acme.example.com/api',
      ),
    ),
  ),
  defaultShellRouteId: 'acme.reports.dashboard',
  modules: <MugenUiModule>[
    ...buildDefaultAppDefinition().modules,
  ],
);
```

`AppConfig` is intentionally slim. It owns:

- app metadata: `appName`, `appVersion`
- API config: `api.baseUrl` and typed endpoint paths
- role catalog: `activeRoles`

Routes, settings panels, and provider overrides now live on modules.

## Modules

`MugenUiModule` is the typed contribution unit for built-in or downstream UI packages.

Each module may contribute:

- `shellRoutes`
- `topLevelRoutes`
- `settingsPanels`
- `providerOverrides`

Provider overrides are applied in module order. Later modules win when overriding
the same provider.

## Example Downstream Module Assembly

This example assumes a downstream package such as `acme_reports_ui` exports typed
definitions and providers.

```dart
import 'package:flutter/material.dart';
import 'package:mugen_ui/app/config/app_config.dart';
import 'package:mugen_ui/app/definition/app_definition.dart';
import 'package:mugen_ui/app/definition/core_modules.dart';

import 'package:acme_reports_ui/acme_reports_ui.dart';

final MugenUiAppDefinition appDefinition = MugenUiAppDefinition(
  config: AppConfig.defaults().merge(
    const AppConfigurationOverride(
      appName: 'muGen UI (ACME)',
      api: ApiConfigOverride(baseUrl: 'https://acme.example.com/api'),
    ),
  ),
  defaultShellRouteId: AcmeReportsRouteIds.dashboard,
  modules: <MugenUiModule>[
    ...buildDefaultAppDefinition().modules,
    MugenUiModule(
      id: 'acme.reports',
      shellRoutes: <ShellRouteDefinition>[
        ShellRouteDefinition(
          id: AcmeReportsRouteIds.dashboard,
          title: 'Reports',
          icon: Icons.insights_outlined,
          section: 'Operations',
          requiredRoles: <String>['acme:report_viewer'],
          builder: buildAcmeReportsPage,
        ),
      ],
      topLevelRoutes: <TopLevelRouteDefinition>[
        TopLevelRouteDefinition.exact(
          id: 'acme.reports.browser',
          path: '/reports',
          builder: buildAcmeReportsBrowserPage,
        ),
        TopLevelRouteDefinition.parsed<AcmeReportDetailRoute>(
          id: 'acme.reports.detail',
          parse: parseAcmeReportDetailRoute,
          canonicalLocation: (route) => route.location,
          builder: buildAcmeReportDetailPage,
        ),
      ],
      settingsPanels: <SettingsPanelDefinition>[
        SettingsPanelDefinition(
          id: 'acme.reports.preferences',
          title: 'Report Preferences',
          icon: Icons.tune_outlined,
          requiredRoles: <String>['acme:report_viewer'],
          builder: buildAcmeReportPreferencesPanel,
          maxWidth: 900,
          maxHeight: 700,
        ),
      ],
      providerOverrides: buildAcmeReportsProviderOverrides(),
    ),
  ],
);
```

## Shell Routes

Use `ShellRouteDefinition` for internal `/app` routes.

Fields:

- `id`
- `title`
- `icon`
- `section`
- `requiredRoles`
- `showInDrawer`
- `builder`

The shell registry is the single source of truth for:

- drawer entries
- route titles
- role gating
- fallback selection
- locked-out empty state handling

Unknown shell route ids still render the existing unknown-route placeholder.

## Top-Level Routes

Use `TopLevelRouteDefinition` for browser routes.

Two helper patterns are provided:

1. `TopLevelRouteDefinition.exact(...)`
2. `TopLevelRouteDefinition.parsed<T>(...)`

Top-level route resolution is deterministic:

1. modules are evaluated in app-definition order
2. routes are evaluated in module order
3. the first matching route wins
4. if nothing matches, the router falls back to the configured `/app` route

Built-in `/app`, `/login`, and invite routes now use the same typed registry model.

## Settings Panels

Use `SettingsPanelDefinition` for account/settings overlays.

Fields:

- `id`
- `title`
- `icon`
- `requiredRoles`
- `builder`
- `maxWidth`
- `maxHeight`
- `showHeader`
- `expandBody`

Settings panel visibility is role-gated from the registered definitions.

## Registry Rules

These are bootstrap-time errors:

- duplicate module ids
- duplicate shell route ids
- duplicate settings panel ids
- duplicate top-level route ids
- duplicate exact top-level paths
- `defaultShellRouteId` not matching a registered shell route

There is no hidden merge behavior for replacing built-in features. Replace features
by assembling a different module list in `app_definition.dart`.

## Route Constants

Core browser paths and built-in shell route ids live in:

- `AppRoutePaths`
- `CoreShellRouteIds`

Downstream modules do not need to edit these constants. They may use arbitrary
string ids for downstream shell routes.

## Compatibility Guidance

When customizing, preserve these externally visible contracts unless intentionally
changing behavior:

1. browser routes used by auth flow (`/app`, `/login`)
2. invite route shape and parser assumptions (`/invite/{tenant_id}/{invitation_id}`)
3. ACP payload/field casing expected by backend endpoints
4. auth refresh/logout behavior tied to the configured endpoint paths

## ACP Console Note

`ACP Console` remains a static descriptor-driven surface. Extend it by changing
descriptor code in `lib/features/acp_console/application/`, not by expecting
runtime widget discovery from backend schemas.
