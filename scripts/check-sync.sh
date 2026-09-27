#!/usr/bin/env bash
# =============================================================================
# Guards the invariants that keep the GitLab templates and the GitHub Action
# interchangeable, and the documentation honest:
#
#   1. every artifact pins exactly the scanner image declared in VERSION;
#   2. every ARK_IN_* an artifact sets is actually consumed downstream;
#   3. every copy-paste reference in the docs pins COMPONENT_VERSION, every
#      mention of the report envelope names REPORT_VERSION, and the onboarding
#      guide takes all of its versions from VERSION.
#
# Run it locally with: ./scripts/check-sync.sh
#
# Membership tests use bash string matching rather than a grep per name: the
# check runs hundreds of them and process creation dominates on Windows.
# =============================================================================
set -euo pipefail

cd "$(dirname "$0")/.."

failures=0
ok() { printf '  ok   %s\n' "$*"; }
fail() { printf '  FAIL %s\n' "$*" >&2; failures=$((failures + 1)); }

# Membership test over a newline-separated list.
has_line() {
  local list="$1" needle="$2"
  [[ $'\n'"$list"$'\n' == *$'\n'"$needle"$'\n'* ]]
}

# -----------------------------------------------------------------------------
# Reads KEY=value from the VERSION file.
# -----------------------------------------------------------------------------
version_field() {
  local key="$1" value
  value="$(grep -E "^${key}=" VERSION | head -n1 | cut -d= -f2-)"
  [ -n "$value" ] || { printf 'VERSION is missing %s\n' "$key" >&2; exit 1; }
  printf '%s' "$value"
}

SCANNER_IMAGE="$(version_field SCANNER_IMAGE)"
SCANNER_VERSION="$(version_field SCANNER_VERSION)"

# -----------------------------------------------------------------------------
# Prints the quoted default that follows a key, searching a few lines ahead.
# -----------------------------------------------------------------------------
default_after() {
  local file="$1" key="$2" span="${3:-4}"
  grep -A"$span" -E "^[[:space:]]*${key}:[[:space:]]*$" "$file" |
    grep -m1 -E "^[[:space:]]*default:" |
    sed -E 's/.*default:[[:space:]]*"?([^"]*)"?[[:space:]]*$/\1/'
}

expect_pin() {
  local label="$1" actual="$2" expected="$3"
  if [ "$actual" = "$expected" ]; then
    ok "$label"
  else
    fail "$label is '$actual', expected '$expected'"
  fi
}

echo "VERSION pins ${SCANNER_IMAGE}:${SCANNER_VERSION}"
echo
echo "1. image pinning"

