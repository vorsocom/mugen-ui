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

### Changed

- Updated Local Users table pagination defaults to 15 rows with options of 15, 25, and 50, added vertical table scrolling support for larger page sizes, and reduced row height for a more compact layout.
