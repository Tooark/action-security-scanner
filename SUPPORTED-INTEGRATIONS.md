# Supported integrations

What this Action is tested and supported on, and where the boundaries are.

Anything not listed here may still work — it is simply not something a bug
report can be held against. When in doubt, open an issue with the environment
filled in; the `bug` template asks for exactly the fields this page indexes.

🌍 Companion pages: [README.md](README.md) · [SUPPORT.md](SUPPORT.md) ·
[CONTRIBUTING.md](CONTRIBUTING.md)

---

## Platforms

| Platform                               | How it is consumed                                                                              | Status            |
| -------------------------------------- | ----------------------------------------------------------------------------------------------- | ----------------- |
| **GitHub Actions** — github.com        | `uses: Tooark/action-security-scanner@v1.3.0`                                                   | ✅ Supported      |
| **Direct invocation**                  | `src/run-scanner.sh` with `ARK_*` variables                                                     | ⚠️ Best effort    |
| **GitLab CI**                          | [`Tooark/template-ci-security-scanner`](https://github.com/Tooark/template-ci-security-scanner) | ➡️ Sister project |
| Jenkins, Azure DevOps, CircleCI, Drone | —                                                                                               | ❌ Not covered    |

The Action is a packaging layer. On an unsupported CI system you can still run
the underlying image directly — that is
[`Tooark/base-images`](https://github.com/Tooark/base-images/tree/main/security-scanner)
territory, not this repository's.

---

## Runners

| Requirement                   | Supported                                                                                |
| ----------------------------- | ---------------------------------------------------------------------------------------- |
| Operating system              | **Linux only**                                                                           |
| Container runtime             | Docker CLI and daemon on the runner                                                      |
| Label                         | `ubuntu-latest`, a pinned `ubuntu-*`, or a Linux self-hosted runner                      |
| Architecture                  | Whatever the scanner image is published for: `amd64` and `arm64`                         |
| Windows / macOS               | ❌ Not supported                                                                         |
| Job running in a `container:` | ⚠️ Untested — the workspace path seen by the job is not the one the Docker daemon mounts |

**Why Linux and Docker.** The Action does not run the tools itself — it runs
`docker run ghcr.io/tooark/security-scanner:<tag>`. Without a working Docker
daemon on the runner there is nothing to execute.

### Minimum Actions Runner version

**Actions Runner 2.327.1 or newer** on self-hosted runners. GitHub-hosted
runners always satisfy this.

The floor comes from the `actions/*` versions that [`action.yml`](action.yml)
references, not from this Action directly: `actions/upload-artifact@v7` and
`actions/cache@v6` run on Node.js 24, and v6 of the artifact action introduced
the 2.327.1 requirement. An older self-hosted runner fails the artifact upload
and the cache steps.

Any dependency bump that raises this floor is recorded in
[`CHANGELOG.md`](CHANGELOG.md) as a consumer-visible change — check it before
moving a floating tag on a fleet of self-hosted runners.

---

## Scans

All seven scans are selected through the `command` input.

| `command`         | Tool        |
| ----------------- | ----------- |
| `full-scan`       | all three   |
| `image-scan`      | Trivy       |
| `filesystem-scan` | Trivy       |
| `config-scan`     | Trivy       |
| `repo-scan`       | Trivy       |
| `dockerfile-lint` | Hadolint    |
| `secret-scan`     | Betterleaks |

### Scan-specific requirements

| Scan                                           | Requires                                                                            |
| ---------------------------------------------- | ----------------------------------------------------------------------------------- |
| `secret-scan`, and `full-scan` secrets         | Full git history — `fetch-depth: 0` on `actions/checkout`                           |
| `image-scan` of an image built in the same job | `docker-socket: "true"`                                                             |
| `image-scan` of an image in a registry         | Network reach, plus `TRIVY_USERNAME` / `TRIVY_PASSWORD` as `env` when it is private |
| `dockerfile-lint`                              | One Dockerfile per step — use `full-scan` with `dockerfiles:` for several           |
| Any Trivy scan                                 | Network reach to the vulnerability database, or a `trivy-server`                    |

A shallow clone is the trap worth repeating: Betterleaks walks the history, and
with the default shallow clone it sees almost nothing **and does not complain**.

---

## Versions

| Action version      | Scanner image                          | Status     |
| ------------------- | -------------------------------------- | ---------- |
| `1.3.x`             | `ghcr.io/tooark/security-scanner:1.10` | Current    |
| `1.2.x`             | `ghcr.io/tooark/security-scanner:1.10` | Superseded |
| `1.0.x` and `1.1.x` | `ghcr.io/tooark/security-scanner:1.9`  | Superseded |

[`VERSION`](VERSION) is the single source of truth for this pairing, and
`scripts/check-sync.sh` fails CI when the Action drifts from it. Overriding
`scanner-version` to a tag this table does not list is allowed and occasionally
useful, but it is unsupported: the inputs are written against the variables a
specific image reads.

Releases up to `1.2.x` were published under the repository's previous name,
`Tooark/ci-security-scanner`, and also carried the GitLab CI/CD templates.
Those moved to
[`Tooark/template-ci-security-scanner`](https://github.com/Tooark/template-ci-security-scanner),
which continues from the same history and the same tags.

### Reference tags

| Reference | Resolves to                    | Mutable            |
| --------- | ------------------------------ | ------------------ |
| `v1.0.0`  | Exactly that release           | No                 |
| `v1.0`    | Newest patch of 1.0            | Yes                |
| `v1`      | Newest release of the 1.x line | Yes                |
| `main`    | Unreleased work                | Yes — never pin it |

---

## Network

| Destination                          | Needed for                          | Avoidable with                                              |
| ------------------------------------ | ----------------------------------- | ----------------------------------------------------------- |
| `ghcr.io`                            | Pulling the scanner image           | A mirror, via `scanner-image`                               |
| Trivy vulnerability database         | Every Trivy scan                    | `trivy-server`, or `TRIVY_SKIP_DB_UPDATE` with a warm cache |
| GitHub's cache and artifact services | `trivy-cache` and `upload-artifact` | `trivy-cache: "false"` / `upload-artifact: "false"`         |

Fully air-gapped runners are not a supported configuration today. The pieces
exist — a mirrored image, a Trivy server — but the combination is untested.

---

## Reports and formats

Report formats, SBOM formats and the consolidated `ark-report-tools` envelope
are produced by the image, not by this Action. The Action forwards the format
inputs, tells the image the name, tag and digest it ran under, which fill the
envelope's `image` object, and uploads whatever lands in the reports directory.

The supported values of `trivy-format`, `hadolint-format`,
`betterleaks-format` and `sbom-format` are listed in the
[README](README.md#-inputs), which mirrors the
[image README](https://github.com/Tooark/base-images/blob/main/security-scanner/README.md).

---

## Not supported

- Windows and macOS runners
- CI systems other than GitHub Actions — GitLab CI has its
  [own project](https://github.com/Tooark/template-ci-security-scanner)
- Container runtimes other than Docker (Podman is untested)
- Fully air-gapped installations
- Scanner image tags outside the pairing table above
- `main` as a pinned reference
