# mugen_ui

Flutter web ACP client rebuilt around strict Clean Architecture and Riverpod.

## Conventional Commits

This repository enforces Conventional Commits for non-merge commits in CI and via an optional local Git `commit-msg` hook.

Accepted commit types:

- `build`
- `chore`
- `ci`
- `docs`
- `feat`
- `fix`
- `perf`
- `refactor`
- `revert`
- `style`
- `test`

Commit header format:

`<type>(optional-scope)!: <description>`

Examples:

- `feat(chat): support structured attachment drafts`
- `fix(auth): preserve session when refresh succeeds`
- `chore(ci): add Flutter web smoke test`

Enable local hook enforcement (recommended):

```bash
./tool/commitlint/install_git_hooks.sh
```

## Versioning and Releases

Versioning follows [Semantic Versioning 2.0.0](https://semver.org/). CI enforces:

- `pubspec.yaml` version format
- version bump + matching dated changelog release section for PRs to `main`
- release tag consistency (`v<version>` must match `pubspec.yaml`, ignoring `+build`)

## Architecture Overview

This codebase uses a feature-first module layout with strict layer boundaries:

`presentation -> application -> domain <- infrastructure`

`shared/` provides cross-feature primitives and adapters that do not violate boundaries.

## Dependency Direction

Rules enforced by `tool/architecture/check_dependencies.dart`:

1. Domain cannot import Flutter/Riverpod/http/web or infrastructure/presentation code.
2. Application cannot import Flutter widget/material APIs.
3. Infrastructure cannot import presentation.
4. No dynamic config-driven widget lookups.

## Project Layout

- `lib/app` composition root, app router, typed app config, global providers
- `lib/shared` common domain/application primitives + infrastructure/presentation adapters
- `lib/features/auth` auth/session domain/application/infrastructure/presentation
- `lib/features/chat` single-conversation web chat (REST + SSE + media) domain/application/infrastructure/presentation
- `lib/features/user_admin` user management domain/application/infrastructure/presentation
- `lib/features/shell` drawer/settings/shell presentation state and pages
- `lib/extension` typed configuration overrides and Riverpod provider overrides

## Chat Composition Modes

Chat requests now support explicit structured composition when attachments are present:

- `message_with_attachments`: optional text part plus ordered attachment parts
- `attachment_with_caption`: attachment parts only, with a required caption per attachment

The UI serializes these through structured multipart fields (`composition_mode`, JSON `parts`, and `files[<attachment_id>]`).

## Extension Surface

- `lib/extension/configuration.dart` exposes typed `AppConfigurationOverride`
- `lib/extension/provider_overrides.dart` exposes typed `List<Override>`

## Documentation

- `docs/README.md` contributor docs index
- `docs/project-layout.md` project structure and development workflows
- `docs/extension-surface.md` typed extension hooks and override examples
- `CHANGELOG.md` Keep a Changelog formatted release notes
- `CONTRIBUTING.md` branch policy, commit conventions, and PR expectations

## Production Identity and Signing Checklist

Before shipping Android/iOS builds, update these placeholders explicitly:

1. Android package ID
   - `android/app/build.gradle` (`applicationId`)
   - `android/app/src/main/AndroidManifest.xml` (`package`)
   - `android/app/src/debug/AndroidManifest.xml` (`package`)
   - `android/app/src/profile/AndroidManifest.xml` (`package`)
   - `android/app/src/main/kotlin/.../MainActivity.kt` package path and declaration
2. Android release signing
   - `android/app/build.gradle` release `signingConfig`
   - keystore properties/CI secrets for release signing
3. iOS bundle identifier
   - `ios/Runner.xcodeproj/project.pbxproj` (`PRODUCT_BUNDLE_IDENTIFIER` for Debug/Release/Profile)
4. Web/app metadata naming (if needed for distribution)
   - `web/index.html` title/meta
   - `web/manifest.json` app name/short name
