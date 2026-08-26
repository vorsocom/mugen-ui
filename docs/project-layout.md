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

### Add a Form or Dialog

Form surfaces and overlays use the shared primitives in
`lib/shared/presentation/theme/app_form_style.dart`:

1. Use `AppFormPanel` for inline forms rendered within a page.
2. Use `AppFormDialog` for every dialog-hosted form. Supply its `title`, `body`,
   and ordered `actions`; the base owns the closeable header, header and footer
   dividers, responsive scrolling body, and right-aligned action footer.
3. Use `AppResponsiveDialog` only for non-form overlays that need the same
   responsive viewport constraints.
4. Do not compose a form from a raw `Dialog`, a fixed-height `SizedBox`, or an
   `Expanded` body. Those patterns either overflow short viewports or force
   short forms to occupy their maximum height.
5. Do not rebuild the title, close control, dividers, or footer inside the form
   body. Keep stateful submit and cancel buttons in `actions`; they remain
   visible while a long body scrolls.
6. Add widget coverage for both a standard viewport and a constrained-height
   viewport. Only set `scrollable: false` when the body supplies its own bounded
   scrolling implementation.
7. The architecture check rejects raw `Dialog`, `AlertDialog`, and
   `SimpleDialog` construction outside the shared dialog primitives.
8. Build labeled text and select controls with `appFormInputDecoration`, and
   supply concise, nonblank `helpText` that explains the field's purpose,
   accepted format, scope, and important side effects. `AppSearchableSelectField`
   and `AcpJsonEditorField` enforce the same guidance contract.
9. Resolve descriptor-driven guidance with `acpFieldHelpText`, passing the
   resource/entity/action context whenever a repeated field key has different
   meanings. Do not merely restate the label, and do not use a tooltip as a
   substitute for inline validation or error text.
10. Add widget coverage that verifies every hand-authored form exposes its
    field guidance, and include new built-in ACP descriptors in the catalog-wide
    explicit-guidance test.
11. For server-backed selectors, use `AppSearchableSelectField` remote-search
    and incremental-loading callbacks instead of placing a separate search box
    or pagination footer beside the selector. Refresh remote options when the
    menu opens, and keep the committed selection stable while remote options
    are loading or temporarily filtered out.

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
