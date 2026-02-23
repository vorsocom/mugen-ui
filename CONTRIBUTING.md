# Contributing

## Branching

- `develop` is the default integration branch.
- `main` will be introduced at first release/tag.
- Open pull requests into `develop` unless release work says otherwise.

## Commit Messages

This repository uses Conventional Commits.

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
- Run checks before opening/updating a PR:

```bash
flutter test
dart run tool/architecture/check_dependencies.dart
```