for template in templates/*.yml; do
  expect_pin "$template scanner_image" "$(default_after "$template" scanner_image)" "$SCANNER_IMAGE"
  expect_pin "$template scanner_version" "$(default_after "$template" scanner_version)" "$SCANNER_VERSION"
done

expect_pin "action.yml scanner-image" "$(default_after action.yml scanner-image)" "$SCANNER_IMAGE"
expect_pin "action.yml scanner-version" "$(default_after action.yml scanner-version)" "$SCANNER_VERSION"

# The runner script carries its own fallbacks for direct invocation.
runner="$(cat src/run-scanner.sh)"

if [[ $runner == *"ARK_SCANNER_IMAGE:-${SCANNER_IMAGE}}"* ]]; then
  ok "src/run-scanner.sh scanner image fallback"
else
  fail "src/run-scanner.sh scanner image fallback does not match '$SCANNER_IMAGE'"
fi

if [[ $runner == *"ARK_SCANNER_VERSION:-${SCANNER_VERSION}}"* ]]; then
  ok "src/run-scanner.sh scanner version fallback"
else
  fail "src/run-scanner.sh scanner version fallback does not match '$SCANNER_VERSION'"
fi

# -----------------------------------------------------------------------------
# Lists the bare variable names passed to a forwarding helper, following
# backslash continuations. Used for both ark_apply_inputs (templates) and
# add_env_from_input (runner script).
# -----------------------------------------------------------------------------
forwarded_names() {
  awk -v fn="$2" '
    {
      line = $0
      if (index(line, fn) > 0) { inblock = 1 }
      if (inblock) {
        cont = (line ~ /\\[ \t]*$/)
        sub(fn, "", line)
        gsub(/\\/, "", line)
        n = split(line, parts, /[ \t]+/)
        for (i = 1; i <= n; i++) {
          if (parts[i] ~ /^[A-Z][A-Z0-9_]*$/) { print parts[i] }
        }
        if (!cont) { inblock = 0 }
      }
    }
  ' "$1" | sort -u
}

echo
echo "2. ARK_IN_* wiring in templates"

for template in templates/*.yml; do
  content="$(cat "$template")"
  declared="$(grep -oE '^[[:space:]]+ARK_IN_[A-Z0-9_]+:' "$template" | tr -d ' :' | sort -u)"
  used_direct="$(grep -oE 'ARK_IN_[A-Z0-9_]+' "$template" | sort -u)"
  exported="$(forwarded_names "$template" ark_apply_inputs | sed 's/^/ARK_IN_/')"

  template_ok=1

  # Anything the job script references must be declared under variables:.
  for name in $used_direct; do
    if ! has_line "$declared" "$name"; then
      fail "$template uses $name but never declares it under variables:"
      template_ok=0
    fi
  done

  # Anything declared must be read directly or exported by ark_apply_inputs.
  for name in $declared; do
    if has_line "$exported" "$name"; then
      continue
    fi
    if [[ $content == *"\${${name}"* ]]; then
      continue
    fi
    fail "$template declares $name but never reads or exports it"
    template_ok=0
  done

  [ "$template_ok" -eq 1 ] && ok "$template"
done

echo
echo "3. ARK_IN_* wiring between action.yml and src/run-scanner.sh"

action_ok=1
runner_forwarded="$(forwarded_names src/run-scanner.sh add_env_from_input | sed 's/^/ARK_IN_/')"

# Read rather than word-split: process substitution keeps the loop in this
# shell, so action_ok survives it (a pipe would run the body in a subshell).
while read -r name; do
  # Either referenced verbatim, or forwarded as a bare name to add_env_from_input.
  if [[ $runner == *"$name"* ]]; then
    continue
  fi
  if has_line "$runner_forwarded" "$name"; then
    continue
  fi
  fail "action.yml sets $name but src/run-scanner.sh never forwards it"
  action_ok=0
done < <(grep -oE 'ARK_IN_[A-Z0-9_]+' action.yml | sort -u)
[ "$action_ok" -eq 1 ] && ok "action.yml -> src/run-scanner.sh"

echo
echo "4. versions quoted in the documentation"

COMPONENT_VERSION="$(version_field COMPONENT_VERSION)"
REPORT_SCHEMA="$(version_field REPORT_SCHEMA)"
REPORT_VERSION="$(version_field REPORT_VERSION)"

# The guide carries {{PLACEHOLDERS}} instead of versions. Readers get the
# rendered copy, so that is what the reference checks below read; rendering
# also fails on a placeholder VERSION does not declare.
rendered="$(mktemp -d)"
trap 'rm -rf "$rendered"' EXIT

if bash scripts/render-docs.sh "$rendered" >/dev/null; then
  ok "docs/ renders from VERSION"
else
  fail "docs/ does not render from VERSION (run ./scripts/render-docs.sh)"
fi

# Where a file is read from: the rendered copy for the guide, itself otherwise.
checked_copy() {
  if [ "$1" = docs/index.html ]; then
    printf '%s' "$rendered/index.html"
  else
    printf '%s' "$1"
  fi
}

# Only the three forms a reader copies into their own pipeline. Prose that
# explains the tagging scheme -- "v1.0.0 is never moved", the table of floating
# tags -- is illustrative and deliberately not matched.
VERSION_REF_RE='ci-security-scanner@v[0-9]+\.[0-9]+\.[0-9]+'
VERSION_REF_RE="$VERSION_REF_RE|ci-security-scanner/v[0-9]+\.[0-9]+\.[0-9]+/"
VERSION_REF_RE="$VERSION_REF_RE|ci-security-scanner/[a-z-]+@[0-9]+\.[0-9]+\.[0-9]+"

version_ref_files=(
  README.md
  README.pt-BR.md
  SUPPORTED-INTEGRATIONS.md
  docs/index.html
  examples/github/security-scan.yml
  examples/gitlab/catalog-component.gitlab-ci.yml
  examples/gitlab/remote-include.gitlab-ci.yml
  examples/gitlab-catalog-mirror/README.md
)

for file in "${version_ref_files[@]}"; do
  if [ ! -f "$file" ]; then
    fail "$file is checked for the component version but does not exist"
    continue
  fi

  file_ok=1
  seen=0
  while read -r ref; do
    [ -n "$ref" ] || continue
    seen=1
    # Strip a trailing slash first, then everything up to the last @ or / and
    # an optional v, leaving the bare version.
    found="$(printf '%s' "$ref" | sed -E 's#/$##; s#.*[@/]v?##')"
    if [ "$found" != "$COMPONENT_VERSION" ]; then
      fail "$file pins $found, expected $COMPONENT_VERSION  ($ref)"
      file_ok=0
    fi
  done < <(grep -oE "$VERSION_REF_RE" "$(checked_copy "$file")" | sort -u)

  if [ "$seen" -eq 0 ]; then
    fail "$file has no component version reference; restore it or drop the file from the list"
  elif [ "$file_ok" -eq 1 ]; then
    ok "$file"
  fi
done

# The envelope version is what a collector behind report_url validates against,
# so a stale one in the docs sends people to the wrong schema. CHANGELOG.md is
# history and deliberately not matched.
REPORT_REF_RE="${REPORT_SCHEMA}\`? (envelope )?v[0-9]+(\.[0-9]+)*"

report_ref_files=(
  README.md
  README.pt-BR.md
  docs/index.html
  templates/full-scan.yml
)

for file in "${report_ref_files[@]}"; do
  file_ok=1
  seen=0
  while read -r ref; do
    [ -n "$ref" ] || continue
    seen=1
    found="${ref##*v}"
    if [ "$found" != "$REPORT_VERSION" ]; then
      fail "$file names $REPORT_SCHEMA v$found, expected v$REPORT_VERSION  ($ref)"
      file_ok=0
    fi
  done < <(grep -oE "$REPORT_REF_RE" "$(checked_copy "$file")" | sort -u)

  if [ "$seen" -eq 0 ]; then
    fail "$file never names the $REPORT_SCHEMA version; restore it or drop the file from the list"
  elif [ "$file_ok" -eq 1 ]; then
    ok "$file names $REPORT_SCHEMA v$REPORT_VERSION"
  fi
done

# A version typed straight into the guide still renders, and still agrees with
# VERSION today; it is the next bump that leaves it behind. Catch it now. Only
# the page body is read: the stylesheet's numbers (line-height: 1.3) are not
# versions.
guide_ok=1
body_line="$(grep -n '<body' docs/index.html | head -n1 | cut -d: -f1)"
for key in COMPONENT_VERSION SCANNER_VERSION REPORT_VERSION; do
  value="$(version_field "$key")"
  # Bounded on both sides so 1.3 matches neither 11.3 nor 1.30 nor the 1.3.01
  # of an SVG path; a sentence-ending "1.3." still counts.
  literal_re="(^|[^0-9.])${value//./\\.}([^0-9.]|\.([^0-9]|$)|$)"
  while IFS=: read -r line _; do
    [ -n "$line" ] || continue
    [ "$line" -gt "${body_line:-0}" ] || continue
    fail "docs/index.html:$line types $value; write {{$key}} instead"
    guide_ok=0
  done < <(grep -nE "$literal_re" docs/index.html || true)
done
[ "$guide_ok" -eq 1 ] && ok "docs/index.html types no version by hand"

echo
if [ "$failures" -gt 0 ]; then
  printf '%s check(s) failed\n' "$failures" >&2
  exit 1
fi
echo "all checks passed"
