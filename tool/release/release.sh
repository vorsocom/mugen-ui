#!/usr/bin/env bash
set -euo pipefail

readonly ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly PUBSPEC_PATH="${ROOT_DIR}/pubspec.yaml"
readonly CHANGELOG_PATH="${ROOT_DIR}/CHANGELOG.md"
readonly GATES_SCRIPT="${ROOT_DIR}/tool/release/run_release_gates.sh"
readonly BOOTSTRAP_VERSION="0.1.0"

usage() {
  cat <<'USAGE'
Usage:
  release.sh prepare [--bump patch|minor|major] [--version x.y.z] [--skip-gates] [--push]
  release.sh finish --version x.y.z
  release.sh publish --version x.y.z [--keep-release-branch] [--keep-remote-release-branch]
USAGE
}

fail() {
  echo "Release automation failed: $1" >&2
  exit 1
}

run_git() {
  git -C "${ROOT_DIR}" "$@"
}

current_branch() {
  run_git rev-parse --abbrev-ref HEAD
}

ensure_clean_worktree() {
  local status
  status="$(run_git status --short)"
  [[ -z "${status}" ]] || fail "working tree is not clean."
}

ensure_branch() {
  local expected="$1"
  local current
  current="$(current_branch)"
  [[ "${current}" == "${expected}" ]] || fail "expected current branch '${expected}', found '${current}'."
}

ensure_synced_with_origin_develop() {
  local local_head
  local remote_head

  local_head="$(run_git rev-parse HEAD)"
  remote_head="$(run_git rev-parse origin/develop)"

  [[ "${local_head}" == "${remote_head}" ]] || fail "develop must match origin/develop before preparing a release."
}

branch_exists_local() {
  local branch="$1"
  run_git show-ref --verify --quiet "refs/heads/${branch}"
}

branch_exists_remote() {
  local branch="$1"
  [[ -n "$(run_git ls-remote --heads origin "${branch}")" ]]
}

tag_exists_remote() {
  local tag="$1"
  [[ -n "$(run_git ls-remote --tags origin "${tag}")" ]]
}

tag_exists_anywhere() {
  local tag="$1"
  [[ -n "$(run_git tag -l "${tag}")" ]] || tag_exists_remote "${tag}"
}

git_file_at_ref() {
  local ref="$1"
  local path="$2"
  run_git show "${ref}:${path}" 2>/dev/null
}

file_exists_at_ref() {
  local ref="$1"
  local path="$2"
  run_git cat-file -e "${ref}:${path}" 2>/dev/null
}

validate_stable_version() {
  local version="$1"
  [[ "${version}" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] \
    || fail "version must be stable SemVer (x.y.z), got '${version}'."
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

pubspec_version_at_ref() {
  local ref="$1"
  local content
  local version

  content="$(git_file_at_ref "${ref}" "pubspec.yaml")" || fail "pubspec.yaml not found at ref '${ref}'."
  version="$(extract_pubspec_version_from_content <<<"${content}")"
  [[ -n "${version}" ]] || fail "version not found in pubspec.yaml at ref '${ref}'."
  echo "${version}"
}

working_tree_pubspec_version() {
  local version
  version="$(extract_pubspec_version_from_content <"${PUBSPEC_PATH}")"
  [[ -n "${version}" ]] || fail "version not found in ${PUBSPEC_PATH}."
  echo "${version}"
}

strip_build_metadata() {
  local version="$1"
  echo "${version%%+*}"
}

extract_build_suffix() {
  local version="$1"
  if [[ "${version}" == *"+"* ]]; then
    echo "+${version#*+}"
    return
  fi
  echo ""
}

bump_version() {
  local version="$1"
  local part="$2"
  local major
  local minor
  local patch

  validate_stable_version "${version}"
  IFS='.' read -r major minor patch <<<"${version}"

  case "${part}" in
    major)
      echo "$((major + 1)).0.0"
      ;;
    minor)
      echo "${major}.$((minor + 1)).0"
      ;;
    patch)
      echo "${major}.${minor}.$((patch + 1))"
      ;;
    *)
      fail "unsupported bump part '${part}'."
      ;;
  esac
}

update_pubspec_version() {
  local target_version="$1"
  perl -0pi -e 's/^version:\s*.*$/version: '"${target_version}"'/m' "${PUBSPEC_PATH}"
}

