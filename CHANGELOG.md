# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

### Changed

- Reordered Platform Capabilities navigation so Service Profiles follows
  Billing Operations and Knowledge Packs follows Service Profiles.

### Deprecated

### Removed

### Fixed

- Fixed unsupported archived collection requests that prevented Service
  Profile, Knowledge Pack, Channel Orchestration, and billing metadata
  hydration, and added direct Knowledge Pack reference fallbacks when
  navigation expansions are unavailable.

### Security

## [0.17.0] - 2026-09-01

### Added

- Added capability-gated Service Profile administration for stable service
  identities, ingress endpoint routing, Billing Subscription Product access,
  and optional Knowledge Scope targeting.

### Changed

### Deprecated

### Removed

### Fixed

### Security

## [0.16.0] - 2026-09-01

### Added

- Added Knowledge Pack projection status, staged publication monitoring,
  reindex/retry controls, exact projection filters, and pack/version
  searchability summaries for the active knowledge gateway.

### Changed

### Deprecated

### Removed

### Fixed

### Security

## [0.15.5] - 2026-08-30

### Added

### Changed

### Deprecated

### Removed

### Fixed

- Fixed shared ACP two-step create forms to recover created identifiers from
  validated `Location` headers, hydrate missing row versions, and retry only
  post-create updates after recoverable failures.
- Fixed Billing Operations entitlement buckets to recover recognizable global
  Price Rule and Meter Definition labels when navigation expansions are
  incomplete or unavailable.

### Security

## [0.15.4] - 2026-08-28

### Added

### Changed

### Deprecated

### Removed

### Fixed

- Fixed UUID-backed ACP administration reference and expansion re-fetches to
  emit typed GUID literals across channel orchestration, knowledge packs, and
  upstream Core administration descriptors while preserving string-key filters.

### Security

## [0.15.3] - 2026-08-28

### Added

### Changed

### Deprecated

### Removed

### Fixed

- Replaced plain-text administrative date and time inputs with reusable UTC
  date-time, 24-hour time, and multi-date selector controls while preserving
  existing API payload formats and untouched timestamp precision.

### Security

## [0.15.2] - 2026-08-28

### Added

### Changed

### Deprecated

### Removed

### Fixed

- Fixed ACP administration reference enrichment to serialize GUID filters
  correctly, resolve readable Billing labels through scoped fallbacks, and
  surface non-blocking warnings when labels remain unavailable.

### Security

## [0.15.1] - 2026-08-28

### Added

### Changed

- Changed administration forms and handoff filters to use searchable entity
  references, bounded catalog suggestions, multi-select chips, and canonical
  timezone, locale, platform, and weekday choices where applicable.

### Deprecated

### Removed

### Fixed

- Fixed monetary administration fields to consistently accept major-unit input,
  avoid unsafe decimal assumptions when currency precision is unavailable, and
  keep raw minor-unit amounts out of human-readable reference labels.
- Added responsive overflow fades and accessible navigation buttons to
  scrollable administration tab strips.
- Fixed descriptor-driven ACP administration tables to render accessible,
  human-readable relationship labels while preserving UUID fallbacks and raw
  identifiers for inspection.

### Security

## [0.15.0] - 2026-08-27

### Added

- Added the complete global Billing Catalog for meters, Price entitlements,
  run definitions, currencies, tax, payment terms, invoice templates, and
  discounts, plus tenant subscription, usage, entitlement, execution,
  invoicing, payment, adjustment, and ledger operations.

### Changed

- Changed billing provisioning to use canonical global meters and Prices,
  generated subscription entitlement buckets, audited balance adjustments,
  global billing-cycle schedules, active global reference selectors, and
  currency-aware major-unit amount entry.

### Deprecated

### Removed

### Fixed

- Fixed billing administration boundaries so tenants cannot recreate meter
  semantics, edit generated allowances, or directly change lifecycle-owned
  financial statuses, while preserving actionable RowVersion conflicts.

