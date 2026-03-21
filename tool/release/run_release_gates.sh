#!/usr/bin/env bash
set -euo pipefail

flutter pub get
flutter analyze
dart run tool/architecture/check_dependencies.dart
flutter test --coverage
tool/coverage/check_line_coverage.sh --lcov coverage/lcov.info --minimum 100
flutter build web --release --no-wasm-dry-run