promote_changelog_release() {
  local version="$1"
  local release_date="$2"

  RELEASE_VERSION="${version}" RELEASE_DATE="${release_date}" perl -0pi -e '
    my $version = $ENV{RELEASE_VERSION};
    my $date = $ENV{RELEASE_DATE};
    my $template = <<"EOF";
## [Unreleased]

### Added

### Changed

### Deprecated

### Removed

### Fixed

### Security

## [$version] - $date

EOF

    my $updated = s{^## \[Unreleased\]\n(.*?)(?=^## \[|\z)}{
      my $body = $1;
      $body =~ s/\A\s+//s;
      $body =~ s/\s+\z//s;
      $body = length($body) ? "$body\n\n" : "\n";
      $template . $body;
    }ems;

    if (!$updated) {
      die "missing or malformed ## [Unreleased] section\n";
    }
  ' "${CHANGELOG_PATH}" || fail "failed to promote CHANGELOG.md release section."
}

ensure_unreleased_section() {
  grep -Eq '^## \[Unreleased\]$' "${CHANGELOG_PATH}" \
    || fail "CHANGELOG.md must include '## [Unreleased]'."
}

fetch_release_refs() {
  run_git fetch origin develop main --tags --prune
}

is_bootstrap_release() {
  ! file_exists_at_ref "origin/main" "pubspec.yaml"
}

release_branch_for_version() {
  local version="$1"
  echo "release/${version}"
}

tag_for_version() {
  local version="$1"
  echo "v${version}"
}

release_pr_title() {
  local version="$1"
  echo "chore(release): ${version}"
}

