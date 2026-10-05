# Support

Thanks for your interest in **Tooark action-security-scanner**! 💙

This document explains where to get help based on what you're trying to do.

---

## 🤔 I have a question

**Read the onboarding guide first:** <https://tooark.com/action-security-scanner/>

It walks the repository file by file — what each artifact does, how an input
travels from the workflow to the scanner, and the reasoning behind the
decisions that look odd on a first read.

Still stuck? **Open an issue:**
<https://github.com/Tooark/action-security-scanner/issues/new/choose>

Please **search existing issues** first. The reference for every input is the
[README](README.md#-inputs), backed by [`action.yml`](action.yml); ready-made
workflows live in [`examples/`](examples/).

Using GitLab CI? Questions about the templates go to
[`Tooark/template-ci-security-scanner`](https://github.com/Tooark/template-ci-security-scanner/issues/new/choose).

---

## 🐛 I found a bug

**Open an issue using the "Bug report" template:**
<https://github.com/Tooark/action-security-scanner/issues/new/choose>

Please include:

- **Which scan** (`full-scan`, `secret-scan`, …).
- **The Action tag** you pinned (e.g. `v1.0.0`) and the **scanner image tag**.
- **Which runner** — self-hosted runners behave differently for image scanning,
  caching and file ownership.
- **The step** that reproduces it, with its `with:` and `env:`.
- **Relevant logs** — redact credentials, tokens and any detected secret.

---

## 🐳 The problem is inside the scanner itself

Trivy, Hadolint, Betterleaks and the `ark-tools` CLI are **not** in this
repository. They ship in the `security-scanner` image, built from
[`Tooark/base-images`](https://github.com/Tooark/base-images/tree/main/security-scanner).

Rule of thumb:

| Symptom                                                     | Where it belongs                                                                         |
| ----------------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| An input is ignored or mis-named                            | here                                                                                     |
| The step fails before `ark-tools` runs                      | here                                                                                     |
| The cache, the artifact upload or file ownership misbehaves | here                                                                                     |
| A scan finds the wrong thing, or a tool flag is unsupported | `base-images`                                                                            |
| The report format or the consolidated envelope is wrong     | `base-images`                                                                            |
| The report's `image` object names the wrong image           | here                                                                                     |
| Anything in a `.gitlab-ci.yml`                              | [`template-ci-security-scanner`](https://github.com/Tooark/template-ci-security-scanner) |

---

## ✨ I have an improvement idea

**Open an issue using the "Feature request" template:**
<https://github.com/Tooark/action-security-scanner/issues/new/choose>

Explain the **problem** you are trying to solve, not just the solution. Note
that every variable the image reads can already be set as `env` on the step —
an input is a convenience on top of that, not the only way in.

---

## 🔒 I found a security vulnerability

**Do NOT open a public issue.** Use one of these private channels:

- **Preferred**: [GitHub Security Advisories](https://github.com/Tooark/action-security-scanner/security/advisories/new)
- **Email**: `security@tooark.com` _(PGP key available on request)_

Full policy and response targets are in [`SECURITY.md`](SECURITY.md).

---

## 📚 I want to read the docs

| Audience                | Start here                                                                                    |
| ----------------------- | --------------------------------------------------------------------------------------------- |
| **New to CI pipelines** | [Onboarding guide](https://tooark.com/action-security-scanner/)                               |
| **Users**               | [README.md](README.md) · [README.pt-BR.md](README.pt-BR.md)                                   |
| **Every input**         | [README — Inputs](README.md#-inputs) and [`action.yml`](action.yml)                            |
| **Support boundaries**  | [SUPPORTED-INTEGRATIONS.md](SUPPORTED-INTEGRATIONS.md)                                        |
| **Workflow examples**   | [examples/](examples/)                                                                        |
| **Contributors**        | [CONTRIBUTING.md](CONTRIBUTING.md)                                                            |
| **GitLab CI users**     | [Tooark/template-ci-security-scanner](https://github.com/Tooark/template-ci-security-scanner) |
