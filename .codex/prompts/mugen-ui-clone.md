# mugen-ui Downstream Clone Prompt

Use this prompt to create or onboard a downstream UI application repository
from upstream `mugen-ui` while keeping future upstream merges clean.

```text
Clone or onboard a downstream UI application repository from upstream mugen-ui.

Suggested chat title: mugen-ui Downstream Clone - <APP_SLUG>

Repository identity:
- GitHub repository for writable origin: <GH_REPO>
- Writable origin URL: <ORIGIN_URL>
- Upstream mugen-ui URL: <UPSTREAM_URL>
- Base branch: develop
- Release branch: main
- Local workspace: <MUGEN_UI_REPO_PATH>

Inputs:
- Local directory for the clone: <MUGEN_UI_REPO_PATH>.
- Downstream app slug: <APP_SLUG>. Use lowercase letters, digits, and hyphens
  only.
- If the local directory already exists, do not overwrite it. Inspect it and
  verify it is the intended mugen-ui repository before continuing.

Placeholder replacement check:
- Before using this prompt for an actual clone or onboarding task, resolve all
  required placeholders.
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
  reports intended for commits, PRs, release notes, or other shared surfaces.

Preflight requirements:
1. Verify the target local directory does not exist unless the user explicitly
   asks to reuse an existing directory.
2. Verify gh --version.
3. Verify gh auth status.
4. If GitHub auth is missing or invalid, stop and report this exact next
   command:
   gh auth login -h github.com --insecure-storage
5. Verify upstream main is reachable:
   git ls-remote --heads <UPSTREAM_URL> main
6. Verify the writable origin repository is reachable and empty, or stop if it
   already contains branches/tags unless the user explicitly confirms reuse.
   Check heads and tags without cloning:
   git ls-remote --heads <ORIGIN_URL>
   git ls-remote --tags <ORIGIN_URL>

Downstream UI app initialization workflow:
1. Clone only upstream main, with full history for that branch and no tags:
   git clone --branch main --single-branch --no-tags <UPSTREAM_URL> <MUGEN_UI_REPO_PATH>
2. Change into <MUGEN_UI_REPO_PATH>.
3. Rename the cloned remote to upstream:
   git remote rename origin upstream
4. Configure future upstream fetches to fetch only main and no tags:
   git config remote.upstream.tagOpt --no-tags
   git config --replace-all remote.upstream.fetch +refs/heads/main:refs/remotes/upstream/main
5. Disable pushes to upstream:
   git remote set-url --push upstream PUSH_DISABLED
6. Add the writable downstream origin:
   git remote add origin <ORIGIN_URL>
7. Configure future origin fetches to avoid automatic tag imports:
   git config remote.origin.tagOpt --no-tags
8. Push the cloned main baseline to origin/main and make local main track it:
   git push -u origin main
9. Create develop from the cloned upstream main baseline, push it to
   origin/develop, and make local develop track it:
   git checkout -b develop main
   git push -u origin develop
10. Set the downstream GitHub default branch to develop if gh is authenticated
   and authorized.
11. Do not fetch upstream develop, all upstream branches, or upstream tags.
12. Create downstream.toml from conf/downstream.toml.sample, then create
    downstream/README.md as a downstream-owned initialization artifact.
13. Run the workspace readiness checks below.
14. Commit downstream-owned initialization artifacts as
    chore(downstream): initialize ui provenance and push to origin/develop
    unless the user explicitly says not to commit.

Downstream provenance metadata:
- Create root downstream.toml from conf/downstream.toml.sample during
  downstream initialization unless the user explicitly opts out.
- Keep downstream.toml limited to downstream app metadata and upstream sync
  provenance. Do not store runtime settings, secrets, local paths,
  machine-specific values, or raw environment variable values.
- Record schema_version = 1.
- Record downstream app metadata, including app.slug = "<APP_SLUG>".
- Record upstream.repo or upstream.url from <UPSTREAM_URL>, upstream.branch =
  "main", and upstream.sync_ref as the exact cloned upstream/main commit.
- Record upstream.sync_tag only if that exact sync_ref corresponds to one
  upstream tag, checked with git ls-remote --tags <UPSTREAM_URL> without
  fetching tags locally.
- If no upstream tag resolves to sync_ref, omit upstream.sync_tag. If multiple
  upstream tags resolve to sync_ref, stop and ask which tag should be recorded.
- On later upstream syncs, update only upstream provenance fields unless the
  task explicitly changes downstream app metadata.
- Validate downstream.toml with a TOML parser and confirm it contains
  schema_version, [app].slug, and [upstream] sections before committing.

Downstream artifact layout:
- Create downstream/README.md during downstream initialization.
- Prefer downstream/ for downstream-owned deployment templates, operator docs,
  release notes, hosting notes, overlays, examples, and app-specific artifacts.
- Keep files in fixed tool locations only where required, such as GitHub
  Actions workflows under .github/workflows.
- Name fixed-location downstream files distinctly, for example
  .github/workflows/release-<APP_SLUG>.yml.

Branch and tag hygiene:
- The downstream UI app initialization path fetches upstream main only, with
  full history for that branch and no tags.
- Downstream UI apps must clone and update from upstream/main only because
  upstream releases are published to main.
- Do not fetch or import tags locally during clone/onboarding or downstream
  upstream sync.
- Do not manually run git fetch --tags, git pull --tags, or git push --tags
  during clone/onboarding.
- Inspect downstream origin tags only with git ls-remote --tags <ORIGIN_URL>
  when downstream tag information is needed.
- For downstream UI apps, inspect upstream tags only with:
  git ls-remote --tags <UPSTREAM_URL>
- If onboarding an existing checkout already has local tags, do not delete them
  unless the user explicitly asks. Report that local tags were already present.
- For downstream UI apps, fetch upstream/main only for upstream sync and fetch
  it directly with --no-tags.
- If main is fetched for release or upstream sync work later, add only the
  explicit main refspec needed for that task rather than broadening any remote
  to all branches.

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
- Run dart run tool/architecture/check_dependencies.dart after structural
  changes.

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
- Before describing or creating downstream release setup, require <APP_SLUG>.
  If missing, default it to the repository name portion of <GH_REPO>, then
  validate it uses lowercase letters, digits, and hyphens only.
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
  for downstream release setup.
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

GitHub Actions troubleshooting:
- Use gh with <GH_REPO> explicitly when inspecting workflow runs, checks, PRs,
  and annotations.
- If a PR check fails and the normal log is unclear, inspect check-run
  annotations through gh api repos/<GH_REPO>/check-runs/CHECK_RUN_ID/annotations.
- Use gh run view -R <GH_REPO> RUN_ID --job JOB_ID --log-failed for failing
  job logs.
- For Flutter failures, distinguish dependency resolution, analyzer,
  architecture validation, tests, coverage, and web release build failures in
  the report.
- If GitHub Actions status cannot be determined reliably, stop and report the
  exact gh commands needed to continue.

Workspace readiness checks:
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

Verification:
- Confirm the current directory is <MUGEN_UI_REPO_PATH>.
- Confirm git status --short is clean after clone/onboarding unless the user
  explicitly asked to preserve existing local changes.
- Confirm git branch --show-current reports develop.
- Confirm git rev-parse --abbrev-ref --symbolic-full-name @{u} reports
  origin/develop.
- Confirm upstream fetches <UPSTREAM_URL>, upstream push is PUSH_DISABLED,
  remote.upstream.tagOpt is --no-tags, and the upstream fetch refspec includes
  only refs/heads/main.
- Confirm remote.origin.tagOpt is --no-tags.
- Confirm origin points to <ORIGIN_URL> and local develop tracks
  origin/develop.
- Confirm downstream.toml exists and records upstream.branch = "main" plus the
  exact upstream.sync_ref used for initialization, unless the user explicitly
  opted out of downstream provenance metadata.
- Confirm downstream/README.md exists.
- Confirm git tag --list is empty after a fresh clone.
- Confirm the complete test suite passed.
- Confirm architecture dependency validation passed.
- Confirm line coverage is still 100%.
- Confirm the web release build passed.

Reporting requirements:
- Report whether the workspace was cloned fresh or an existing checkout was
  onboarded.
- Report origin URL, current branch, upstream tracking branch, and current
  short commit SHA.
- Summarize key command results for dependency install, analyze, architecture
  validation, tests, coverage, and build.
- If blocked, stop and report the blocker with next action options.
```
