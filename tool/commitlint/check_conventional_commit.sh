#!/usr/bin/env bash
set -euo pipefail

readonly HEADER_REGEX='^(build|chore|ci|docs|feat|fix|perf|refactor|revert|style|test)(\([a-z0-9][a-z0-9._/-]*\))?(!)?: .+$'
readonly MAX_HEADER_LENGTH=100

print_usage() {
  cat <<'USAGE'
Usage:
  check_conventional_commit.sh <commit_message_file>
  check_conventional_commit.sh --rev-range <git_rev_range>
USAGE
}

extract_header_from_file() {
  local message_file="$1"

  awk '
    {
      gsub(/\r$/, "", $0)
      line=$0
      sub(/^[[:space:]]+/, "", line)
      sub(/[[:space:]]+$/, "", line)
      if (line == "" || line ~ /^#/) {
        next
      }
      print line
      exit
    }
  ' "${message_file}"
}

validate_header() {
  local header="$1"

  if [[ -z "${header}" ]]; then
    echo "Conventional Commit check failed: missing commit header." >&2
    return 1
  fi

  if ((${#header} > MAX_HEADER_LENGTH)); then
    echo "Conventional Commit check failed: header exceeds ${MAX_HEADER_LENGTH} characters." >&2
    echo "Header: ${header}" >&2
    return 1
  fi

  # Allow git-generated revert subjects.
  if [[ "${header}" =~ ^Revert\ \".+\"$ ]]; then
    return 0
  fi

  if [[ ! "${header}" =~ ${HEADER_REGEX} ]]; then
    echo "Conventional Commit check failed: invalid header format." >&2
    echo "Expected: <type>(optional-scope)!: <description>" >&2
    echo "Example: feat(chat): support media upload retries" >&2
    echo "Header: ${header}" >&2
    return 1
  fi
}

validate_message_file() {
  local message_file="$1"

  if [[ ! -f "${message_file}" ]]; then
    echo "Conventional Commit check failed: commit message file not found: ${message_file}" >&2
    return 1
  fi

  local header
  header="$(extract_header_from_file "${message_file}")"
  validate_header "${header}"
}

validate_commit_range() {
  local rev_range="$1"
  local -a commits
  local failures=0

  mapfile -t commits < <(git rev-list --no-merges "${rev_range}")

  if ((${#commits[@]} == 0)); then
    echo "No non-merge commits found in range '${rev_range}'."
    return 0
  fi

  for commit_sha in "${commits[@]}"; do
    local header
    header="$(git show -s --format=%s "${commit_sha}")"
    if ! validate_header "${header}"; then
      echo "Commit ${commit_sha} failed validation." >&2
      failures=$((failures + 1))
    fi
  done

  if ((failures > 0)); then
    echo "Conventional Commit check failed for ${failures} commit(s)." >&2
    return 1
  fi

  echo "Conventional Commit check passed for ${#commits[@]} commit(s)."
}

main() {
  if (($# == 1)); then
    validate_message_file "$1"
    exit 0
  fi

  if (($# == 2)) && [[ "$1" == "--rev-range" ]]; then
    validate_commit_range "$2"
    exit 0
  fi

  print_usage >&2
  exit 2
}

main "$@"
