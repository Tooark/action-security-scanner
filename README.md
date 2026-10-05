<!--
  Links to files in this repository are absolute on purpose: the GitHub
  Marketplace listing renders this README outside the repository, and absolute
  links resolve there too.

  Every section heading starts with an icon, and GitHub then starts its anchor
  with a hyphen: "## 🔧 Inputs" is #-inputs. Pick icons that are a single
  character; one that carries a variation selector (U+FE0F, as in the warning
  sign) leaves an invisible character in the anchor and breaks every link to it.
-->
<div align="left">
  <img src="https://raw.githubusercontent.com/Tooark/action-security-scanner/main/media/banner-ci-security-scanner.png" alt="CI Security Scanner" width="100%" />
</div>

# CI Security Scanner — GitHub Action

A GitHub Action that runs the Tooark
[`security-scanner`](https://github.com/Tooark/base-images/tree/main/security-scanner)
image — **Trivy** (vulnerabilities), **Hadolint** (Dockerfile lint) and
**Betterleaks** (secret detection) behind one `ark-tools` CLI, producing a
single `ark-report-tools v1.3` report.

One step gives a workflow the scan, the failure gates, a cached vulnerability
database and the reports as an artifact.

> **On GitLab?** The same scans, with the same input names, ship as GitLab
> CI/CD templates in
> [`Tooark/template-ci-security-scanner`](https://github.com/Tooark/template-ci-security-scanner).

New to CI pipelines? The
[onboarding guide](https://tooark.com/action-security-scanner/) walks through
every file in this repository and the reasoning behind each decision, written
for readers who know software development but not CI. Source in
[`docs/`](https://github.com/Tooark/action-security-scanner/tree/main/docs).

🌍 **Languages:** ![USA Flag](https://flagcdn.com/w20/us.png) **English (this file)** · [![Brazil Flag](https://flagcdn.com/w20/br.png) Português](https://github.com/Tooark/action-security-scanner/blob/main/README.pt-BR.md)

---

## 📑 Contents

- [🚀 Quick start](#-quick-start)
- [📋 Requirements](#-requirements)
- [🧰 Commands](#-commands)
- [🚦 Failure gates](#-failure-gates)
- [🔧 Inputs](#-inputs)
- [📤 Outputs](#-outputs)
- [📊 Reports](#-reports)
- [🔀 How precedence works](#-how-precedence-works)
- [🔑 Secrets](#-secrets)
- [🍳 Recipes](#-recipes)
- [💾 Trivy database cache](#-trivy-database-cache)
- [🐳 Which image wrote the report](#-which-image-wrote-the-report)
- [🔐 Security notes](#-security-notes)
- [🔖 Versioning](#-versioning)
- [📦 Publishing](#-publishing)
- [🚧 Gotchas](#-gotchas)
- [📁 Repository layout](#-repository-layout)
- [🧪 Development](#-development)
- [🔗 Related projects](#-related-projects)
- [🤝 Contributing](#-contributing)
- [🆘 Help & Security](#-help--security)
- [💖 Support](#-support)
- [📝 License](#-license)

---

## 🚀 Quick start

Scan the repository on every push and pull request:

```yaml
name: Security

on:
  push:
    branches: [main]
  pull_request:

permissions:
  contents: read

jobs:
  scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
        with:
          fetch-depth: 0 # Betterleaks needs the full git history

      - uses: Tooark/action-security-scanner@v1.3.0
```

With no inputs the Action runs `full-scan` without the image step: Trivy over
the source tree, Betterleaks over the git history and Hadolint over
`./Dockerfile`. The job fails when a [gate](#-failure-gates) trips, and the
reports are uploaded as the `security-reports` artifact either way.

To include the container image the job has just built:

```yaml
- run: docker build -t "myapp:${{ github.sha }}" .

- uses: Tooark/action-security-scanner@v1.3.0
  with:
    image: "myapp:${{ github.sha }}"
    docker-socket: "true" # only when the image was built on this runner
    trivy-severity: CRITICAL,HIGH
```

Complete workflows, ready to copy, live in
[`examples/`](https://github.com/Tooark/action-security-scanner/tree/main/examples):

| Example                                                                                                         | What it shows                                                                  |
| --------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------ |
| [`quick-start.yml`](https://github.com/Tooark/action-security-scanner/blob/main/examples/quick-start.yml)       | The workflow above                                                             |
| [`security-scan.yml`](https://github.com/Tooark/action-security-scanner/blob/main/examples/security-scan.yml)   | Fast checks on pull requests, full scan of the built image, a non-blocking job |
| [`registry-image.yml`](https://github.com/Tooark/action-security-scanner/blob/main/examples/registry-image.yml) | Scheduled scan of an image in a private registry, with an SBOM                 |
| [`code-scanning.yml`](https://github.com/Tooark/action-security-scanner/blob/main/examples/code-scanning.yml)   | Trivy findings as SARIF in the repository's Security tab                       |

---

## 📋 Requirements

| Requirement         | Detail                                                                                          |
| ------------------- | ----------------------------------------------------------------------------------------------- |
| Runner              | **Linux with Docker.** `ubuntu-latest` works as is; Windows and macOS runners are not supported |
| Checkout            | Run `actions/checkout` first — the Action scans the workspace, it does not clone it             |
| Git history         | `fetch-depth: 0` on the checkout for `secret-scan` and for the secrets step of `full-scan`      |
| Self-hosted runners | Actions Runner **2.327.1 or newer**                                                             |
| Network             | `ghcr.io` for the scanner image, and the Trivy vulnerability database (or a `trivy-server`)     |

The full support matrix is in
[`SUPPORTED-INTEGRATIONS.md`](https://github.com/Tooark/action-security-scanner/blob/main/SUPPORTED-INTEGRATIONS.md).

---

## 🧰 Commands

The `command` input selects the scan. Each one maps to the `ark-tools` command
of the same name inside the image.

| `command`         | Tool        | What it does                                                  | Main input         |
| ----------------- | ----------- | ------------------------------------------------------------- | ------------------ |
| `full-scan`       | all three   | Image + source + secrets + Dockerfile lint, one merged report | `image`, `path`    |
| `image-scan`      | Trivy       | Vulnerability scan of a container image                       | `image` (required) |
| `filesystem-scan` | Trivy       | Scan of the source tree (lockfiles, OS and language deps)     | `path`             |
| `config-scan`     | Trivy       | IaC / misconfiguration scan                                   | `path`             |
| `repo-scan`       | Trivy       | Repository scan; accepts a remote URL                         | `target`           |
| `dockerfile-lint` | Hadolint    | Lint of one Dockerfile                                        | `dockerfile`       |
| `secret-scan`     | Betterleaks | Secrets in the working tree and the git history               | `path`, `no-git`   |

`full-scan` is the default. Without an `image` it skips the image step; the
other steps can be turned off with `skip-lint` and `skip-secrets`.

---

## 🚦 Failure gates

A tripped gate fails the step, and with it the job.

| Tool        | Fails when                                                     | Turn it off with                        |
| ----------- | -------------------------------------------------------------- | --------------------------------------- |
| Trivy       | A severity in `trivy-severity-fail` is found, and it has a fix | `trivy-exit-code: "0"`                  |
| Hadolint    | A finding at `hadolint-failure-level` or above                 | `hadolint-failure-level: "none"`        |
| Betterleaks | Any secret is detected                                         | `betterleaks-fail-on-findings: "false"` |

The report and the gate are separate settings: `trivy-severity` decides what is
written to the report, `trivy-severity-fail` what fails the job. The same split
applies to `trivy-ignore-unfixed` and `trivy-ignore-unfixed-fail`.

`soft-fail: "true"` keeps every gate but stops it from failing the step: the
result is reported through the `exit-code` output instead, for the workflow to
branch on.

---

## 🔧 Inputs

Every input is optional except `image` for `image-scan`. Inputs are strings, so
booleans are written `"true"` / `"false"`.
[`action.yml`](https://github.com/Tooark/action-security-scanner/blob/main/action.yml)
is the authoritative reference.

### What to scan

| Input          | Default      | Used by                                                      | Notes                                                      |
| -------------- | ------------ | ------------------------------------------------------------ | ---------------------------------------------------------- |
| `command`      | `full-scan`  | —                                                            | The scan to run; see [Commands](#-commands)                |
| `image`        | —            | `full-scan`, `image-scan`                                    | Image reference. Empty skips the image step of `full-scan` |
| `path`         | `.`          | `full-scan`, `filesystem-scan`, `config-scan`, `secret-scan` | Directory to scan                                          |
| `target`       | workspace    | `repo-scan`                                                  | Local path or remote repository URL                        |
| `dockerfile`   | `Dockerfile` | `dockerfile-lint`                                            | The one Dockerfile to lint                                 |
| `dockerfiles`  | `Dockerfile` | `full-scan`                                                  | Comma-separated Dockerfiles, relative to `path`            |
| `scan-mode`    | `fs`         | `full-scan`                                                  | Trivy source scan mode: `fs` or `repo`                     |
| `skip-image`   | `false`      | `full-scan`                                                  | Skip the Trivy image step                                  |
| `skip-lint`    | `false`      | `full-scan`                                                  | Skip the Hadolint step                                     |
| `skip-secrets` | `false`      | `full-scan`                                                  | Skip the Betterleaks step                                  |
| `no-git`       | `false`      | `secret-scan`                                                | Scan only the working tree, not the git history            |
| `sbom`         | `false`      | `full-scan`, `image-scan`, `filesystem-scan`                 | Also generate an SBOM                                      |
| `sbom-format`  | `cyclonedx`  | same as `sbom`                                               | `cyclonedx` or `spdx-json`                                 |
| `extra-args`   | —            | all                                                          | Extra flags forwarded to the underlying tool after `--`    |

Paths are relative to the workspace; the Action rewrites them against the
container mount point.

### Scanner image

| Input             | Default                           | Notes                                                   |
| ----------------- | --------------------------------- | ------------------------------------------------------- |
| `scanner-image`   | `ghcr.io/tooark/security-scanner` | Change it to pull from a mirror                         |
| `scanner-version` | `1.10`                            | Image tag. Pin it; `latest` makes runs non-reproducible |

### Trivy

Used by every command except `dockerfile-lint` and `secret-scan`.

| Input                       | Image default                      | Notes                                                   |
| --------------------------- | ---------------------------------- | ------------------------------------------------------- |
| `trivy-severity`            | `UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL` | Severities written to the report                        |
| `trivy-severity-fail`       | `HIGH,CRITICAL`                    | Severities that trip the gate                           |
| `trivy-ignore-unfixed`      | `false`                            | Drop vulnerabilities without a fix from the report      |
| `trivy-ignore-unfixed-fail` | `true`                             | Gate only on vulnerabilities that have a fix            |
| `trivy-exit-code`           | `1`                                | `0` disables the Trivy gate                             |
| `trivy-format`              | `json`                             | `json`, `sarif`, `table`, `cyclonedx` or `spdx-json`    |
| `trivy-scanners`            | Trivy's own                        | E.g. `vuln,secret,misconfig,license`                    |
| `trivy-timeout`             | `10m`                              | E.g. `15m`                                              |
| `trivy-server`              | —                                  | Trivy server endpoint; pass `TRIVY_TOKEN` through `env` |
| `trivy-ignorefile`          | auto-detected                      | Path to a `.trivyignore` file                           |

### Hadolint

Used by `dockerfile-lint` and by the lint step of `full-scan`.

| Input                       | Image default | Notes                                                                |
| --------------------------- | ------------- | -------------------------------------------------------------------- |
| `hadolint-failure-level`    | `error`       | Lowest level that fails: `error`, `warning`, `info`, `style`, `none` |
| `hadolint-config`           | —             | Path to a `.hadolint.yaml` file                                      |
| `hadolint-format`           | `json`        | `json`, `tty` or `sarif`                                             |
| `hadolint-log-max-findings` | `20`          | Findings itemized in the log                                         |

### Betterleaks

Used by `secret-scan` and by the secrets step of `full-scan`.

| Input                          | Image default | Notes                                                        |
| ------------------------------ | ------------- | ------------------------------------------------------------ |
| `betterleaks-fail-on-findings` | `true`        | Fail when a secret is detected                               |
| `betterleaks-redact`           | `100`         | Percentage of each secret masked in the report (`0`–`100`)   |
| `betterleaks-baseline`         | —             | Path to a `betterleaks-baseline.json` with accepted findings |
| `betterleaks-config`           | —             | Path to a `.betterleaks.toml` file                           |
| `betterleaks-format`           | `json`        | `json`, `csv`, `junit`, `sarif` or `template`                |
| `betterleaks-log-max-findings` | `20`          | Findings itemized in the log                                 |

### Report webhook

| Input                  | Image default | Notes                                        |
| ---------------------- | ------------- | -------------------------------------------- |
| `report-url`           | —             | Comma-separated URLs the report is POSTed to |
| `report-fail-on-error` | `false`       | Fail the step when the upload fails          |

The bearer token is a secret: pass `REPORT_TOKEN` through `env`, see
[Secrets](#-secrets).

### Runner behaviour

| Input                     | Default            | Notes                                                                                |
| ------------------------- | ------------------ | ------------------------------------------------------------------------------------ |
| `reports-dir`             | `scan-reports`     | Where reports are written, relative to the workspace                                 |
| `upload-artifact`         | `true`             | Upload `reports-dir` as a workflow artifact, even when the scan fails                |
| `artifact-name`           | `security-reports` | Must be unique in the workflow run; see [Gotchas](#-gotchas)                         |
| `artifact-retention-days` | `7`                | Artifact retention                                                                   |
| `soft-fail`               | `false`            | Report the exit code as an output instead of failing the step                        |
| `docker-socket`           | `false`            | Mount `/var/run/docker.sock`; see [Security notes](#-security-notes)                 |
| `trivy-cache`             | `true`             | Cache the vulnerability database; see [Trivy database cache](#-trivy-database-cache) |

The tool inputs map one to one to the environment variables documented in the
[image README](https://github.com/Tooark/base-images/blob/main/security-scanner/README.md):
`trivy-severity` sets `TRIVY_SEVERITY`, `betterleaks-redact` sets
`BETTERLEAKS_REDACT`, and so on. A variable with no input of its own — say
`TRIVY_SKIP_DB_UPDATE` or `REPORT_METHOD` — is set as `env` on the step; see
[How precedence works](#-how-precedence-works).

---

## 📤 Outputs

| Output        | Value                                                                          |
| ------------- | ------------------------------------------------------------------------------ |
| `exit-code`   | Exit code of the scan. Non-zero means a gate tripped or the scan itself failed |
| `reports-dir` | Absolute path of the directory holding the reports                             |
| `report`      | Absolute path of the consolidated `full-scan` report                           |

```yaml
- id: scan
  uses: Tooark/action-security-scanner@v1.3.0
  with:
    soft-fail: "true"

- if: steps.scan.outputs.exit-code != '0'
  run: echo "::warning::the security scan found something"
```

---

## 📊 Reports

Everything lands in `reports-dir` and is uploaded as one artifact.

| Command           | Tool report                                                          | `ark-report-tools` envelope       |
| ----------------- | -------------------------------------------------------------------- | --------------------------------- |
| `full-scan`       | the files below, per step; the lint report is `hadolint-<file>.json` | `full-scan-report.json`           |
| `image-scan`      | `trivy-image.json`                                                   | `ark-report-image-scan.json`      |
| `filesystem-scan` | `trivy-filesystem.json`                                              | `ark-report-filesystem-scan.json` |
| `config-scan`     | `trivy-config.json`                                                  | `ark-report-config-scan.json`     |
| `repo-scan`       | `trivy-repo.json`                                                    | `ark-report-repo-scan.json`       |
| `dockerfile-lint` | `hadolint.json`                                                      | `ark-report-dockerfile-lint.json` |
| `secret-scan`     | `betterleaks.json`                                                   | `ark-report-secret-scan.json`     |

The envelope is the stable format: tool output wrapped with the scan target,
the repository, the commit and the scanner image that produced it. It is what
`report-url` receives. `sbom: "true"` adds `trivy-image.sbom.json` or
`trivy-filesystem.sbom.json`, and a `trivy-format` other than `json` adds a
converted copy next to the JSON report, such as `trivy-filesystem.sarif`.

---

## 🔀 How precedence works

Every tunable resolves in the same order:

```text
input  >  env of the job or step  >  image default
```

An **empty input is never forwarded**. That is deliberate: it lets a workflow
set `TRIVY_SEVERITY` once in a top-level `env:` and leave the matching input
blank in every job, rather than repeating it. Setting both means the input
wins.

The container does not inherit the runner's environment, so the Action passes
the middle tier on itself: every `TRIVY_*`, `HADOLINT_*`, `BETTERLEAKS_*`,
`SBOM_*`, `FULL_SCAN_*` and `REPORT_*` variable it finds in the step's
environment. Nothing else crosses over — not `GITHUB_TOKEN`, not a cloud
credential that happens to be set in the job.

```yaml
env:
  TRIVY_SEVERITY: CRITICAL,HIGH # every scan in this workflow

jobs:
  scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - uses: Tooark/action-security-scanner@v1.3.0
        with:
          command: filesystem-scan
```

---

## 🔑 Secrets

Input values show up in the workflow log, so secrets never travel as inputs.
Pass them as `env`, and they are forwarded to the container automatically:

`TRIVY_TOKEN`, `TRIVY_USERNAME`, `TRIVY_PASSWORD`, `REPORT_TOKEN`,
`REPORT_HEADERS`, `REPORT_SBOM_URL`, `REPORT_SBOM_TOKEN`.

They are handed to Docker by name, not by value, so a secret appears neither in
the command line of `docker run` nor in the log, which prints only the names of
the variables it took from the environment.

```yaml
- uses: Tooark/action-security-scanner@v1.3.0
  env:
    REPORT_TOKEN: ${{ secrets.REPORT_TOKEN }}
  with:
    report-url: https://security-hub.example.com/api/reports
```

Betterleaks redacts every secret in the report by default
(`betterleaks-redact: "100"`), and the job log prints only rule, file, line and
short commit — never the secret itself.

---

## 🍳 Recipes

**Scan an image from a private registry.** Trivy pulls the image itself, so the
Docker socket stays unmounted:

```yaml
- uses: Tooark/action-security-scanner@v1.3.0
  env:
    TRIVY_USERNAME: ${{ github.actor }}
    TRIVY_PASSWORD: ${{ secrets.GITHUB_TOKEN }}
  with:
    command: image-scan
    image: ghcr.io/my-org/my-app:latest
```

**Run more than one scan in a job.** Give each run its own `artifact-name`:

```yaml
- uses: Tooark/action-security-scanner@v1.3.0
  with:
    command: secret-scan
    artifact-name: secret-scan-reports

- uses: Tooark/action-security-scanner@v1.3.0
  with:
    command: dockerfile-lint
    dockerfile: docker/Dockerfile.worker
    artifact-name: dockerfile-lint-reports
```

**Accept a known finding.** Commit a `.trivyignore` at the repository root — it
is picked up automatically — or a Betterleaks baseline:

```yaml
- uses: Tooark/action-security-scanner@v1.3.0
  with:
    command: secret-scan
    betterleaks-baseline: .security/betterleaks-baseline.json
```

**Report without blocking.** `soft-fail: "true"` plus the `exit-code` output,
as shown under [Outputs](#-outputs).

**Show findings in the Security tab.** `trivy-format: sarif` plus
`github/codeql-action/upload-sarif`; the full workflow is in
[`examples/code-scanning.yml`](https://github.com/Tooark/action-security-scanner/blob/main/examples/code-scanning.yml).

---

## 💾 Trivy database cache

Downloading the vulnerability database on every build is the slowest part of a
scan and the easiest way to hit registry rate limits, so the Action caches it.
`dockerfile-lint` and `secret-scan` skip the cache entirely — Hadolint and
Betterleaks never read the database.

The database is kept in `RUNNER_TEMP`, which the job wipes on exit, so the
mount alone would only help across steps. `actions/cache` carries it between
runs with one entry per day per scanner version, falling back to the previous
day so Trivy refreshes an existing database rather than fetching a whole one.

The save is a separate `actions/cache/save` step rather than the automatic post
step, because the post step is skipped when an earlier step failed — and this
Action fails by design when a gate trips. Without the split, only repositories
that found nothing would ever populate the cache.

| Goal                     | How                                         |
| ------------------------ | ------------------------------------------- |
| Disable the cache        | `trivy-cache: "false"`                      |
| Reuse without refreshing | `TRIVY_SKIP_DB_UPDATE: "true"` as job `env` |

A cached database is still refreshed when Trivy considers it stale; the cache
saves the download, it does not freeze the data. `TRIVY_SKIP_DB_UPDATE` does
freeze it, which trades result accuracy for speed — the image forwards it to
Trivy, which reads the variable natively.

---

## 🐳 Which image wrote the report

The `ark-report-tools` envelope carries an `image` object naming the scanner
that produced the report. The image knows only its own build version, so the
Action passes the rest: `ARK_IMAGE_NAME` and `ARK_IMAGE_TAG` come from
`scanner-image` and `scanner-version`, so a mirror or a floating tag is
recorded as it ran. The Action also resolves the digest of the image it runs
and passes `ARK_IMAGE_DIGEST`, which makes `image.reference` an immutable
`name@sha256:…`. Setting any of the three as job `env` overrides it.

---

## 🔐 Security notes

Four things are worth knowing before you wire this into a workflow that holds
credentials.

**`docker-socket: "true"` hands the container root on the runner.** The Docker
socket is an unrestricted control plane for the daemon, so anything inside the
container can start a privileged container and read the host. It is off by
default and only needed to scan an image built earlier in the same job — an
image already pushed to a registry does not need it. On a shared self-hosted
runner, prefer pushing to a registry and scanning from there.

**Reports can contain the secrets they found.** Two settings turn an artifact
into a disclosure: `betterleaks-redact: "0"` writes detected secrets in
cleartext, and adding `secret` to `trivy-scanners` puts Trivy's findings in the
report. Artifacts are downloadable by everyone with read access to the
repository, so leave redaction at its default unless the artifact destination
is as restricted as the secrets themselves.

**Floating tags are mutable by design.** Each release force-moves `v1` and
`v1.0`, so pinning either means code you have not reviewed runs in your
workflow after the next release. `v1.0.0` is never moved, but a tag can in
principle be rewritten by anyone with push access; a commit SHA is the only
fully immutable reference:

```yaml
- uses: Tooark/action-security-scanner@<commit-sha> # v1.0.0
```

**The reports directory is briefly world-writable.** The image drops to uid
1000, which is not the runner user, so the directory is opened up for the
duration of the scan and tightened again afterwards. On ephemeral runners this
is immaterial; on a self-hosted runner with concurrent jobs, another job could
write into it during the scan.

### What was checked

`eval` appears in `src/run-scanner.sh`, but only ever iterates a hardcoded list
of variable names — no input reaches it. Word splitting of `extra-args` is
deliberate and runs under `set -f`, so a value like `*` cannot expand against
repository files. Only variables under the image's own prefixes leave the job
environment for the container, by name. Workflow expressions reach `run:`
blocks through `env:` rather than string interpolation. Workflow tokens are
scoped: `contents: read` for CI, `contents: write` only for the release job.
The third-party `actionlint` image is pinned by digest, and Dependabot tracks
the rest. `tests/run-scanner.test.sh` asserts most of this on every commit.

---

## 🔖 Versioning

Releases are tagged `vMAJOR.MINOR.PATCH`. Each release also moves two floating
tags so consumers can track a line without editing workflows on every patch:

| Reference | Resolves to                    | Use when                           |
| --------- | ------------------------------ | ---------------------------------- |
| `v1.0.0`  | Exactly that release           | Reproducible workflows             |
| `v1.0`    | Newest patch of 1.0            | Automatic patch updates            |
| `v1`      | Newest release of the 1.x line | Automatic minor and patch updates  |
| `main`    | Unreleased work                | Never in a workflow you care about |

Dependabot keeps a pinned tag or SHA current: add the `github-actions`
ecosystem to `.github/dependabot.yml` in the consuming repository.

[`VERSION`](https://github.com/Tooark/action-security-scanner/blob/main/VERSION)
is the single source of truth for both the Action version and the scanner image
tag it pins. `scripts/check-sync.sh` fails CI if any of them drift, and the
release workflow refuses a tag that disagrees with `COMPONENT_VERSION`.

Bumping the scanner image is therefore a three-line change: edit `VERSION`,
run `./scripts/check-sync.sh`, update the pins it flags.

---

## 📦 Publishing

### GitHub Releases

Push a `v*.*.*` tag. [`.github/workflows/release.yml`](https://github.com/Tooark/action-security-scanner/blob/main/.github/workflows/release.yml)
runs the checks, compares the tag against `VERSION`, creates the release with
generated notes and moves the floating tags.

### GitHub Marketplace

The Action is listed as
[Tooark Security Scanner](https://github.com/marketplace/actions/tooark-security-scanner).
Listing a release is a manual opt-in that the API cannot set: open the release
on GitHub and tick **Publish this Action to the GitHub Marketplace**.

---

## 🚧 Gotchas

**`fetch-depth: 0` matters for secret scanning.** Betterleaks walks the git
history. With the default `fetch-depth: 1` of `actions/checkout` it silently
sees almost nothing.

**Scanning an image built in the same job needs the socket.** Trivy looks the
image up in the local daemon, which the container cannot reach without
`docker-socket: "true"`. Images already pushed to a registry do not need it.

**Artifact names must be unique in a workflow run.** Every run of the Action
uploads `reports-dir` under `artifact-name`, and a second upload with the same
name fails. Set `artifact-name` on each step when the Action runs more than
once, in one job or across jobs — or `upload-artifact: "false"` on all but the
last step of a job, since they share the reports directory.

**File ownership.** The image drops to the non-root `app` user (uid 1000),
which is not the runner user. The Action creates the reports directory
world-writable and hands ownership back afterwards, and declares the workspace
as a git safe directory. Custom `reports-dir` values inherit this.

**Dockerfile lint handles one file per step.** Use `full-scan` with
`dockerfiles: "a,b,c"`, or run `dockerfile-lint` once per file.

**Pull requests from forks get no secrets.** A `REPORT_TOKEN` or registry
password is empty there, so a scan that needs one fails or skips the upload.
Scan the source tree on `pull_request` and keep the steps that need secrets
for `push`.

---

## 📁 Repository layout

```text
action.yml                  The composite Action: inputs, outputs, steps
src/run-scanner.sh          Translates the inputs into a docker run of the image
examples/                   Ready-to-copy workflows
scripts/                    Checks run in CI and locally
tests/                      Tests of the runner script, no Docker needed
docs/                       Onboarding guide, published to GitHub Pages
SUPPORTED-INTEGRATIONS.md   Runners and versions supported
VERSION                     Single source of truth for versions
```

---

## 🧪 Development

```bash
python3 -m pip install pyyaml

./scripts/check-sync.sh               # version pins, input wiring, docs
python3 scripts/check-examples.py     # examples and README snippets match action.yml
./tests/run-scanner.test.sh           # the docker run the Action builds, without Docker
shellcheck -s bash src/run-scanner.sh scripts/*.sh tests/*.sh
```

CI runs all four, plus `actionlint`, plus a self-scan in which the Action in
this repository scans this repository.

When adding an input, touch all four places or `check-sync.sh` will say so:
the `inputs:` block of `action.yml`, the `env:` of its scan step as
`ARK_IN_*`, `src/run-scanner.sh`, and the tables in both READMEs.
[`CONTRIBUTING.md`](https://github.com/Tooark/action-security-scanner/blob/main/CONTRIBUTING.md)
has the details.

---

## 🔗 Related projects

| Project                                                                                         | What it is                                                      |
| ----------------------------------------------------------------------------------------------- | --------------------------------------------------------------- |
| [`Tooark/template-ci-security-scanner`](https://github.com/Tooark/template-ci-security-scanner) | The same scans as GitLab CI/CD templates                        |
| [`Tooark/base-images`](https://github.com/Tooark/base-images/tree/main/security-scanner)        | The `security-scanner` image: the tools and the `ark-tools` CLI |

---

## 🤝 Contributing

Contributions are welcome! Start with
[CONTRIBUTING.md](https://github.com/Tooark/action-security-scanner/blob/main/CONTRIBUTING.md)
— it covers what belongs here and what belongs in the scanner image, the
development workflow, how to add an input, the commit convention and the
release process.

Quick notes:

- Run the four checks under [Development](#-development) before opening a PR
- A new input lands in four places, or `check-sync.sh` fails the build
- Keep `README.md` and `README.pt-BR.md` in sync
- Commits follow [Conventional Commits](https://www.conventionalcommits.org/)
- Record anything a consumer will notice in `CHANGELOG.md`, under `[Unreleased]`

By participating you agree to the [Code of Conduct](https://github.com/Tooark/action-security-scanner/blob/main/CODE_OF_CONDUCT.md).

---

## 🆘 Help & Security

- ❓ **Questions, bugs, feature ideas** — see [SUPPORT.md](https://github.com/Tooark/action-security-scanner/blob/main/SUPPORT.md) for the right channel
- 🔒 **Security vulnerabilities** — do **not** open a public issue; follow [SECURITY.md](https://github.com/Tooark/action-security-scanner/blob/main/SECURITY.md)
- 🐳 **A problem inside the scanner itself** — Trivy, Hadolint, Betterleaks and `ark-tools` live in [`Tooark/base-images`](https://github.com/Tooark/base-images/tree/main/security-scanner)

---

## 💖 Support

If this Action helps your pipelines, consider supporting its development:

- 💙 [GitHub Sponsors](https://github.com/sponsors/paulosfjunior)
- ☕ [Ko-fi](https://ko-fi.com/paulosfjunior)

Every contribution helps keep the project maintained and improving. Thank you! 🙏

---

## 📝 License

This project is licensed under the [MIT License](https://github.com/Tooark/action-security-scanner/blob/main/LICENSE).
