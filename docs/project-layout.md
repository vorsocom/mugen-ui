# Project Layout Guide

This repository uses feature-first Clean Architecture with Riverpod code generation.

## Dependency Direction

The expected direction is:

`presentation -> application -> domain <- infrastructure`

`shared` can be used by any feature as long as it does not introduce UI/framework leaks into lower layers.

Architecture rules are enforced by `tool/architecture/check_dependencies.dart`.

## Top-Level Layout

- `lib/main.dart`: platform entrypoint.
- `lib/app`: composition root (bootstrap, router, global providers, typed app config, and typed UI registries).
- `lib/shared`: cross-feature primitives and adapters.
- `lib/features`: feature modules (`auth`, `chat`, `user_admin`, `tenant_admin`, `tenant_invite`, `shell`) with layer-aligned subfolders.
- `lib/extension`: downstream app assembly entrypoint (`app_definition.dart`).
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

### Add a New Shell Route

1. Define a `ShellRouteDefinition` in a core or downstream `MugenUiModule`.
2. Assemble that module in `lib/extension/app_definition.dart`.
3. If the route should be the shell landing page, set `defaultShellRouteId` to the new route id.
4. Validate drawer behavior, role gating, and route switching in shell widget/provider tests.

### Add a New Top-Level Browser Route

1. Define a `TopLevelRouteDefinition.exact(...)` or `TopLevelRouteDefinition.parsed<T>(...)` in a module.
2. Assemble that module in `lib/extension/app_definition.dart`.
3. Keep route ids and exact paths unique; startup will fail fast on duplicates.
4. Add router tests that exercise both the match and the canonical location.

### Add a New Settings Panel

1. Define a `SettingsPanelDefinition` in a module.
2. Assemble that module in `lib/extension/app_definition.dart`.
3. Supply a typed builder and any required dialog sizing/header options.
4. Ensure role gating and rendering behavior are covered by widget tests.

### Replace a Built-In Feature Downstream

1. Build a different `modules` list in `lib/extension/app_definition.dart`.
2. Omit the built-in module you want to replace.
3. Add your downstream replacement module with the desired shell routes, browser routes, settings panels, and provider overrides.
4. Prefer typed provider overrides and module composition over hidden merge semantics.

## Guardrails

1. Keep framework dependencies out of `domain`.
2. Keep Flutter widget imports out of `application`.
3. Keep `infrastructure` independent from `presentation`.
4. Prefer typed models over dynamic maps.
5. Do not add reflection or config-driven widget lookup for route/panel registration.
6. Run `dart run tool/architecture/check_dependencies.dart` after structural changes.
