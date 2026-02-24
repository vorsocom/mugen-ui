# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

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

### Changed

- Updated Local Users table pagination defaults to 15 rows with options of 15, 25, and 50, added vertical table scrolling support for larger page sizes, and reduced row height for a more compact layout.
- Updated tenant management ACP subresource/action endpoint defaults to use lowercase `/core/acp/v1/tenants/...` paths so browser preflight requests resolve correctly.
- Updated RBAC Admin test coverage with additional repository/domain tests and coverage pragmas so CI 100% line coverage is preserved.
- Renamed Platform Configuration menu labels to `LocalUsers`, `Tenants`, and `Roles & Permissions`.
- Constrained tenant and RBAC admin dialog form panels to the same fixed-width presentation used by LocalUsers forms.
