# mugen-ui Downstream Work Session Prompt

Use this prompt at the start of an agent session inside an existing downstream
UI application repository based on upstream `mugen-ui`. It is standing policy
only until a later concrete task is given.

```text
Behavioral-note handling:
- Treat this entire message as standing policy/context, not an instruction to
  execute work now.
- Do not run commands, checks, git/gh actions, or file edits from this message
  alone.
- First response must be a brief confirmation that you understand and will
  follow these rules.
- After confirming, wait for explicit task instructions.
- Execute the workflows below only when a later concrete task is provided.

Suggested chat title: mugen-ui Downstream Work Session - <APP_SLUG>

Workspace:
- Repository path: <MUGEN_UI_REPO_PATH>
- GitHub repository for writable origin: <GH_REPO>
- Writable remote: origin (<ORIGIN_URL>)
- Read-only upstream remote: upstream (<UPSTREAM_URL>)
- Base branch: develop
- Release branch: main
- This is a Flutter web-only downstream UI project based on upstream mugen-ui.
- Do not make changes outside <MUGEN_UI_REPO_PATH>.

Placeholder replacement check:
- Before using this prompt for an actual task, resolve all required
  placeholders.
- Replace <MUGEN_UI_REPO_PATH>, <GH_REPO>, <ORIGIN_URL>, and <UPSTREAM_URL>.
- <GH_REPO> must use owner/repository form, for example org-or-user/mugen-ui.
- Provide <APP_SLUG>, or default it to the repository name portion of <GH_REPO>
  if no explicit app slug is supplied.
- Derived <APP_SLUG> values must use lowercase letters, digits, and hyphens
  only. If the repository name does not already satisfy that rule after
  lowercasing, stop and ask for the app slug instead of guessing a rewrite.
- If any required placeholder remains when a concrete task starts, stop and ask
  for the missing value instead of guessing.
- Do not include local usernames, absolute paths, or machine-specific values in
  commit messages, PR titles, PR descriptions, branch names, or merge messages.

Approval checkpoint:
- Before any git commit, stop and ask for explicit permission.
- Do not run git commit unless the user gives clear approval, for example:
  "yes, commit".
- After commit approval is granted and the commit is created, proceed
  automatically with required push, PR creation, PR monitoring, merge, and
  cleanup workflows without asking again.
- If commit approval is denied or not provided, stop and report current status
  plus next action options.

Task startup checks:
- Verify the current directory is <MUGEN_UI_REPO_PATH>.
- Verify origin/develop exists. If it does not, stop and report that the base
  branch is missing; do not substitute another base branch.
- Verify the configured origin URL is <ORIGIN_URL>.
- Verify <GH_REPO> is the GitHub owner/repository behind <ORIGIN_URL> before
  running any gh -R <GH_REPO> or gh api repos/<GH_REPO>/... command. If they
  disagree, stop and report the mismatch.
- Verify upstream points to <UPSTREAM_URL>, upstream push URL is PUSH_DISABLED,
  remote.upstream.tagOpt is --no-tags, and the upstream fetch refspec includes
  only refs/heads/main.
- Verify remote.origin.tagOpt is --no-tags. If it is not, configure it before
  fetching:
  git config remote.origin.tagOpt --no-tags
- Verify the local branch is not develop or main before editing. If needed,
  fetch develop explicitly with git fetch origin develop --prune --no-tags,
  start from fresh origin/develop, and create a feature branch.
- Verify gh --version.
- Verify gh auth status.
- If GitHub auth is missing or invalid, stop and report this exact next
  command:
  gh auth login -h github.com --insecure-storage
- Use gh -R <GH_REPO> for PR creation, inspection, monitoring, and merge.
- For gh api, use explicit repos/<GH_REPO> endpoints because gh api
  does not accept -R.
- Do not rely on default GitHub repo resolution.

Git workflow:
- Always branch from develop.
- Refresh develop with explicit no-tag fetches, not broad all-branch or tag
  fetches.
- Never commit directly to develop or main.
- Create a feature branch for the task, such as fix/topic, feat/topic,
  docs/topic, chore/topic, or test/topic.
- Branch names must be lowercase and hyphenated, with no spaces, local
  usernames, absolute paths, raw issue text containing sensitive details, or
  private customer names.
- Push only the feature branch to origin.
- Use conventional commits for commit subjects, PR titles, and merge-commit
  subjects.
- Push only the feature branch and provide the PR URL.

Branch and tag hygiene:
- Do not manually run git fetch --tags, git pull --tags, or git push --tags
  outside approved downstream release automation.
- Do not fetch or import tags for normal develop-targeted work.
- Inspect downstream origin tags only with git ls-remote --tags <ORIGIN_URL>
  when downstream tag information is needed.
- Inspect upstream tags only with:
  git ls-remote --tags <UPSTREAM_URL>
- Fetch upstream/main only for upstream sync and fetch it directly with
  --no-tags.
- If a downstream release task creates a tag, use downstream-owned adapted
  automation or push only the explicit app-prefixed release tag. Never push all
  local tags.

Downstream UI upstream sync policy:
- Downstream UI apps must sync upstream changes from upstream/main only because
  upstream releases are published to main.
- Never sync downstream UI apps from upstream/develop, broad upstream refspecs,
  or imported upstream tags.
- Fetch upstream releases only with:
  git fetch upstream main --no-tags
- Merge upstream/main into develop, then resolve conflicts while preserving
  downstream-owned files, app-prefixed release policy, and downstream-owned
  release automation.
- Review upstream release, workflow, build, and extension-surface changes during
  each upstream sync, then port only the relevant changes into downstream-owned
  surfaces.
- Do not make canonical upstream release/X.Y.Z branches or vX.Y.Z tags the
  downstream release source of truth.
- After each upstream sync, update downstream.toml upstream provenance if the
  file exists: upstream.branch stays "main", upstream.sync_ref becomes the exact
  merged upstream/main commit, and upstream.sync_tag is set only when that
  commit resolves to exactly one upstream tag via git ls-remote --tags
  <UPSTREAM_URL>.

Architecture guidelines:
- Read docs/project-layout.md and docs/extension-surface.md before making
  structural app changes.
- Respect the Clean Architecture dependency direction:
  presentation -> application -> domain <- infrastructure.
- Keep domain code free of Flutter, Riverpod, http, web, infrastructure, and
  presentation imports.
- Keep application code free of Flutter widget/material APIs.
- Do not introduce dynamic config-driven widget lookup for routes, panels, or
  feature registration.
- Use lib/extension/app_definition.dart as the downstream app assembly seam for
  routes, settings panels, app config, and provider overrides.
- After structural changes, run dart run tool/architecture/check_dependencies.dart
  and include the result in the final report.

Deployment and hosting policy:
- Treat upstream .github/workflows, tool/release, web build behavior, and
  hosting build specs as upstream-owned unless the downstream app explicitly
  forks that behavior.
- Put downstream-specific deployment, hosting, and release automation in
  downstream-owned files with distinct names.
- When changing Flutter web build inputs, environment contracts, or hosting
  behavior, update the relevant docs and CI/release workflow expectations in
  the same task.
- Keep public web runtime configuration explicit and documented. Do not commit
  secrets, raw environment values, signing material, or machine-specific paths.
- Preserve the MUGEN_UI_API_BASE_URL build/runtime contract unless the task
  explicitly changes the API endpoint configuration model.
- For release or hosting changes, verify flutter build web --release
  --no-wasm-dry-run before opening or updating a PR.

Downstream provenance metadata:
- downstream.toml, if present, is downstream-owned provenance metadata.
- It is modeled after conf/downstream.toml.sample, but the downstream copy is
  not disposable after initialization.
- Keep downstream.toml free of runtime settings, secrets, local paths,
  machine-specific values, and raw environment variable values.
- Only edit downstream.toml when the task requires downstream app metadata,
  upstream sync metadata, release metadata, or provenance maintenance.
- Never overwrite downstream.toml wholesale from conf/downstream.toml.sample.
- Preserve unrelated downstream.toml values when updating it.
- Before editing downstream.toml, create _dev/bak if needed and write a
  timestamped backup such as _dev/bak/downstream.toml.pre-edit-<timestamp>.bak.
- Treat _dev/bak backups as local safety artifacts. Do not commit them unless
  the user explicitly requests that exact backup artifact to be committed.
- When updating upstream sync provenance, set upstream.branch to "main", set
  upstream.sync_ref to the exact upstream/main commit used, and set
  upstream.sync_tag only when that commit resolves to exactly one upstream tag
  checked with git ls-remote --tags <UPSTREAM_URL> without importing tags.
- After editing downstream.toml, validate it with a TOML parser, report keys
  structurally added, removed, or relocated, confirm unrelated values were
  preserved, and name the backup file.

Canonical mugen-ui release workflow reference:
- Upstream mugen-ui releases use release/X.Y.Z branches, vX.Y.Z tags,
  pubspec.yaml versions, and dated CHANGELOG.md release headers.
- Upstream mugen-ui release automation lives in .github/workflows/release.yml
  and tool/release/release.sh.
- Treat upstream release automation as context only. Do not run or copy it
  unchanged for downstream UI app releases.
- Use upstream/main as the downstream sync source because upstream releases are
  published to main.

Downstream UI app release policy:
- Downstream UI app releases must not use canonical tool/release/release.sh
  unchanged because canonical release/X.Y.Z branches and vX.Y.Z tags can collide
  with upstream mugen-ui release names.
- Before any downstream UI release task, require <APP_SLUG>. If missing,
  default it to the repository name portion of <GH_REPO>, then validate it uses
  lowercase letters, digits, and hyphens only.
- Downstream UI app release branches must use release/<APP_SLUG>-vX.Y.Z.
- Downstream UI app release tags must use <APP_SLUG>-vX.Y.Z.
- Reject bare downstream release branches such as release/X.Y.Z and bare tags
  such as vX.Y.Z.
- Keep upstream/canonical release automation unchanged unless the user
  explicitly chooses to fork that behavior.
- If downstream UI release automation is needed, create downstream-owned
  automation with distinct names and paths, such as downstream/,
  .github/workflows/release-<APP_SLUG>.yml, or
  tool/release/release-downstream-<APP_SLUG>.sh.
- Downstream automation must preserve upstream merge cleanliness and keep
  branch, tag, and changelog conventions app-prefixed.
- Inspect upstream/canonical tags only with git ls-remote --tags <UPSTREAM_URL>
  when comparing release history. Do not fetch or import upstream tags locally
  for downstream release work.
- Downstream UI apps must sync upstream changes from upstream/main only. Never
  sync from upstream/develop for downstream release baselines.
- Push only explicit downstream release tags. Never run git push --tags.

Important release policy:
- develop is the integration branch; main is the release branch.
- For downstream UI apps, use downstream-owned adapted automation if automation
  is needed.
- Keep release branches, release tags, pubspec.yaml versions, and CHANGELOG.md
  release headers aligned.
- Never broaden a release task into unrelated feature work.
- Downstream UI app release branches and tags are app-prefixed with
  <APP_SLUG>-vX.Y.Z.
- Never run broad tag pushes; push only the explicit release tag when a manual
  fallback is required.

Conventional commit enforcement:
- The git commit subject, PR title, and merge-commit subject must all use
  conventional commit format.
- Allowed forms include:
  - type: description
  - type(scope): description
  - type!: description
  - type(scope)!: description
- Allowed types: build, chore, ci, docs, feat, fix, perf, refactor, revert,
  style, test.
- The description must be concise, imperative, and must not end with a period.
- Keep the subject within 100 characters.
- Validate before git commit, before gh pr create, and before gh pr merge:
  tool/commitlint/check_conventional_commit.sh --pr-title "fix(scope): example"
- If any subject/title is invalid, correct it before proceeding.

Quality gates before commit or push:
1. Run:
   flutter pub get
2. Run:
   flutter analyze
3. Run:
   dart run tool/architecture/check_dependencies.dart
4. Run:
   flutter test --coverage
5. Run:
   tool/coverage/check_line_coverage.sh --lcov coverage/lcov.info --minimum 100
6. Run:
   flutter build web --release --no-wasm-dry-run
7. Ensure CHANGELOG.md is updated under ## [Unreleased] with at least one Keep
   a Changelog bullet entry.

Quality confirmation required before commit or push:
- Confirm the complete test suite passed.
- Confirm architecture dependency validation passed.
- Confirm line coverage is still 100%.
- Confirm the web release build passed.
- If any quality gate fails, do not commit or push. Report the failure and next
  debugging options.

PR creation and monitoring:
- After commit approval is granted, create the commit.
- Push the feature branch to origin.
- For normal development tasks, create the PR with gh pr create -R <GH_REPO>
  --base develop targeting the current feature branch.
- For downstream release or sync-back tasks, use the downstream-owned release
  automation and target the branch required by that downstream release policy.
- Provide the created PR URL from gh.
- PR descriptions must not include system details: no absolute paths, usernames,
  interpreter locations, machine-specific commands, secrets, local repo names,
  raw environment variable values, or private customer names.
- After PR creation, monitor GitHub status with gh pr view -R
  <GH_REPO> and/or gh pr checks -R <GH_REPO>.
- Poll every 30 seconds for up to 30 minutes from PR creation.
- During monitoring, report only meaningful status changes.
- Continue automatically while checks are pending and no human action is
  required.
- Stop and report immediately if any required check fails, required review or
  approval is missing, merge conflicts exist, branch protection or repo policy
  blocks merge, gh cannot determine status reliably, or the 30-minute timeout is
  reached.
- If timeout occurs, report the latest PR state, outstanding blockers, and exact
  next gh commands to continue later.
- When the PR is mergeable within the monitoring window, generate and report a
  conventional merge-commit message.
- Merge with a regular merge commit, not a squash merge:
  gh pr merge -R <GH_REPO> "${pr_url_or_number}" --merge --delete-branch=false --subject "${merge_subject}" --body ""
- After merge, report the merged PR URL and resulting commit SHA if available.

GitHub Actions troubleshooting:
- Use gh with <GH_REPO> explicitly when inspecting workflow runs, checks, PRs,
  and annotations.
- If a PR check fails and the normal log is unclear, inspect check-run
  annotations:
  gh api repos/<GH_REPO>/check-runs/CHECK_RUN_ID/annotations
- Always pass the explicit repo for failed job logs:
  gh run view -R <GH_REPO> RUN_ID --job JOB_ID --log-failed
- For Flutter failures, distinguish dependency resolution, analyzer,
  architecture validation, tests, coverage, and web release build failures in
  the report.
- If GitHub Actions status cannot be determined reliably, stop and report the
  exact gh commands needed to continue.

Reporting requirements:
- Show exactly what changed, with files and purpose.
- Summarize key command results for analyze, tests, coverage, architecture
  validation, and build.
- Include key git/gh results: branch, commit, push, PR creation, PR monitoring
  outcome, merge result, and cleanup result.
- After creating a PR, always generate and provide a merge-commit message.
- If blocked, stop and report the blocker with next action options.

Post-merge cleanup:
1. git checkout develop
2. git pull --ff-only origin develop
3. Capture the merged feature branch name in feature_branch before deleting it
   locally.
4. git update-ref -d "refs/heads/${feature_branch}"
5. URL-encode the feature branch name for the GitHub API. For example,
   fix/chat-scroll-anchor becomes fix%2Fchat-scroll-anchor.
6. Delete the remote feature branch with:
   gh api "repos/<GH_REPO>/git/refs/heads/${encoded_branch}" --method DELETE
7. If the remote branch is already absent, report it as already cleaned up.
8. Confirm final state with:
   git status --short
   git branch --show-current
   git rev-parse --short HEAD
```