### Security

## [0.14.0] - 2026-08-26

### Added

- Added extension-gated Core administration surfaces for tenant billing
  operations, governance policies, workflows, SLA configuration, reporting,
  and connectors, including guarded actions, searchable managed references,
  operational diagnostics, and typed WhatsApp secret-reference paths.

### Changed

- Extended descriptor-driven ACP forms with retained input on API failures,
  stale-versus-lifecycle conflict feedback, affected-row refresh, constrained
  row actions, create-then-update contract support, timezone validation, and
  searchable single- and multi-reference value semantics.

### Deprecated

### Removed

### Fixed

- Corrected Billing Runs diagnostics to display the ACP `PeriodStart` and
  `PeriodEnd` fields.

### Security

## [0.13.0] - 2026-08-26

### Added

- Added a configurable public muGen portal with responsive landing, production
  login, Terms of Use, and Privacy Policy screens, official brand assets, and
  a fail-closed optional WhatsApp Embedded Signup launcher contract.

### Changed

- Changed the default and unknown browser route destination to the public
  portal while preserving authentication guards for the application and
  invitation flows, and changed logout to return to the portal.
- Added typed downstream portal definitions for logo, pattern, semantic theme
  tokens, company branding, page copy, and ordered legal content.
- Replaced the default Flutter web favicon and installable-app icons with the
  official muGen mark, including safe-area-aware maskable variants.

### Deprecated

### Removed

### Fixed

### Security

## [0.12.0] - 2026-08-26

### Added

- Added an extension-aware global Billing Catalog under Platform Configuration
  with Product and Price management, read-only access, lifecycle actions, and
  guarded navigation based on runtime Billing availability and catalog read
  permission.

### Changed

- Grouped Platform Configuration destinations into Identity & Access,
  Platform Capabilities, Operations & Governance, and Developer drawer
  groups with extension-ready nested navigation metadata.
- Consolidated tenant discovery into one backend-searchable selector with
  incremental result loading, refresh-on-open behavior, and stable,
  non-shifting loading feedback.
- Completed contextual information tooltips across built-in form surfaces and
  made nonblank field guidance a required shared form-control contract.
- Replaced warm beige-gray surfaces, outlines, and supporting text with a
  consistent neutral grayscale while retaining graphite-blue interactions.
- Unified the admin interaction palette around graphite blue, bundled explicit
  Inter font weights for crisp navigation and action labels, and added shared
  safe plain-text normalization for JSON, HTML, and plain API errors.
- Updated Billing Product and Price forms with contextual field help and the
  shared JSON editor, including independently contained editor scrolling.
- Consolidated dialog-hosted forms on a responsive shared base with a uniform
  closeable header, section dividers, pinned action footer, and a body that
  shrink-wraps short content or scrolls within the available viewport.
- Redesigned the web admin console with a graphite navigation drawer,
  neutral-gray borders around clean white workspace and dialog surfaces,
  graphite-blue interaction states and primary actions, refined typography,
  underlined count-bearing screen tabs, and denser enterprise controls and
  tables.
- Changed descriptor-driven admin consoles to use shared operational headers,
  resource tabs with counts, grid footers, contextual empty states, and row
  detail drawers.
- Changed Local Users to use the shared admin header, toolbar, data grid,
  status chips, row actions, grid footer, and contextual empty states.
- Changed Tenants to use the shared admin header, toolbar, tabs, pagination
  footer, empty states, status chips, and row action sizing.
- Changed Roles & Permissions to use the shared admin header, toolbar, tabs,
  data grid, pagination footer, empty states, split permission columns, and
  clearer lifecycle actions.
- Changed Audit Events to use the shared admin header, toolbar, data grid,
  pagination footer, selected-row highlighting, status chips, copyable detail
  metadata, and contextual empty states.
