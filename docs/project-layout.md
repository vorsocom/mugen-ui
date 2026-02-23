# Project Layout Guide

This repository uses feature-first Clean Architecture with Riverpod code generation.

## Dependency Direction

The expected direction is:

`presentation -> application -> domain <- infrastructure`

`shared` can be used by any feature as long as it does not introduce UI/framework leaks into lower layers.

Architecture rules are enforced by `tool/architecture/check_dependencies.dart`.

## Top-Level Layout

- `lib/main.dart`: platform entrypoint.
- `lib/app`: composition root (bootstrap, router, global providers, typed app config).
- `lib/shared`: cross-feature primitives and adapters.
- `lib/features`: feature modules (`auth`, `chat`, `user_admin`, `tenant_admin`, `tenant_invite`, `shell`) with layer-aligned subfolders.
- `lib/extension`: typed extension surface for configuration and provider overrides.
- `test`: unit and widget tests, including layer and behavior checks.
- `tool/architecture`: dependency rule checker.

## Feature Module Structure

Each feature follows this pattern:

```text
lib/features/<feature_name>/
  domain/
    entities/
    repositories/
    usecases/
  application/
    dto/
    services/
  infrastructure/
    repositories/
    datasources/
    mappers/
  presentation/
    providers/
    pages/
    widgets/
```

## How To Work In This Layout

### Chat Structured Composition

`lib/features/chat` supports two explicit attachment composition modes in presentation/application/domain:

1. `message_with_attachments`: optional message text plus ordered attachment parts.
2. `attachment_with_caption`: attachments only, caption required per attachment.

Infrastructure maps these modes to the web plugin structured multipart contract (`composition_mode`, `parts`, and `files[<id>]`).

### Add a New Business Flow

1. Define entities/repository contracts/use cases in `domain`.
2. Add request/response DTOs and orchestration services in `application`.
3. Implement repository/data transport details in `infrastructure`.
4. Expose UI state/events in `presentation/providers` using `@Riverpod`.
5. Render UI in `presentation/pages` and `presentation/widgets`.
6. Add tests per layer (`domain` unit tests first, then widget tests for UI behavior).

### Add a New SPA Route

1. Add route ID in `lib/app/routing/route_ids.dart`.
2. Add route metadata in `AppConfig.defaults()` (`drawerItems`, `spaRoutes`, and optionally `spaDefaultRoute`) in `lib/app/config/app_config.dart`.
3. Add content widget mapping in `lib/features/shell/presentation/widgets/route_views.dart`.
4. Validate drawer behavior and route switching in shell widget tests.

### Add an Invite Deep-Link Route

1. Add typed route helpers in `lib/app/routing/route_ids.dart` for path build/parse.
2. Detect dynamic invite paths in `lib/app/routing/app_router.dart` before fallback shell routes.
3. Route invite links through `AuthGuard` and persist pending invite context for login-first flows.
4. Ensure login success redirects to pending invite when present, otherwise `/app`.

### Add a New Settings Panel

1. Extend `SettingsPanelType` in `lib/app/config/app_config.dart`.
2. Add panel config in `AppConfig.defaults().settingsPanels`.
3. Handle the new panel type in `_panelBody` inside `lib/features/shell/presentation/widgets/settings_panel.dart`.
4. Ensure role gating and rendering behavior are covered by widget tests.

## Guardrails

1. Keep framework dependencies out of `domain`.
2. Keep Flutter widget imports out of `application`.
3. Keep `infrastructure` independent from `presentation`.
4. Prefer typed models over dynamic maps.
5. Run `dart run tool/architecture/check_dependencies.dart` after structural changes.
