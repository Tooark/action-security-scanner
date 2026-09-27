# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/Tooark/ci-security-scanner/compare/v1.2.0...HEAD
[1.2.0]: https://github.com/Tooark/ci-security-scanner/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/Tooark/ci-security-scanner/releases/tag/v1.1.0
[1.0.0]: https://github.com/Tooark/ci-security-scanner/commit/56263b1c4c085d5ce785ed263194c04609b8f0be
