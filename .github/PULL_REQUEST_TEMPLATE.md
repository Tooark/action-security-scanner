# Summary

<!--
Explain what this PR does and why. Reference the issue(s) it closes.
Example: "Closes #42 — add trivy-ignorefile to the Trivy scans."
-->

## Affected area(s)

- [ ] `action.yml` — the composite Action
- [ ] `src/run-scanner.sh` — the runner behind the Action
- [ ] `scripts/` and `tests/` — validation run in CI and locally
- [ ] `.github/workflows/` — this repository's own CI
- [ ] `VERSION` — scanner image or component version
- [ ] `docs/` — onboarding guide
- [ ] `examples/` — copy-ready workflows
- [ ] Governance / documentation only

## Type of change

- [ ] `feat` — new input, new scan, new capability
- [ ] `fix` — bug fix
- [ ] `docs` — documentation only
- [ ] `refactor` — no functional change
- [ ] `build` / `ci` — workflow or tooling change
- [ ] `chore` — version bumps, dependency updates
- [ ] Breaking change (describe it under "Consumer impact")

## Consumer impact

<!--
Does this change what runs inside someone else's workflow? action.yml and
src/run-scanner.sh do; .github/workflows/ does not. Call out anything that raises a
requirement on the consumer's side — a new minimum runner version, a new
permission, a changed default, a removed input — and add it to CHANGELOG.md.
-->

- [ ] No consumer-visible change (this repo's own CI, docs or tooling only)
- [ ] Consumer-visible; described above and recorded in `CHANGELOG.md`

## Checklist

- [ ] Commits follow [Conventional Commits](https://www.conventionalcommits.org/)
- [ ] `./scripts/check-sync.sh` passes
- [ ] `python3 scripts/check-examples.py` passes
- [ ] `./tests/run-scanner.test.sh` passes, with a case for any new behaviour
- [ ] `shellcheck -s bash src/run-scanner.sh scripts/*.sh tests/*.sh` passes
- [ ] Version pins were changed only through `VERSION`
- [ ] `README.md` and `README.pt-BR.md` updated **and in sync** (if docs changed)
- [ ] `CHANGELOG.md` updated under `[Unreleased]`

### If this PR adds or renames an input

All four places, or `check-sync.sh` will say so:

- [ ] The `inputs:` block of `action.yml` — with a `description` naming the allowed values
- [ ] The `env:` of the scan step in `action.yml`, staged as `ARK_IN_*`
- [ ] `src/run-scanner.sh` — forwarded, and only when non-empty
- [ ] The input tables of `README.md` and `README.pt-BR.md`
- [ ] The name matches the image variable and the GitLab templates (`kebab-case` here, `snake_case` there)

## Notes for reviewers

<!-- Anything specific to focus on, alternatives considered, follow-up work, etc. -->
