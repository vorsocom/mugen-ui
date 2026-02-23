#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  check_semver.sh check-pubspec [--ref <git_ref>]
  check_semver.sh check-pr-main --base <base_sha> --head <head_sha>
  check_semver.sh check-tag --tag <tag_name> --ref <git_ref>

Commands:
  check-pubspec
    Validates that pubspec.yaml version follows Semantic Versioning.

  check-pr-main
    Validates release rules for a PR targeting main:
      - pubspec.yaml version in head is > base
      - head version is not a pre-release
      - head CHANGELOG.md contains a dated release header matching version
      - the matching release header is added in the PR diff

  check-tag
    Validates release rules for a pushed tag:
      - tag must be v<semver>
      - tag version must match pubspec.yaml version (ignoring +build metadata)
      - CHANGELOG.md at ref contains matching dated release header
USAGE
}

fail() {
  echo "SemVer check failed: $1" >&2
  exit 1
}

regex_escape() {
  sed 's/[][(){}.^$*+?|\\/-]/\\&/g' <<<"$1"
}

git_file_at_ref() {
  local ref="$1"
  local path="$2"
  git show "${ref}:${path}" 2>/dev/null || return 1
}

extract_pubspec_version_from_content() {
  awk '
    /^[[:space:]]*version[[:space:]]*:/ {
      line=$0
      sub(/^[^:]*:[[:space:]]*/, "", line)
      sub(/[[:space:]]*#.*$/, "", line)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
      if (line ~ /^".*"$/ || line ~ /^'\''.*'\''$/) {
        line=substr(line, 2, length(line)-2)
      }
      print line
      exit
    }
  '
}

get_pubspec_version_at_ref() {
  local ref="$1"
  local content
  local version

  content="$(git_file_at_ref "${ref}" "pubspec.yaml")" \
    || fail "pubspec.yaml not found at ref '${ref}'."
  version="$(extract_pubspec_version_from_content <<<"${content}")"

  [[ -n "${version}" ]] || fail "version not found in pubspec.yaml at ref '${ref}'."
  echo "${version}"
}

validate_identifier_list() {
  local value="$1"
  local kind="$2"
  local enforce_no_leading_zero_numeric="$3"

  [[ "${value}" =~ ^[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*$ ]] \
    || fail "invalid ${kind} identifier list: '${value}'."

  if [[ "${enforce_no_leading_zero_numeric}" == "true" ]]; then
    local ident
    local -a idents
    IFS='.' read -r -a idents <<<"${value}"
    for ident in "${idents[@]}"; do
      if [[ "${ident}" =~ ^[0-9]+$ ]] && [[ "${ident}" =~ ^0[0-9]+$ ]]; then
        fail "numeric ${kind} identifier '${ident}' must not contain leading zeroes."
      fi
    done
  fi
}

parse_semver() {
  local version="$1"
  local prefix="$2"
  local core_with_prerelease
  local core
  local prerelease=""
  local build=""
  local -a core_parts

  [[ -n "${version}" ]] || fail "empty version string."
  [[ ! "${version}" =~ [[:space:]] ]] || fail "version must not contain spaces: '${version}'."

  if [[ "${version}" =~ \+.*\+ ]]; then
    fail "version contains multiple '+' segments: '${version}'."
  fi

  if [[ "${version}" == *"+"* ]]; then
    core_with_prerelease="${version%%+*}"
    build="${version#*+}"
    [[ -n "${build}" ]] || fail "build metadata must not be empty: '${version}'."
    validate_identifier_list "${build}" "build metadata" "false"
  else
    core_with_prerelease="${version}"
  fi

  if [[ "${core_with_prerelease}" == *"-"* ]]; then
    core="${core_with_prerelease%%-*}"
    prerelease="${core_with_prerelease#*-}"
    [[ -n "${prerelease}" ]] || fail "pre-release part must not be empty: '${version}'."
    validate_identifier_list "${prerelease}" "pre-release" "true"
  else
    core="${core_with_prerelease}"
  fi

  IFS='.' read -r -a core_parts <<<"${core}"
  ((${#core_parts[@]} == 3)) \
    || fail "core version must be MAJOR.MINOR.PATCH: '${version}'."

  local major="${core_parts[0]}"
  local minor="${core_parts[1]}"
  local patch="${core_parts[2]}"
  local part

  for part in "${major}" "${minor}" "${patch}"; do
    [[ "${part}" =~ ^(0|[1-9][0-9]*)$ ]] \
      || fail "core version identifiers must be non-negative integers without leading zeroes: '${version}'."
  done

  local no_build="${core}"
  if [[ -n "${prerelease}" ]]; then
    no_build="${core}-${prerelease}"
  fi

  printf -v "${prefix}_major" '%s' "${major}"
  printf -v "${prefix}_minor" '%s' "${minor}"
  printf -v "${prefix}_patch" '%s' "${patch}"
  printf -v "${prefix}_prerelease" '%s' "${prerelease}"
  printf -v "${prefix}_build" '%s' "${build}"
  printf -v "${prefix}_core" '%s' "${core}"
  printf -v "${prefix}_no_build" '%s' "${no_build}"
}

cmp_uint() {
  local left="${1}"
  local right="${2}"

  if ((${#left} > ${#right})); then
    echo 1
    return
  fi
  if ((${#left} < ${#right})); then
    echo -1
    return
  fi
  if [[ "${left}" > "${right}" ]]; then
    echo 1
    return
  fi
  if [[ "${left}" < "${right}" ]]; then
    echo -1
    return
  fi
  echo 0
}

cmp_prerelease() {
  local left="$1"
  local right="$2"

  if [[ -z "${left}" ]] && [[ -z "${right}" ]]; then
    echo 0
    return
  fi
  if [[ -z "${left}" ]]; then
    echo 1
    return
  fi
  if [[ -z "${right}" ]]; then
    echo -1
    return
  fi

  local -a left_ids
  local -a right_ids
  local i
  local left_id
  local right_id
  local cmp

  IFS='.' read -r -a left_ids <<<"${left}"
  IFS='.' read -r -a right_ids <<<"${right}"

  for ((i = 0; i < ${#left_ids[@]} || i < ${#right_ids[@]}; i++)); do
    if ((i >= ${#left_ids[@]})); then
      echo -1
      return
    fi
    if ((i >= ${#right_ids[@]})); then
      echo 1
      return
    fi

    left_id="${left_ids[i]}"
    right_id="${right_ids[i]}"

    if [[ "${left_id}" =~ ^[0-9]+$ ]] && [[ "${right_id}" =~ ^[0-9]+$ ]]; then
      cmp="$(cmp_uint "${left_id}" "${right_id}")"
      if [[ "${cmp}" != "0" ]]; then
        echo "${cmp}"
        return
      fi
      continue
    fi

    if [[ "${left_id}" =~ ^[0-9]+$ ]] && [[ ! "${right_id}" =~ ^[0-9]+$ ]]; then
      echo -1
      return
    fi
    if [[ ! "${left_id}" =~ ^[0-9]+$ ]] && [[ "${right_id}" =~ ^[0-9]+$ ]]; then
      echo 1
      return
    fi

    if [[ "${left_id}" > "${right_id}" ]]; then
      echo 1
      return
    fi
    if [[ "${left_id}" < "${right_id}" ]]; then
      echo -1
      return
    fi
  done

  echo 0
}

compare_semver() {
  local left_version="$1"
  local right_version="$2"

  parse_semver "${left_version}" "left"
  parse_semver "${right_version}" "right"

  local cmp

  cmp="$(cmp_uint "${left_major}" "${right_major}")"
  if [[ "${cmp}" != "0" ]]; then
    echo "${cmp}"
    return
  fi

  cmp="$(cmp_uint "${left_minor}" "${right_minor}")"
  if [[ "${cmp}" != "0" ]]; then
    echo "${cmp}"
    return
  fi

  cmp="$(cmp_uint "${left_patch}" "${right_patch}")"
  if [[ "${cmp}" != "0" ]]; then
    echo "${cmp}"
    return
  fi

  cmp_prerelease "${left_prerelease}" "${right_prerelease}"
}

check_pubspec_command() {
  local ref="HEAD"

  while (($# > 0)); do
    case "$1" in
      --ref)
        shift
        (($# > 0)) || fail "missing value for --ref."
        ref="$1"
        ;;
      *)
        usage >&2
        exit 2
        ;;
    esac
    shift
  done

  local version
  version="$(get_pubspec_version_at_ref "${ref}")"
  parse_semver "${version}" "pubspec"
  echo "SemVer check passed for pubspec.yaml at ${ref}: ${version}"
}

check_pr_main_command() {
  local base=""
  local head=""

  while (($# > 0)); do
    case "$1" in
      --base)
        shift
        (($# > 0)) || fail "missing value for --base."
        base="$1"
        ;;
      --head)
        shift
        (($# > 0)) || fail "missing value for --head."
        head="$1"
        ;;
      *)
        usage >&2
        exit 2
        ;;
    esac
    shift
  done

  [[ -n "${base}" ]] || fail "missing required --base."
  [[ -n "${head}" ]] || fail "missing required --head."

  git cat-file -e "${base}^{commit}" 2>/dev/null || fail "base commit not found: ${base}"
  git cat-file -e "${head}^{commit}" 2>/dev/null || fail "head commit not found: ${head}"

  local base_version
  local head_version
  local cmp
  local changelog
  local changelog_diff
  local escaped_release

  base_version="$(get_pubspec_version_at_ref "${base}")"
  head_version="$(get_pubspec_version_at_ref "${head}")"

  parse_semver "${head_version}" "head"
  cmp="$(compare_semver "${head_version}" "${base_version}")"
  if [[ "${cmp}" != "1" ]]; then
    fail "pubspec version must increase for a PR to main (base=${base_version}, head=${head_version})."
  fi

  if [[ -n "${head_prerelease}" ]]; then
    fail "pre-release pubspec versions are not allowed for main release PRs: '${head_version}'."
  fi

  changelog="$(git_file_at_ref "${head}" "CHANGELOG.md")" \
    || fail "CHANGELOG.md not found at head ref '${head}'."

  escaped_release="$(regex_escape "${head_no_build}")"
  grep -Eq "^## \[${escaped_release}\] - [0-9]{4}-[0-9]{2}-[0-9]{2}( \[YANKED\])?$" <<<"${changelog}" \
    || fail "CHANGELOG.md at head must contain: ## [${head_no_build}] - YYYY-MM-DD"

  changelog_diff="$(git diff --unified=0 "${base}" "${head}" -- CHANGELOG.md)"
  grep -Eq "^\+## \[${escaped_release}\] - [0-9]{4}-[0-9]{2}-[0-9]{2}( \[YANKED\])?$" <<<"${changelog_diff}" \
    || fail "PR to main must add the release header for ${head_no_build} in CHANGELOG.md."

  echo "SemVer main release PR check passed (base=${base_version}, head=${head_version})."
}

check_tag_command() {
  local tag=""
  local ref=""
  local tag_version
  local pubspec_version
  local changelog
  local escaped_release

  while (($# > 0)); do
    case "$1" in
      --tag)
        shift
        (($# > 0)) || fail "missing value for --tag."
        tag="$1"
        ;;
      --ref)
        shift
        (($# > 0)) || fail "missing value for --ref."
        ref="$1"
        ;;
      *)
        usage >&2
        exit 2
        ;;
    esac
    shift
  done

  [[ -n "${tag}" ]] || fail "missing required --tag."
  [[ -n "${ref}" ]] || fail "missing required --ref."

  if [[ ! "${tag}" =~ ^v(.+)$ ]]; then
    fail "tag must be prefixed with 'v', got '${tag}'."
  fi
  tag_version="${BASH_REMATCH[1]}"

  parse_semver "${tag_version}" "tag"
  pubspec_version="$(get_pubspec_version_at_ref "${ref}")"
  parse_semver "${pubspec_version}" "pubspec"

  if [[ "${tag_no_build}" != "${pubspec_no_build}" ]]; then
    fail "tag version (${tag_no_build}) must match pubspec version without build metadata (${pubspec_no_build})."
  fi

  changelog="$(git_file_at_ref "${ref}" "CHANGELOG.md")" \
    || fail "CHANGELOG.md not found at ref '${ref}'."

  escaped_release="$(regex_escape "${tag_no_build}")"
  grep -Eq "^## \[${escaped_release}\] - [0-9]{4}-[0-9]{2}-[0-9]{2}( \[YANKED\])?$" <<<"${changelog}" \
    || fail "CHANGELOG.md at tag ref must contain: ## [${tag_no_build}] - YYYY-MM-DD"

  echo "SemVer tag check passed (tag=${tag}, pubspec=${pubspec_version})."
}

main() {
  (($# > 0)) || {
    usage >&2
    exit 2
  }

  local command="$1"
  shift

  case "${command}" in
    check-pubspec)
      check_pubspec_command "$@"
      ;;
    check-pr-main)
      check_pr_main_command "$@"
      ;;
    check-tag)
      check_tag_command "$@"
      ;;
    -h|--help|help)
      usage
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
}

main "$@"
