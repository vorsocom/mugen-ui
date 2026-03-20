# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Added admin-only Audit Events SPA management with global and tenant scopes, event lifecycle row actions, and audit set actions (`run_lifecycle`, `verify_chain`, `seal_backlog`) with dry-run guardrails.
- Enforced Conventional Commit headers in CI and local `commit-msg` hooks.
- Added a contributor guide with branch, commit, and PR expectations.
- Enforced Keep a Changelog updates for pull requests in CI.
- Enforced Semantic Versioning checks in CI for pubspec version format, main release PR version bumps, and release tag consistency.
- Added runtime quality gates in CI (`analyze`, architecture check, tests, and web release build) and Conventional Commit validation for pull request titles.
- Enforced 100% line coverage in CI using `flutter test --coverage` and `tool/coverage/check_line_coverage.sh`.
- Added admin-only Tenant Management SPA support with typed tenant/domain/invitation/membership ACP repositories and UI workflows.
- Added login-first invite deep-link handling for `/invite/{tenant_id}/{invitation_id}?token=...` with authenticated ACP redeem and `/app` success landing.
- Reintroduced the RBAC Admin SPA for ACP global and tenant-scoped role, permission-object, permission-type, and grant management.
- Added LocalUsers delete + per-user session revocation actions and account self-service `Manage Account` entries for `Edit Profile` and `Reset Password` in separate panels.
- Added admin-only Runtime Control, Channel Orchestration, Context Engine, and ACP Console routes backed by a shared descriptor-driven ACP admin layer with generic CRUD/action handling and JSON form support.

### Changed

- Refactored the extension surface to a typed app-definition/module registry so downstream apps can brand the UI and contribute shell routes, browser routes, settings panels, and provider overrides without editing core host wiring.
- Enforced internal `/app` shell route authorization from registered shell-route role requirements, with automatic fallback redirects, access-denied snackbar feedback, and a locked-out empty state when no SPA routes are available.
- Updated app config to allow overriding the web API base URL at build time via `MUGEN_UI_API_BASE_URL`.
- Updated Local Users table pagination defaults to 15 rows with options of 15, 25, and 50, added vertical table scrolling support for larger page sizes, and reduced row height for a more compact layout.
- Updated tenant management ACP subresource/action endpoint defaults to use lowercase `/core/acp/v1/tenants/...` paths so browser preflight requests resolve correctly.
- Updated RBAC Admin test coverage with additional repository/domain tests and coverage pragmas so CI 100% line coverage is preserved.
- Renamed Platform Configuration menu labels to `LocalUsers`, `Tenants`, and `Roles & Permissions`.
- Constrained tenant and RBAC admin dialog form panels to the same fixed-width presentation used by LocalUsers forms.

### Fixed

- Fixed Runtime Control key-reference actions so the UI no longer offers `New Row`, `Rotate` remains available from the toolbar for create-through-rotation, and existing key refs expose a visible right-side row `Rotate` action with all fields prefilled except the secret value.
- Fixed Messaging Client Profile create-form validation so only universal and platform-specific identifier fields are required instead of every profile field.
- Synced ACP admin create-form requirements and blank optional text submission with the backend Pydantic validation surface for runtime, context, and orchestration resources.
