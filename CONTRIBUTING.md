# Contributing to action-security-scanner

First off, thank you for considering contributing to
**Tooark action-security-scanner**! 🎉

This repository publishes one thing: the GitHub Action that runs the Tooark
`security-scanner` image. What it promises a consumer is that every documented
input does what the documentation says — which is the constraint that shapes
almost every rule below.

The same scans ship for GitLab CI from a sister repository,
[`Tooark/template-ci-security-scanner`](https://github.com/Tooark/template-ci-security-scanner).
The two share input names on purpose, so a change to an input here is usually
worth an issue there.

If you are new to CI pipelines, read the
[onboarding guide](https://tooark.com/action-security-scanner/) first — it
explains what each file does and why.

## Table of contents

- [Ways to contribute](#ways-to-contribute)
- [What belongs here and what does not](#what-belongs-here-and-what-does-not)
- [Repository layout](#repository-layout)
- [Development workflow](#development-workflow)
- [Adding or renaming an input](#adding-or-renaming-an-input)
- [Versioning](#versioning)
- [Commit convention](#commit-convention)
- [Documentation standards](#documentation-standards)
- [Releasing](#releasing)
- [Pull Request checklist](#pull-request-checklist)
- [Community](#community)

---

## Ways to contribute

- 🐛 **Report bugs** — open an issue with the `bug` template.
- ✨ **Suggest improvements** — open an issue with the `feature` template.
- 📖 **Improve documentation** — the READMEs (English and Portuguese) and the
  onboarding guide in `docs/` are first-class.
- 🔒 **Review security** — question a default, a mount, or a place where a
  value could reach a shell.
- 💻 **Write code** — the Action, the runner script, the examples, validation.

---

## What belongs here and what does not

This Action **forwards configuration**; it does not implement scanning.
Trivy, Hadolint, Betterleaks and the `ark-tools` CLI live in the image, built
from [`Tooark/base-images`](https://github.com/Tooark/base-images/tree/main/security-scanner).

| Change                                                | Repository                     |
| ----------------------------------------------------- | ------------------------------ |
| A new input that forwards a variable the image reads  | here                           |
| A step fails before `ark-tools` starts                | here                           |
| The cache, the artifact upload, file ownership        | here                           |
| A tool needs a flag the image does not expose         | `base-images`                  |
| The report format or the consolidated envelope        | `base-images`                  |
| Anything about a GitLab template or the CI/CD Catalog | `template-ci-security-scanner` |

Before proposing a new input, check that it cannot already be done by setting
the matching environment variable as `env` on the step — the Action passes on
every variable under the image's prefixes, so an input is a convenience for the
settings most people touch, not the only way in.

---

## Repository layout

```text
action.yml          The composite Action: inputs, outputs, steps
src/run-scanner.sh  Translates the inputs into a docker run of the image
examples/           Ready-to-copy workflows
scripts/            Checks run in CI and locally
tests/              Tests of the runner script, no Docker needed
docs/               Onboarding guide, published to GitHub Pages
VERSION             Single source of truth for versions
```

---

## Development workflow

```bash
python3 -m pip install pyyaml

./scripts/check-sync.sh               # version pins, input wiring, docs
python3 scripts/check-examples.py     # examples and README snippets match action.yml
./tests/run-scanner.test.sh           # the docker run the Action builds, without Docker
shellcheck -s bash src/run-scanner.sh scripts/*.sh tests/*.sh
```

Run all four before opening a PR. CI runs them, plus `actionlint`, plus a
self-scan in which the Action in this repository scans this repository.

**Install `shellcheck` locally.** It fails on `info`-level findings, and it is
the easiest of the four to discover only after CI has turned red.

`tests/run-scanner.test.sh` puts a stand-in `docker` on the `PATH` that records
the command line instead of running it, then asserts on what
`src/run-scanner.sh` built. It is where a change to precedence, to what is
forwarded, or to path rewriting gets its test — none of it needs the image.

To run the Action's script by hand, against any directory, on a machine with
Docker:

```bash
ARK_WORKSPACE="$PWD" ARK_COMMAND=secret-scan ARK_IN_NO_GIT=true bash src/run-scanner.sh
```

Every input is an `ARK_IN_<NAME>` variable there; `action.yml` shows the
mapping.

`check-examples.py` exists because GitHub does not reject an input the Action
never declared: the workflow runs, prints a warning nobody reads, and the
setting does nothing. An example that teaches such an input must never reach a
tag.

---

## Adding or renaming an input

An input lives in **four places**. Miss one and `check-sync.sh` fails the
build — which is the point, because the failure mode it replaces is silent:
the input exists in the documentation, the user sets it, and nothing happens.

1. The `inputs:` block of `action.yml` — with a `description` that names the
   allowed values. This block is the authoritative reference for users.
2. The `env:` of the scan step in `action.yml`, staged as `ARK_IN_<NAME>`.
3. `src/run-scanner.sh` — forwarded to the container.
4. The input tables of `README.md` and `README.pt-BR.md`.

Three rules that are not negotiable:

**Names match the image and the GitLab templates.** An input that forwards an
image variable takes its name in `kebab-case`: `TRIVY_SEVERITY` is
`trivy-severity` here and `trivy_severity` in the templates. Someone moving
between the two platforms should have nothing to relearn.

**An empty input is never forwarded.** That is what makes
`input > workflow env > image default` hold. Forwarding an empty value would
overwrite, with an empty string, a variable the workflow set as `env`.

**Inputs never reach a shell as text.** They arrive as environment variables.
A `${{ inputs.x }}` spliced into a `run:` block is a command injection waiting
for the right input.

---

## Versioning

The project follows [Semantic Versioning](https://semver.org/).

[`VERSION`](VERSION) is the single source of truth for the Action version, the
scanner image tag it pins, and the report envelope that image writes:

```text
COMPONENT_VERSION=1.3.0
SCANNER_IMAGE=ghcr.io/tooark/security-scanner
SCANNER_VERSION=1.10
REPORT_SCHEMA=ark-report-tools
REPORT_VERSION=1.3
```

Bumping the scanner image is a three-step change: edit `VERSION` (and
`REPORT_VERSION` when the new image writes a new envelope), run
`./scripts/check-sync.sh`, update the pins and mentions it flags. Never edit a
pin directly. The onboarding guide needs no edit: it has no version of its own
to update.

What counts as breaking here is anything that changes what runs inside a
consumer's workflow: a removed or renamed input, a changed default, or a new
minimum runner version pulled in by an action referenced from `action.yml`.
Record it in `CHANGELOG.md` — the consumer cannot see the diff, only the tag.

The scanner image default is the exception: it follows the image's own
versioning. A minor or patch bump of the image ships in a minor or patch
release here, a major one in a major release. What the image changes with it —
the report envelope, a tool version — is the image's to version; the
changelog entry still names anything a consumer has to act on, such as a
collector that must accept a new envelope version.

---

## Commit convention

We use [**Conventional Commits**](https://www.conventionalcommits.org/).

Format:

```text
<type>(<scope>): <short summary>
```

Common types: `feat`, `fix`, `docs`, `refactor`, `build`, `ci`, `chore`.

Use the area as the scope when it applies:

```text
feat(action): add trivy-ignorefile to the Trivy scans
fix(runner): treat an empty path as the workspace root
chore(version): bump the scanner image to 1.10
docs(readme): document the artifact name collision
```

---

## Documentation standards

- The repository ships a **bilingual README**: `README.md` in English and
  `README.pt-BR.md` in Portuguese, with the language selector at the top.
  **Keep both in sync** — a change in one requires the same change in the
  other.
- Every input is documented twice: its `description` in `action.yml`, and a
  row in the README tables. `check-sync.sh` fails when a README misses one.
- Every YAML block in the READMEs that calls the Action is checked against
  `action.yml` by `check-examples.py`, exactly like the files in `examples/`.
  Write snippets that parse on their own.
- `docs/` holds the onboarding guide, published to GitHub Pages. It explains
  _why_ a decision was made; the README explains _how_ to use the Action.
  Resist adding a third place that says the same thing — there is no
  `check-sync.sh` for prose.
- The guide never types a version. It writes `{{COMPONENT_VERSION}}`,
  `{{SCANNER_VERSION}}` and the other `VERSION` keys, and
  `scripts/render-docs.sh` fills them in before Pages publishes it; the header
  of that script lists the derived ones, such as `{{COMPONENT_MINOR}}`.
  `check-sync.sh` fails on a version typed by hand. To preview the page, run
  `./scripts/render-docs.sh` and open `_site/index.html` — `docs/index.html`
  itself shows the raw placeholders.
- Comments in `action.yml` and in `src/run-scanner.sh` record the reason a
  line exists, not what it does. Several of them are the only surviving record
  of a bug that took a while to find.

---

## Releasing

Releases are cut from tags:

1. Update `COMPONENT_VERSION` in `VERSION`.
2. Move the `[Unreleased]` entries in `CHANGELOG.md` under the new version.
3. Tag `vMAJOR.MINOR.PATCH` and push it.

[`.github/workflows/release.yml`](.github/workflows/release.yml) runs the
checks, **refuses a tag that disagrees with `COMPONENT_VERSION`**, creates the
release with generated notes, and force-moves the floating `vMAJOR` and
`vMAJOR.MINOR` tags.

Marketplace listing is a manual opt-in the API cannot set: open the release on
GitHub and tick _Publish this Action to the GitHub Marketplace_.

---

## Pull Request checklist

The [PR template](.github/PULL_REQUEST_TEMPLATE.md) carries the full list. The
short version:

- [ ] The four local validations pass
- [ ] A new input landed in all four places
- [ ] `README.md` and `README.pt-BR.md` are in sync
- [ ] `CHANGELOG.md` has an `[Unreleased]` entry
- [ ] Consumer-visible changes are called out explicitly

---

## Community

- 💬 Questions and support: [`SUPPORT.md`](SUPPORT.md)
- 🔒 Security reports: [`SECURITY.md`](SECURITY.md) — never a public issue
- 🤝 Expected behaviour: [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md)