- Changed the Human Handoff drawer item to show compact status chips for live
  handoff workload and attention states.

### Deprecated

### Removed

### Fixed

- Fixed transient Human Handoff stream reconnects being reported as live
  incidents, and consolidated the drawer status into one compact badge so the
  navigation label remains stable.
- Fixed rounded table surfaces so header backgrounds remain clipped inside
  their borders.
- Fixed administrative page headers so subtitle copy uses the available width
  beside primary actions instead of wrapping within an arbitrary fixed cap.
- Fixed searchable Tenant and Product selectors so their scrollable option
  menus open in anchored overlays without expanding the surrounding layout.

### Security

## [0.11.1] - 2026-06-21

### Added

### Changed

### Deprecated

### Removed

### Fixed

### Security

- Bumped the JavaScript asset bundler dependency and restricted CI workflow
  token permissions.

## [0.11.0] - 2026-06-19

### Added

- Added optional browser title configuration separate from the in-app drawer
  title.
- Added optional favicon configuration for downstream browser branding.

### Changed

### Deprecated

### Removed

### Fixed

### Security

## [0.10.0] - 2026-06-19

### Added

- Added Global Role Memberships management under Roles & Permissions with
  searchable user and global-role selectors.

### Changed

- Renamed the Roles & Permissions Role Memberships tab to Tenant Role
  Memberships.
- Reordered Roles & Permissions tabs to group permission catalogs, global RBAC,
  and tenant RBAC workflows.
- Changed global and tenant grant creation to use searchable role,
  permission-object, and permission-type pickers.
- Changed Platform Configuration tenant selectors and enum-like form fields to
  use searchable selectors and constrained dropdowns.

### Deprecated

### Removed

- Removed the LocalUsers table Edit Roles action in favor of dedicated global
  and tenant role-membership management.

### Fixed

- Reset AI Assist transient state when the authenticated user changes so stale
  errors and in-flight responses do not leak across logins.
- Rendered AI Assist backend errors in a red alert above the composer and
  normalized HTML API error pages into readable messages.
- Capped the LocalUsers sessions dialog height against the viewport so long
  session lists remain scrollable on shorter screens.

### Security

## [0.9.1] - 2026-06-18

### Added

### Changed

### Deprecated

### Removed

### Fixed

- Changed tenant role membership creation to use searchable member and role
  pickers with explicit selections.

### Security

## [0.9.0] - 2026-06-18

### Added

- Added tenant-scoped role membership management under Roles & Permissions.

### Changed

### Deprecated

### Removed

### Fixed

- Synced in-memory auth session roles after successful token refreshes so route
  visibility follows refreshed RBAC claims without requiring a reload.

### Security

## [0.8.0] - 2026-06-17

### Added

- Added Codex convenience prompts for mugen-ui work sessions, workspace
  cloning, architecture, deployment, CI troubleshooting, and release workflow
  guidance, including downstream UI release safety and upstream/main sync rules.
- Added a downstream provenance TOML sample for downstream UI app
  initialization.

### Changed

### Deprecated

### Removed

### Fixed

### Security

## [0.7.0] - 2026-06-10

### Added

- Added an Amplify Hosting build spec that installs Flutter and injects
  `MUGEN_UI_API_BASE_URL` into the web release build.

### Changed

### Deprecated

### Removed

### Fixed

### Security

## [0.6.0] - 2026-06-06

### Added

- Added search controls to the Roles & Permissions tables.

### Changed

- Changed AI Assist route visibility to use the backend `com.vorsocomputing.mugen.web:access` permission instead of allowing every authenticated shell session.

### Deprecated

### Removed

### Fixed

### Security

## [0.5.0] - 2026-06-04

### Added

- Added a Knowledge Packs Platform Configuration panel for knowledge-pack ACP resources and version lifecycle actions.

### Changed

- Changed Knowledge Packs route visibility to use the backend `knowledge_pack:configurator` permission instead of the global ACP administrator role.