release_pr_body() {
  local version="$1"
  cat <<EOF
Prepare release ${version} for merge into \`main\`.

Generated by \`tool/release/release.sh finish\`.
Tag the merged \`main\` commit and sync \`develop\` after this PR lands.
EOF
}

sync_pr_title() {
  local version="$1"
  echo "chore(release): sync ${version} back to develop"
}

sync_pr_body() {
  local version="$1"
  cat <<EOF
Sync released version ${version} back into \`develop\`.

Generated by \`tool/release/release.sh publish\`.
Cleanup the release branch after this PR lands.
EOF
}

branch_pr_field() {
  local head_branch="$1"
  local base_branch="$2"
  local state="$3"
  local fields="$4"
  local query="$5"

  gh pr list \
    --limit 1 \
    --state "${state}" \
    --base "${base_branch}" \
    --head "${head_branch}" \
    --json "${fields}" \
    --jq "if length == 0 then \"\" else .[0].${query} // \"\" end"
}

ensure_release_branch_ready_for_pr() {
  local release_branch="$1"

  if branch_exists_remote "${release_branch}"; then
    return
  fi

  branch_exists_local "${release_branch}" || fail "release branch not found: ${release_branch}"
  run_git push -u origin "${release_branch}"
}

ensure_release_branch_available_locally() {
  local release_branch="$1"

  if branch_exists_local "${release_branch}"; then
    return 0
  fi

  if ! branch_exists_remote "${release_branch}"; then
    return 1
  fi

  run_git fetch origin "${release_branch}:${release_branch}"
}

commit_exists_locally() {
  local commitish="$1"
  run_git rev-parse --verify --quiet "${commitish}^{commit}" >/dev/null
}

resolve_commitish() {
  local commitish="$1"
  run_git rev-parse "${commitish}^{commit}"
}

is_ancestor() {
  local ancestor="$1"
  local descendant="$2"
  run_git merge-base --is-ancestor "${ancestor}" "${descendant}"
}

repo_name_with_owner() {
  gh repo view --json nameWithOwner --jq '.nameWithOwner'
}

delete_remote_branch_via_gh() {
  local branch="$1"
  local repo
  local encoded_branch

  repo="$(repo_name_with_owner)"
  encoded_branch="${branch//\//%2F}"
  gh api "repos/${repo}/git/refs/heads/${encoded_branch}" --method DELETE >/dev/null
}

prepare_release() {
  local bump_part="patch"
  local explicit_version=""
  local skip_gates=0
  local push_branch=0

  while (($# > 0)); do
    case "$1" in
      --bump)
        shift
        (($# > 0)) || fail "missing value for --bump."
        bump_part="$1"
        ;;
      --version)
        shift
        (($# > 0)) || fail "missing value for --version."
        explicit_version="$1"
        ;;
      --skip-gates)
        skip_gates=1
        ;;
      --push)
        push_branch=1
        ;;
      *)
        usage >&2
        exit 2
        ;;
    esac
    shift
  done

  ensure_clean_worktree
  ensure_branch "develop"
  fetch_release_refs
  ensure_synced_with_origin_develop
  ensure_unreleased_section

  local current_version
  local current_release_version
  local build_suffix
  local bootstrap
  local target_release_version
  local target_pubspec_version
  local release_branch
  local release_date

  current_version="$(working_tree_pubspec_version)"
  current_release_version="$(strip_build_metadata "${current_version}")"
  build_suffix="$(extract_build_suffix "${current_version}")"

  if is_bootstrap_release; then
    bootstrap=1
  else
    bootstrap=0
  fi

  if [[ -n "${explicit_version}" ]]; then
    target_release_version="${explicit_version}"
  elif ((bootstrap == 1)); then
    target_release_version="${BOOTSTRAP_VERSION}"
  else
    target_release_version="$(bump_version "${current_release_version}" "${bump_part}")"
  fi

  validate_stable_version "${target_release_version}"

  if ((bootstrap == 1)) && [[ "${target_release_version}" != "${BOOTSTRAP_VERSION}" ]]; then
    fail "the first release to an empty main branch must be ${BOOTSTRAP_VERSION}."
  fi

  if ((bootstrap == 0)) && [[ "${target_release_version}" == "${current_release_version}" ]]; then
    fail "target version equals current develop version."
  fi

  target_pubspec_version="${target_release_version}${build_suffix}"
  release_branch="$(release_branch_for_version "${target_release_version}")"
  release_date="$(date -u +%F)"

  if branch_exists_local "${release_branch}"; then
    fail "local branch already exists: ${release_branch}"
  fi
  if branch_exists_remote "${release_branch}"; then
    fail "remote branch already exists: ${release_branch}"
  fi
  if tag_exists_anywhere "$(tag_for_version "${target_release_version}")"; then
    fail "tag already exists: $(tag_for_version "${target_release_version}")"
  fi

  run_git checkout -b "${release_branch}" develop
  update_pubspec_version "${target_pubspec_version}"
  promote_changelog_release "${target_release_version}" "${release_date}"

  if ((skip_gates == 0)); then
    "${GATES_SCRIPT}"
  fi

  run_git add pubspec.yaml CHANGELOG.md
  run_git commit -m "chore(release): prepare ${target_release_version}"

  if ((push_branch == 1)); then
    run_git push -u origin "${release_branch}"
  fi

  echo "Release branch ready: ${release_branch}"
  echo "Version: ${target_pubspec_version}"
  echo "Next: run tool/release/release.sh finish --version ${target_release_version}"
}

finish_release() {
  local version=""

  while (($# > 0)); do
    case "$1" in
      --version)
        shift
        (($# > 0)) || fail "missing value for --version."
        version="$1"
        ;;
      *)
        usage >&2
        exit 2
        ;;
    esac
    shift
  done

  [[ -n "${version}" ]] || fail "missing required --version."
  validate_stable_version "${version}"
  ensure_clean_worktree
  fetch_release_refs

  local release_branch
  local tag_name
  local merged_pr_url
  local open_pr_url
  local pr_url

  release_branch="$(release_branch_for_version "${version}")"
  tag_name="$(tag_for_version "${version}")"
  ensure_release_branch_ready_for_pr "${release_branch}"

  if tag_exists_anywhere "${tag_name}"; then
    fail "tag already exists: ${tag_name}"
  fi

  merged_pr_url="$(branch_pr_field "${release_branch}" "main" "merged" "url" "url")"
  if [[ -n "${merged_pr_url}" ]]; then
    echo "Release PR already merged: ${merged_pr_url}"
    echo "Next: run tool/release/release.sh publish --version ${version}"
    return
  fi

  open_pr_url="$(branch_pr_field "${release_branch}" "main" "open" "url" "url")"
  if [[ -n "${open_pr_url}" ]]; then
    echo "Release PR already open: ${open_pr_url}"
    echo "Next: merge the PR, then run tool/release/release.sh publish --version ${version}"
    return
  fi

  pr_url="$(gh pr create \
    --base main \
    --head "${release_branch}" \
    --title "$(release_pr_title "${version}")" \
    --body "$(release_pr_body "${version}")")"

  echo "Release PR ready: ${pr_url}"
  echo "Next: merge the PR, then run tool/release/release.sh publish --version ${version}"
}

publish_release() {
  local version=""
  local keep_release_branch=0
  local keep_remote_release_branch=0

  while (($# > 0)); do
    case "$1" in
      --version)
        shift
        (($# > 0)) || fail "missing value for --version."
        version="$1"
        ;;
      --keep-release-branch)
        keep_release_branch=1
        ;;
      --keep-remote-release-branch)
        keep_remote_release_branch=1
        ;;
      *)
        usage >&2
        exit 2
        ;;
    esac
    shift
  done

  [[ -n "${version}" ]] || fail "missing required --version."
  validate_stable_version "${version}"
  ensure_clean_worktree
  fetch_release_refs

  local release_branch
  local tag_name
  local merged_pr_url
  local merge_commit_oid
  local open_pr_url
  local tag_target
  local sync_merged_url
  local sync_open_url
  local sync_pr_url
  local develop_synced=0
  local develop_status
  local cleanup_status
  local local_cleanup="already absent"
  local remote_cleanup="already absent"

  release_branch="$(release_branch_for_version "${version}")"
  tag_name="$(tag_for_version "${version}")"

  merged_pr_url="$(branch_pr_field "${release_branch}" "main" "merged" "url,mergeCommit" "url")"
  if [[ -z "${merged_pr_url}" ]]; then
    open_pr_url="$(branch_pr_field "${release_branch}" "main" "open" "url" "url")"
    if [[ -n "${open_pr_url}" ]]; then
      fail "release PR not merged yet: ${open_pr_url}"
    fi
    fail "merged release PR not found for ${release_branch}."
  fi

  merge_commit_oid="$(branch_pr_field "${release_branch}" "main" "merged" "url,mergeCommit" "mergeCommit.oid")"
  [[ -n "${merge_commit_oid}" ]] || fail "could not determine merge commit for release PR: ${merged_pr_url}"

  ensure_release_branch_available_locally "${release_branch}" || true

  if ! commit_exists_locally "${merge_commit_oid}"; then
    fail "merge commit is not available locally: ${merge_commit_oid}"
  fi

  if [[ -z "$(run_git tag -l "${tag_name}")" ]]; then
    if tag_exists_remote "${tag_name}"; then
      run_git fetch origin --tags
    fi
  fi

  if [[ -z "$(run_git tag -l "${tag_name}")" ]]; then
    run_git tag -a "${tag_name}" "${merge_commit_oid}" -m "Release ${version}"
    run_git push origin "${tag_name}"
    tag_target="${merge_commit_oid}"
    echo "Created tag ${tag_name} at ${merge_commit_oid}"
  else
    tag_target="$(resolve_commitish "${tag_name}")"
    [[ "${tag_target}" == "${merge_commit_oid}" ]] \
      || fail "tag ${tag_name} already points to ${tag_target}, expected ${merge_commit_oid}."
    echo "Tag ${tag_name} already exists at ${tag_target}"
  fi

  sync_merged_url="$(branch_pr_field "${release_branch}" "develop" "merged" "url" "url")"
  if [[ -n "${sync_merged_url}" ]]; then
    develop_synced=1
    develop_status="PR merged: ${sync_merged_url}"
  elif is_ancestor "${merge_commit_oid}" "origin/develop"; then
    develop_synced=1
    develop_status="already up to date"
  else
    sync_open_url="$(branch_pr_field "${release_branch}" "develop" "open" "url" "url")"
    if [[ -n "${sync_open_url}" ]]; then
      develop_status="PR already open: ${sync_open_url}"
    else
      ensure_release_branch_ready_for_pr "${release_branch}"
      sync_pr_url="$(gh pr create \
        --base develop \
        --head "${release_branch}" \
        --title "$(sync_pr_title "${version}")" \
        --body "$(sync_pr_body "${version}")")"
      develop_status="PR ready: ${sync_pr_url}"
    fi
  fi

  cleanup_status="Release branch cleanup: deferred until develop sync is merged."
  if ((develop_synced == 1)); then
    if branch_exists_local "${release_branch}"; then
      if ((keep_release_branch == 0)); then
        if [[ "$(current_branch)" == "${release_branch}" ]]; then
          run_git checkout develop
        fi
        run_git pull --ff-only origin develop
        run_git branch -d "${release_branch}"
        local_cleanup="deleted"
      else
        local_cleanup="kept"
      fi
    fi

    if branch_exists_remote "${release_branch}"; then
      if ((keep_remote_release_branch == 0)); then
        delete_remote_branch_via_gh "${release_branch}"
        remote_cleanup="deleted"
      else
        remote_cleanup="kept"
      fi
    fi

    cleanup_status="Release branch cleanup: local=${local_cleanup} remote=${remote_cleanup}"
  fi

  echo "Release published for ${version}"
  echo "Release PR: ${merged_pr_url}"
  echo "Tag ${tag_name}: ${tag_target}"
  echo "Develop sync: ${develop_status}"
  echo "${cleanup_status}"
  if ((develop_synced == 0)); then
    echo "Next: merge the develop sync PR, then rerun tool/release/release.sh publish --version ${version}"
  fi
}

main() {
  (($# > 0)) || {
    usage >&2
    exit 2
  }

  local command="$1"
  shift

  case "${command}" in
    prepare)
      prepare_release "$@"
      ;;
    finish)
      finish_release "$@"
      ;;
    publish)
      publish_release "$@"
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
