#!/usr/bin/env bash
# =============================================================================
# Tests src/run-scanner.sh without Docker.
# -----------------------------------------------------------------------------
# The whole job of that script is to build one `docker run` command line. A
# stand-in `docker`, written to a temporary directory below, records the
# command line instead of running it, and each case asserts on what it
# received, one argument per line.
#
# What this covers is the contract the README documents: precedence, what is
# forwarded and what never is, path rewriting, soft-fail, the outputs. What it
# cannot cover is the image itself; the self-scan job in CI does that.
#
# Run it with: ./tests/run-scanner.test.sh
# =============================================================================
set -uo pipefail

cd "$(dirname "$0")/.." || exit 1

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/bin" "$tmp/workspace"
argv="$tmp/argv.txt"
log="$tmp/log.txt"
outputs="$tmp/outputs.txt"

# `image inspect` reports the image as missing and `pull` succeeds, which is
# the path a fresh runner takes. `run` is the only call that matters.
cat > "$tmp/bin/docker" <<'STUB'
#!/usr/bin/env bash
case "${1:-}" in
  image) exit 1 ;;
  pull) exit 0 ;;
  run)
    shift
    printf '%s\n' "$@" > "$DOCKER_STUB_ARGV"
    exit "${DOCKER_STUB_EXIT:-0}"
    ;;
  *)
    echo "docker stub: unexpected command: $*" >&2
    exit 64
    ;;
esac
STUB
chmod +x "$tmp/bin/docker"

failures=0
ok() { printf '  ok   %s\n' "$*"; }
fail() { printf '  FAIL %s\n' "$*" >&2; failures=$((failures + 1)); }

# Runs the script with exactly the variables given, plus what the stub needs.
# A clean environment keeps the runner's own variables out of the assertions.
status=0
run_scanner() {
  : > "$argv"
  : > "$outputs"
  status=0
  env -i \
    PATH="$tmp/bin:$PATH" \
    DOCKER_STUB_ARGV="$argv" \
    RUNNER_TEMP="$tmp" \
    ARK_WORKSPACE="$tmp/workspace" \
    GITHUB_OUTPUT="$outputs" \
    "$@" bash src/run-scanner.sh > "$log" 2>&1 || status=$?
}

# An argument `docker run` received, as one exact line.
passed() {
  if grep -qxF -- "$2" "$argv"; then ok "$1"; else fail "$1 (docker run never received '$2')"; fi
}

not_passed() {
  if grep -qxF -- "$2" "$argv"; then fail "$1 (docker run received '$2')"; else ok "$1"; fi
}

# The ark-tools command line: everything after the image reference.
command_line() {
  sed -n '/^ghcr\.io\/tooark\/security-scanner:/,$p' "$argv" | tail -n +2 | tr '\n' ' ' | sed 's/ $//'
}

runs() {
  local actual
  actual="$(command_line)"
  if [ "$actual" = "$2" ]; then ok "$1"; else fail "$1 (ran 'ark-tools $actual', expected 'ark-tools $2')"; fi
}

exits() {
  if [ "$status" -eq "$2" ]; then ok "$1"; else fail "$1 (exit $status, expected $2)"; fi
}

echo "1. precedence: input > job env > image default"

run_scanner ARK_COMMAND=filesystem-scan TRIVY_SEVERITY=CRITICAL TRIVY_SKIP_DB_UPDATE=true
passed "a blank input lets the job env through" "TRIVY_SEVERITY"
passed "a variable with no input comes from the job env" "TRIVY_SKIP_DB_UPDATE"

run_scanner ARK_COMMAND=filesystem-scan ARK_IN_TRIVY_SEVERITY=HIGH TRIVY_SEVERITY=CRITICAL
passed "an input is forwarded with its value" "TRIVY_SEVERITY=HIGH"
not_passed "and the job env is not passed on top of it" "TRIVY_SEVERITY"

run_scanner ARK_COMMAND=secret-scan BETTERLEAKS_REDACT=
not_passed "an empty job variable is not forwarded" "BETTERLEAKS_REDACT"

run_scanner ARK_COMMAND=secret-scan
not_passed "with neither, the image default applies" "BETTERLEAKS_REDACT"

echo
echo "2. secrets"

run_scanner ARK_COMMAND=full-scan REPORT_TOKEN=s3cr3t TRIVY_PASSWORD=hunter2 \
  AWS_SECRET_ACCESS_KEY=nope GITHUB_TOKEN=nope
passed "REPORT_TOKEN is passed by name" "REPORT_TOKEN"
passed "TRIVY_PASSWORD is passed by name" "TRIVY_PASSWORD"
not_passed "a secret value never lands in argv" "REPORT_TOKEN=s3cr3t"
not_passed "variables the image does not read stay out" "AWS_SECRET_ACCESS_KEY"
not_passed "GITHUB_TOKEN stays out" "GITHUB_TOKEN"
if grep -qE 's3cr3t|hunter2' "$log"; then
  fail "a secret value was printed in the log"
else
  ok "a secret value never lands in the log"
fi

echo
echo "3. paths the script owns"

run_scanner ARK_COMMAND=full-scan ARK_IN_IMAGE=app:1 \
  REPORT_DIR=/host/reports TRIVY_CACHE_DIR=/host/cache FULL_SCAN_PATH=/host/src
passed "REPORT_DIR is the container path" "REPORT_DIR=/reports"
not_passed "a host REPORT_DIR cannot replace it" "REPORT_DIR"
not_passed "a host TRIVY_CACHE_DIR cannot replace the mount" "TRIVY_CACHE_DIR"
not_passed "a host FULL_SCAN_PATH cannot replace --path" "FULL_SCAN_PATH"

