#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  check_keepachangelog.sh --base <base_sha> --head <head_sha>

Checks that:
  1) CHANGELOG.md exists and follows Keep a Changelog core structure.
  2) Pull request diff updates CHANGELOG.md.
  3) Diff adds at least one changelog bullet line ("- ..."), unless a release
     section header was added in the same diff.
USAGE
}

fail() {
  echo "Changelog check failed: $1" >&2
  exit 1
}

require_line() {
  local regex="$1"
  local file="$2"
  local message="$3"

  if ! grep -Eq "${regex}" "${file}"; then
    fail "${message}"
  fi
}

validate_release_headers() {
  local file="$1"
  local header

  while IFS= read -r header; do
    if [[ "${header}" == "## [Unreleased]" ]]; then
      continue
    fi

    if [[ ! "${header}" =~ ^##\ \[[^]]+\]\ -\ [0-9]{4}-[0-9]{2}-[0-9]{2}(\ \[YANKED\])?$ ]]; then
      fail "release headers must match: ## [x.y.z] - YYYY-MM-DD (optionally with [YANKED])."
    fi
  done < <(grep -E '^## \[' "${file}")
}

validate_unreleased_has_known_sections() {
  local file="$1"

  if ! awk '
    BEGIN { in_unreleased = 0; section_found = 0 }
    /^## \[Unreleased\]$/ { in_unreleased = 1; next }
    /^## \[/ { if (in_unreleased == 1) { in_unreleased = 0 } }
    in_unreleased == 1 && /^### (Added|Changed|Deprecated|Removed|Fixed|Security)$/ {
      section_found = 1
    }
    END { exit section_found ? 0 : 1 }
  ' "${file}"; then
    fail "Unreleased section must contain at least one standard subsection heading."
  fi
}

main() {
  local base=""
  local head=""

  while (($# > 0)); do
    case "$1" in
      --base)
        shift
        (($# > 0)) || { usage >&2; exit 2; }
        base="$1"
        ;;
      --head)
        shift
        (($# > 0)) || { usage >&2; exit 2; }
        head="$1"
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        usage >&2
        exit 2
        ;;
    esac
    shift
  done

  [[ -n "${base}" ]] || { usage >&2; exit 2; }
  [[ -n "${head}" ]] || { usage >&2; exit 2; }

  git cat-file -e "${base}^{commit}" 2>/dev/null || fail "base commit not found: ${base}"
  git cat-file -e "${head}^{commit}" 2>/dev/null || fail "head commit not found: ${head}"

  local changed_files
  changed_files="$(git diff --name-only "${base}" "${head}")"

  if ! grep -Fxq "CHANGELOG.md" <<<"${changed_files}"; then
    fail "CHANGELOG.md must be updated in this pull request."
  fi

  local changelog_tmp
  changelog_tmp="$(mktemp)"
  trap '[[ -n "${changelog_tmp:-}" ]] && rm -f "${changelog_tmp}"' EXIT

  git show "${head}:CHANGELOG.md" > "${changelog_tmp}" 2>/dev/null \
    || fail "CHANGELOG.md is missing in head commit."

  require_line '^# Changelog$' "${changelog_tmp}" "CHANGELOG.md must start with '# Changelog'."
  require_line '^## \[Unreleased\]$' "${changelog_tmp}" "CHANGELOG.md must include a '## [Unreleased]' section."
  validate_release_headers "${changelog_tmp}"
  validate_unreleased_has_known_sections "${changelog_tmp}"

  local changelog_diff
  changelog_diff="$(git diff --unified=0 "${base}" "${head}" -- CHANGELOG.md)"

  local release_header_added=0
  if grep -Eq '^\+## \[[^]]+\] - [0-9]{4}-[0-9]{2}-[0-9]{2}( \[YANKED\])?$' <<<"${changelog_diff}"; then
    release_header_added=1
  fi

  if ((release_header_added == 0)); then
    if ! grep -Eq '^\+\s*-\s+\S' <<<"${changelog_diff}"; then
      fail "add at least one bullet entry under CHANGELOG.md (for example under Unreleased -> Added/Changed/Fixed)."
    fi
  fi

  echo "Changelog check passed."
}

main "$@"
