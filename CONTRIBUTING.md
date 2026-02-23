# Contributing

## Branching

- `develop` is the default integration branch.
- `main` will be introduced at first release/tag.
- Open pull requests into `develop` unless release work says otherwise.

## Commit Messages

This repository uses Conventional Commits.

Pull request titles are validated with the same Conventional Commit format in CI.

Header format:

`<type>(optional-scope)!: <description>`

Allowed types:

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

Recommended scopes in this repo:

- `app`
- `auth`
- `chat`
- `user_admin`
- `shell`
- `shared`
- `extension`
- `web`
- `docs`
- `ci`
- `tooling`
- `deps`

Examples:

- `feat(chat): support attachment caption editing`
- `fix(auth): retain session after token refresh`
- `refactor(shared): simplify result mapping helpers`
- `docs(project): clarify route extension points`
- `chore(deps): bump riverpod_generator`

Breaking changes:

- Add `!` after type or scope, for example: `feat(auth)!: require password reset on first login`
- Include a `BREAKING CHANGE:` section in the commit body when relevant.

## Local Hook Setup

Enable local commit-msg validation:

```bash
./tool/commitlint/install_git_hooks.sh
```

## Pull Request Expectations

- Keep PRs focused and small when practical.
- Add an entry to `CHANGELOG.md` under `## [Unreleased]` using a Keep a Changelog category.
- For PRs targeting `main`, bump `pubspec.yaml` version and add a dated `## [x.y.z] - YYYY-MM-DD` release section in `CHANGELOG.md`.
- Run checks before opening/updating a PR:

```bash
flutter analyze
dart run tool/architecture/check_dependencies.dart
flutter test
```

- Optional locally (required in CI):

```bash
flutter build web --release --no-wasm-dry-run
```

## Release and Versioning

- Versioning follows [Semantic Versioning 2.0.0](https://semver.org/).
- Release tags must be `v<version>` and match `pubspec.yaml` version (ignoring `+build` metadata).
- Release tags require a matching dated section in `CHANGELOG.md`:

`## [x.y.z] - YYYY-MM-DD`