echo
echo "4. the command line, per scan"

run_scanner ARK_COMMAND=full-scan ARK_IN_PATH=.
runs "full-scan defaults to the workspace" "full-scan --path /workspace"
passed "full-scan without an image skips the image step" "FULL_SCAN_SKIP_IMAGE=true"

run_scanner ARK_COMMAND=full-scan ARK_IN_IMAGE=app:1 ARK_IN_PATH=services/api ARK_IN_SBOM=true
runs "full-scan with an image, a path and an SBOM" "full-scan app:1 --path /workspace/services/api --sbom"
not_passed "full-scan with an image keeps the image step" "FULL_SCAN_SKIP_IMAGE=true"

run_scanner ARK_COMMAND=full-scan FULL_SCAN_SKIP_IMAGE=false
passed "FULL_SCAN_SKIP_IMAGE from the job env is respected" "FULL_SCAN_SKIP_IMAGE"
not_passed "and is not forced to true" "FULL_SCAN_SKIP_IMAGE=true"

run_scanner ARK_COMMAND=image-scan ARK_IN_IMAGE=registry.example.com/app:1 ARK_IN_SBOM=true
runs "image-scan" "image-scan --sbom registry.example.com/app:1"

run_scanner ARK_COMMAND=image-scan
exits "image-scan without an image is refused" 1
if [ -s "$argv" ]; then fail "docker ran anyway"; else ok "and docker never runs"; fi

run_scanner ARK_COMMAND=filesystem-scan ARK_IN_PATH=./src
runs "filesystem-scan rewrites a relative path" "filesystem-scan /workspace/src"

run_scanner ARK_COMMAND=config-scan ARK_IN_PATH=/abs/terraform
runs "config-scan leaves an absolute path alone" "config-scan /abs/terraform"

run_scanner ARK_COMMAND=repo-scan ARK_IN_TARGET=https://github.com/org/repo.git
runs "repo-scan leaves a URL alone" "repo-scan https://github.com/org/repo.git"

run_scanner ARK_COMMAND=repo-scan
runs "repo-scan defaults to the workspace" "repo-scan /workspace"

run_scanner ARK_COMMAND=dockerfile-lint
runs "dockerfile-lint defaults to ./Dockerfile" "dockerfile-lint /workspace/Dockerfile"

run_scanner ARK_COMMAND=dockerfile-lint ARK_IN_DOCKERFILE=docker/Dockerfile.worker
runs "dockerfile-lint rewrites the Dockerfile path" "dockerfile-lint /workspace/docker/Dockerfile.worker"

run_scanner ARK_COMMAND=secret-scan ARK_IN_NO_GIT=true ARK_IN_PATH=.
runs "secret-scan --no-git" "secret-scan --no-git /workspace"

run_scanner ARK_COMMAND=full-scan ARK_IN_PATH=. "ARK_IN_EXTRA_ARGS=--skip-dirs * --debug"
runs "extra-args are split on spaces but never globbed" "full-scan --path /workspace -- --skip-dirs * --debug"

run_scanner ARK_COMMAND=deploy-to-production
exits "an unknown command is refused" 1
if [ -s "$argv" ]; then fail "docker ran anyway"; else ok "and docker never runs"; fi

echo
echo "5. mounts and scanner identity"

run_scanner ARK_COMMAND=full-scan ARK_SCANNER_IMAGE=mirror.example.com/scanner ARK_SCANNER_VERSION=9.9
passed "the workspace is mounted" "$tmp/workspace:/workspace"
passed "the reports directory is mounted" "$tmp/workspace/scan-reports:/reports"
passed "the Trivy cache is mounted" "$tmp/ark-trivy-cache:/home/app/.cache/trivy"
passed "a mirror is run as given" "mirror.example.com/scanner:9.9"
passed "and recorded as the image name" "ARK_IMAGE_NAME=mirror.example.com/scanner"
passed "with its tag" "ARK_IMAGE_TAG=9.9"

run_scanner ARK_COMMAND=secret-scan ARK_TRIVY_CACHE=false ARK_REPORTS_DIR=out/security
not_passed "trivy-cache: false drops the cache mount" "$tmp/ark-trivy-cache:/home/app/.cache/trivy"
passed "reports-dir moves the reports mount" "$tmp/workspace/out/security:/reports"

echo
echo "6. exit code, soft-fail and outputs"

run_scanner ARK_COMMAND=secret-scan DOCKER_STUB_EXIT=1
exits "a tripped gate fails the step" 1
if grep -qxF "exit-code=1" "$outputs"; then ok "exit-code output is 1"; else fail "exit-code output is not 1"; fi

run_scanner ARK_COMMAND=secret-scan DOCKER_STUB_EXIT=1 ARK_SOFT_FAIL=true
exits "soft-fail keeps the step green" 0
if grep -qxF "exit-code=1" "$outputs"; then ok "and still reports exit-code=1"; else fail "soft-fail lost the exit code"; fi

run_scanner ARK_COMMAND=full-scan
exits "a clean scan succeeds" 0
if grep -qxF "reports-dir=$tmp/workspace/scan-reports" "$outputs"; then
  ok "reports-dir output is the absolute path"
else
  fail "reports-dir output is wrong: $(grep '^reports-dir=' "$outputs")"
fi
if grep -qxF "report=$tmp/workspace/scan-reports/full-scan-report.json" "$outputs"; then
  ok "report output points at the consolidated report"
else
  fail "report output is wrong: $(grep '^report=' "$outputs")"
fi

echo
if [ "$failures" -gt 0 ]; then
  printf '%s check(s) failed\n' "$failures" >&2
  exit 1
fi
echo "all runner checks passed"
