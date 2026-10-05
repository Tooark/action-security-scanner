# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.3.0] - 2026-10-05

The repository has a new name, `Tooark/action-security-scanner`, and a single
job: the GitHub Action. The GitLab CI/CD templates moved to
[`Tooark/template-ci-security-scanner`](https://github.com/Tooark/template-ci-security-scanner).
**Every workflow has to change its `uses:` line** — see the first entry under
_Changed_.

### Added

- Three more copy-ready workflows in `examples/`: `quick-start.yml`, the
  smallest useful setup; `registry-image.yml`, a scheduled scan of an image in
  a private registry; and `code-scanning.yml`, which uploads Trivy findings as
  SARIF to the repository's Security tab.
- `tests/run-scanner.test.sh` tests `src/run-scanner.sh` without Docker: a
  stand-in `docker` records the command line the script builds, and some fifty
  assertions cover precedence, what is forwarded and what never is, path
  rewriting, soft-fail and the outputs. CI runs it on every commit.
- `scripts/check-examples.py` checks every step that calls the Action, in
  `examples/` and in the YAML blocks of both READMEs, against `action.yml`: an
  undeclared input, an undeclared output or an unknown `command` fails CI.
  GitHub itself only warns about an undeclared input, and then ignores it.
- `scripts/check-sync.sh` now also fails when an input is declared but read by
  no step, when `src/run-scanner.sh` reads an `ARK_IN_*` the Action never
  stages, when an input is missing from either README, and when the
  `scanner-version` row of a README or the current line of
  `SUPPORTED-INTEGRATIONS.md` names an image tag other than the one in
  `VERSION`.
- Contributing, Help & Security and Support sections at the end of both
  READMEs.

### Changed

- **The repository is renamed to `Tooark/action-security-scanner`.** It was
  `Tooark/ci-security-scanner`. GitHub does not redirect `uses:` for a renamed
  action repository, so **every workflow has to change its reference**, whatever
  it pins:

  ```yaml
  - uses: Tooark/action-security-scanner@v1.3.0 # was Tooark/ci-security-scanner@…
  ```

  Tags and releases carried over, so `@v1.2.0`, `@v1.1.0` and `@v1` resolve
  under the new name too. The onboarding guide moved with the repository, to
  <https://tooark.com/action-security-scanner/>. The log prefix and the file
  headers follow the name: `[action-security-scanner]`.

- The README is the complete reference for the Action: every input with its
  default, the outputs, the report files each scan writes, and recipes. It no
  longer defers to the templates' `spec:inputs`. Every section heading carries
  an icon, which changes the anchor of the section: it now starts with a
  hyphen, `#-inputs` where it was `#inputs`.
- `SUPPORTED-INTEGRATIONS.md`, `CONTRIBUTING.md`, `SECURITY.md`, `SUPPORT.md`
  and the issue and pull request templates describe the Action only, and send
  GitLab questions to the sister repository.
- The example workflow moved from `examples/github/security-scan.yml` to
  `examples/security-scan.yml`, and its advisory job sets its own
  `artifact-name`.
- The onboarding guide covers the Action only. The GitLab section is gone, the
  walkthrough of `src/run-scanner.sh` follows the script as it is now, and the
  page closes with a card pointing at the sibling guide of the GitLab
  templates. Its accent colour moved from teal to GitHub's green: each guide
  takes the colour of its platform, and the green no longer sits next to
  Trivy's teal on the gate cards.

### Removed

- **The GitLab CI/CD templates**, together with `scripts/validate-templates.py`,
  the GitLab examples and the CI/CD Catalog mirror pipeline. They moved to
  [`Tooark/template-ci-security-scanner`](https://github.com/Tooark/template-ci-security-scanner),
  which continues from the same history and the same tags. If you consume the
  templates from here:
  - a remote include must point at
    `https://raw.githubusercontent.com/Tooark/template-ci-security-scanner/<tag>/templates/<scan>.yml`.
    One that still names `Tooark/ci-security-scanner` resolves only for as
    long as GitHub redirects the old name, and only for tags up to `v1.2.0`,
    the last to carry `templates/`;
  - a catalog mirror set up from `examples/gitlab-catalog-mirror/` fails its
    `sync` job with `upstream release is missing templates` from this release
    on. Set `UPSTREAM_REPO` to `Tooark/template-ci-security-scanner`, in the
    mirror's `.gitlab-ci.yml` or as a project CI/CD variable.

### Fixed

- **A variable set with `env:` now reaches the scanner.** The documented
  precedence is `input > workflow env > image default`, but `docker run` starts
  the container with an empty environment and only inputs and seven named
  secrets were passed on. A workflow that set `TRIVY_SEVERITY` once in a
  top-level `env:` and left the input blank got the image default instead, and
  `TRIVY_SKIP_DB_UPDATE` — which the README told people to set as job `env` —
  never took effect. The Action now passes on every `TRIVY_*`, `HADOLINT_*`,
  `BETTERLEAKS_*`, `SBOM_*`, `FULL_SCAN_*` and `REPORT_*` variable found in the
  step's environment whose input is blank. An input still wins, and
  `REPORT_DIR`, `TRIVY_CACHE_DIR` and `FULL_SCAN_PATH` stay under the Action's
  control because they are container paths. **Check your workflows for
  variables under those prefixes that were being ignored until now** — they
  start to apply with this release.
- The diagram of a run in the onboarding guide no longer lets text out of its
  boxes. It was an SVG with fixed-width boxes: the label under it was cut off
  at the right edge on the published page, and opening `docs/index.html`
  without rendering it pushed the version placeholder out of the first box. It
  is now HTML, so text wraps inside each card, and the cards stack on a narrow
  screen instead of scrolling sideways.

### Security

- Secrets are handed to Docker by name (`-e REPORT_TOKEN`) instead of by value
  (`-e REPORT_TOKEN=…`), so they no longer appear in the command line of
  `docker run`, where another process on a shared runner could read them.

## [1.2.0] - 2026-09-27

### Added

- The onboarding guide is bilingual. A language button beside the theme button
  switches between Portuguese and English without reloading the page. Both
  languages live in the same file, side by side, so they cannot drift apart the
  way two separate files can; the choice is remembered per visitor, and a
  first-time visitor gets whichever language their browser asks for. Without
  JavaScript the page still renders, in Portuguese.
- The guide links out: a GitHub button beside the language and theme buttons
  and the repository badge open the repository, the version badge opens that
  version's release, and the scanner badge opens the `Tooark/base-images`
  release of the image it pins.

### Changed

- The onboarding guide no longer carries versions of its own. It writes
  placeholders, and `scripts/render-docs.sh` fills them in from `VERSION` —
  which now also declares `REPORT_SCHEMA` and `REPORT_VERSION` — before Pages
  publishes the page. Pages now also redeploys when only `VERSION` changes.
  `check-sync.sh` reads the rendered page, fails on a version typed into the
  guide by hand, and checks that every live mention of the report envelope
  names `REPORT_VERSION`.

- Scanner image bumped to `ghcr.io/tooark/security-scanner:1.10`, the new
  default of `scanner_version` / `scanner-version`. Its reports use the
  `ark-report-tools` envelope v1.3, which adds an optional `image` object —
  `name`, `version`, `tag`, `digest` and `reference` of the scanner image that
  produced the report — and sets `version` to `"1.3"`. A collector behind
  `report_url` / `report-url` that only accepts the literal `"1.2"` must be
  updated; reports without `image` still validate against the new schema.
  Released as a minor because the image moved a minor: the scanner default
  follows the image's own versioning (see `CONTRIBUTING.md`).
- Reports say which image produced them. The image knows only its own build
  version, so both front ends pass `ARK_IMAGE_NAME` and `ARK_IMAGE_TAG` from
  `scanner_image` / `scanner-image` and `scanner_version` / `scanner-version`:
  a mirror or the floating `1.10` tag is recorded as it ran, not as
  `ghcr.io/tooark/security-scanner:1.10.0`. The Action also resolves the
  digest of the image it runs and passes `ARK_IMAGE_DIGEST`, so
  `image.reference` becomes an immutable `name@sha256:…`. GitLab exposes no
  digest for a job image; a project that wants one sets `ARK_IMAGE_DIGEST` as
  a CI/CD variable. A CI/CD variable, or the job `env` on GitHub, overrides all
  three.

### Fixed

- The onboarding guide no longer serves `uses: Tooark/ci-security-scanner@v1.1.0`
  as `[email protected]`. Cloudflare proxies `tooark.com` and its Email Address
  Obfuscation rewrites anything shaped like an address; `name@vX.Y.Z` qualifies.
  The affected spans now carry Cloudflare's `email_off` opt-out.
- The `[1.0.0]` and `[1.1.0]` links at the bottom of this file pointed at a
  `v1.0.0` tag that was never pushed, so both 404'd.
- The guide's JavaScript moved out of the page and into `docs/guide.js`. The
  site is served behind a Content Security Policy of `script-src 'self'`, which
  blocks inline `<script>` outright — so the theme toggle, the language toggle
  and the nav highlight were all dead on the published page while working
  locally. The button labels moved into `data-` attributes on the buttons, so
  the script file now carries no translated text at all.
- The guide serves its own favicon. The link pointed at `../media/favicon.png`,
  which resolves above the published root — `docs/` is the site root — and only
  appeared to work because the organization's site happens to serve an
  identical file at that path. It also declared `image/x-icon` for a PNG.
- The Portuguese half of the guide had fallen behind the English one. It still
  showed `v1.0.0` in both tag tables, `actions/cache/restore@v4` and
  `actions/checkout@v4`, and it listed three `check-sync.sh` invariants where
  there are four. Both halves said the scanner version is pinned in ten places;
  it is nine, since `run-scanner.sh` has a single version fallback. On narrow
  phones the header buttons no longer overlap the eyebrow line.
- The catalog mirror's `sync` job could not push. GitLab Runner rewrites the
  bare project URL to one carrying `CI_JOB_TOKEN`
  (`url.<with token>.insteadOf <without>`), so the push went out with the
  read-only job token instead of `CATALOG_PUSH_TOKEN` and failed with
  `You are not allowed to push code to this project`. The push URL now carries
  a user part (`https://oauth2@…`), which that prefix match no longer rewrites,
  and every push resets `credential.helper` first, so a job-token helper the
  runner installs under `FF_GIT_URLS_WITHOUT_TOKENS` cannot answer instead.
- The mirror's push to the default branch carries `-o ci.skip`. Without it the
  push started a branch pipeline whose own `sync` job raced the tag push, and
  failed trying to create the same tag whenever it won.
- The README reaches the catalog mirror without `media/`, `docs/`, `examples/`,
  `action.yml` or the other language's README, so on the catalog page the
  banner and those links were broken. Links to files the mirror does not sync
  are now absolute; `templates/`, `LICENSE` and `VERSION` stay relative.
- The mirror's troubleshooting table blamed branch protection for the 403 that
  was really the runner's job token, and listed a missing description as a
  cause of an empty catalog, when it actually fails the release job with
  `Project must have a description`. It now covers both, and how to publish a
  release that was created while the **CI/CD Catalog project** toggle was off.

### Security

- The mirror pipeline pins its images by digest: `alpine:3.24.2` for `sync`,
  which holds `CATALOG_PUSH_TOKEN` (3.20 reached end of support on
  2026-04-01), and `glab` v1.119.0 for `release` instead of the mutable
  `latest`. The mirror's README notes that the `glab` path needs GitLab 18.0 or
  later.

## [1.1.0] - 2026-09-22

### Added

- Onboarding guide in `docs/`, deployed to GitHub Pages by
  `.github/workflows/pages.yml`. It walks the repository file by file and
  records the reasoning behind each decision, for readers who know software
  development but not CI.
- OSS governance files modelled on `Tooark/base-images`: `SECURITY.md`,
  `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `SUPPORT.md`, `.github/CODEOWNERS`,
  `.github/FUNDING.yml`, a pull request template and issue forms.
- `SUPPORTED-INTEGRATIONS.md`, recording the support boundaries previously
  scattered across header comments and README gotchas: supported platforms,
  runners and executors, the component-to-image version pairing, and the
  network destinations a scan needs.
- `scripts/check-sync.sh` now also verifies that every copy-paste reference in
  the README, the examples, the onboarding guide and
  `SUPPORTED-INTEGRATIONS.md` pins `COMPONENT_VERSION`. Only the three forms a
  reader actually copies are matched; prose explaining the tagging scheme is
  not. Without it, a release silently left the quick start teaching the
  previous version.

### Changed

- **Minimum Actions Runner version on self-hosted runners.** `action.yml` now
  references `actions/upload-artifact@v7` and `actions/cache@v6`, which run on
  Node.js 24 and require Actions Runner **2.327.1 or newer** — the floor
  introduced by `actions/upload-artifact@v6`. GitHub-hosted runners are
  unaffected. A self-hosted runner older than that will fail the artifact
  upload and the cache steps once `v1` or `v1.0` moves to a release containing
  this change.
- This repository's own workflows moved to `actions/checkout@v7`,
  `actions/configure-pages@v6` and `actions/deploy-pages@v5`. No consumer
  impact; the runners had started warning that Node 20 is deprecated.
- The GitHub example in `examples/` moved to `actions/checkout@v7`, so a reader
  copying it does not start on a version the runner already warns about.

### Fixed

- `scripts/check-sync.sh` no longer trips ShellCheck `SC2013`, which failed the
  CI lint step on every commit and blocked every Dependabot pull request. The
  `ARK_IN_*` parity check now reads names with `while read` fed by process
  substitution, which keeps the loop in the current shell so the failure flag
  survives it.
- The onboarding guide is linked by its canonical address,
  `https://tooark.com/ci-security-scanner/`. The `tooark.github.io` URL used
  until now is a redirect: the organization serves Pages from a custom domain.

## [1.0.0] - 2026-09-21

First release. Pins `ghcr.io/tooark/security-scanner:1.9`. Never published as
a tag — this content first reached consumers as part of 1.1.0.

### Added

- GitLab CI/CD component templates, one job each: `full-scan`, `image-scan`,
  `filesystem-scan`, `config-scan`, `repo-scan`, `dockerfile-lint` and
  `secret-scan`. Usable through `include: remote:` or from a CI/CD Catalog.
- GitHub composite Action (`action.yml`) covering the same seven scans through
  a `command` input, with `exit-code`, `reports-dir` and `report` outputs.
- Shared precedence rule across both platforms: an empty input is never
  forwarded, so `input > CI variable > image default` holds everywhere.
- Secret passthrough (`TRIVY_TOKEN`, `REPORT_TOKEN`, registry credentials and
  friends) via environment rather than inputs.
- Trivy database caching on both platforms, skipped for the two scans that do
  not read the database. GitLab caches `.cache/trivy` under a fixed key; GitHub
  uses `actions/cache` with one entry per day per scanner version, saved from
  an explicit step so a tripped failure gate still populates it.
- `scripts/validate-templates.py` and `scripts/check-sync.sh`, which fail CI on
  undeclared or unused inputs, broken `ARK_IN_*` wiring, and version pins that
  drift from `VERSION`.
- Release workflow that validates, checks the tag against `VERSION`, publishes
  the GitHub release and moves the floating `vMAJOR` and `vMAJOR.MINOR` tags.
- Mirror pipeline in `examples/gitlab-catalog-mirror/` that polls GitHub
  releases on a schedule and republishes to a self-hosted CI/CD Catalog.
- Copy-ready examples for both platforms in `examples/`.

### Security

- `extra_args` is split under `set -f`, so a value such as `*` is passed
  literally instead of expanding against the files in the repository.
- The catalog mirror hands its push token to git through a credential helper
  rather than a remote URL, keeping it out of argv and out of git's errors.
- The third-party `actionlint` image is pinned by digest, and Dependabot keeps
  the remaining action references current.
- The reports directory is tightened again once a scan finishes, limiting the
  world-writable window the non-root container user requires.
- Documented the disclosure paths that configuration can open: the Docker
  socket mount, unredacted Betterleaks output, and Trivy's secret scanner
  writing findings into an uploaded artifact.

[Unreleased]: https://github.com/Tooark/action-security-scanner/compare/v1.3.0...HEAD
[1.3.0]: https://github.com/Tooark/action-security-scanner/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/Tooark/action-security-scanner/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/Tooark/action-security-scanner/releases/tag/v1.1.0
[1.0.0]: https://github.com/Tooark/action-security-scanner/commit/56263b1c4c085d5ce785ed263194c04609b8f0be