### Deprecated

### Removed

### Fixed

### Security

## [0.4.1] - 2026-06-02

### Added

- Added live Human Handoff operator updates, transcript cursor refreshes, and new inbound-user activity markers.

### Changed

### Deprecated

### Removed

### Fixed

### Security

## [0.4.0] - 2026-06-02

### Added

- Added a Human Handoff operator console for active sessions, transcript review, human replies, delivery failures, and release back to AI.

### Changed

- Changed Human Handoff route visibility to use the dedicated operator permission instead of the global ACP administrator role.

### Deprecated

### Removed

### Fixed

### Security

## [0.3.0] - 2026-05-28

### Added

### Changed

- Changed persistent panel and form-dialog errors to render as copyable red alert boxes.

### Deprecated

### Removed

### Fixed

- Fixed ACP JSON form fields so the dialog scrollbar uses a reserved right-side gutter instead of overlapping the editor scrollbar.

### Security

## [0.2.0] - 2026-05-20

### Added

- Added a documented identifier-type dropdown to Ingress Binding create and update forms.
- Added backend-oriented field help tooltips to Platform Configuration CRUD dialogs.
- Added information-icon tooltips to Platform Configuration tab labels and moved page-level descriptions into muted notice boxes.
- Added tenant-aware searchable reference selectors for Channel Profile `ClientProfileId` and Ingress Binding `ChannelProfileId` fields.
- Added a row-detail dialog action to copy the ACP object ID to the clipboard.
- Added prominent active scope context to ACP form dialogs so tenant or global operations are visible while editing.
- Added a self-hosted CodeMirror JSON editor for ACP admin form fields that edit JSON values.

### Changed

- Changed Platform Configuration tenant management to use a dropdown tenant selector while keeping selected-tenant edit and lifecycle actions available.
- Moved the Channel Profile `ClientProfileId` field to the top of create and update forms.
- Changed Runtime Control Key References provider inputs and table labels to use `Key Provider`, with dropdown choices for supported key providers.

### Deprecated

### Removed

### Fixed

- Fixed row detail dialogs so short object views shrink to their content while preserving the existing maximum height.
- Fixed Channel Profile update forms so the channel and profile keys remain visible as read-only identity context.
- Fixed update dialogs so selected reference fields display resolved profile names alongside their IDs.
- Fixed ACP edit and row action dialogs and mutations so existing objects use the row's tenant context instead of the current screen scope when those differ.
- Fixed ACP `New Row` dialogs so short Platform Configuration forms shrink to their content while preserving the existing maximum height for longer forms.
- Fixed RBAC global and tenant grant dialog dropdown sizing so long permission keys truncate within the field instead of overflowing the trailing menu affordance.
- Fixed Runtime Control key-reference row actions so the three-dot menu remains visible and clickable in the table.

### Security

## [0.1.1] - 2026-05-13

### Added

### Changed

- Updated tenant membership management to search/select existing users, show usernames and emails in membership rows, choose membership roles from fixed role options, and make the active tenant row more identifiable.

### Deprecated

### Removed

### Fixed

- Fixed ACP and LocalUsers table column sizing so cell text uses the full available column width instead of being constrained to narrow intrinsic/fixed text boxes.

### Security

## [0.1.0] - 2026-03-21

### Added

- Added admin-only Audit Events SPA management with global and tenant scopes, event lifecycle row actions, and audit set actions (`run_lifecycle`, `verify_chain`, `seal_backlog`) with dry-run guardrails.
- Enforced Conventional Commit headers in CI and local `commit-msg` hooks.
- Added a contributor guide with branch, commit, and PR expectations.
- Enforced Keep a Changelog updates for pull requests in CI.
- Added bootstrap-aware release automation with `prepare`, `finish`, and `publish` flows for `release/<version>` branches, `main` release PRs, and tagged publishes back-synced into `develop`.
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
