#!/usr/bin/env bash
# =============================================================================
# action-security-scanner :: GitHub Action runner
# -----------------------------------------------------------------------------
# Translates the action inputs (staged as ARK_IN_* / ARK_* environment
# variables) into a `docker run` of ghcr.io/tooark/security-scanner.
#
# An empty input is never forwarded, so precedence stays
# "input > workflow env > image default".
# =============================================================================
set -euo pipefail

log() { printf '[action-security-scanner] %s\n' "$*"; }
die() { printf '[action-security-scanner] error: %s\n' "$*" >&2; exit 1; }

# -----------------------------------------------------------------------------
# Container layout. The workspace is always mounted at /workspace, so every
# host-relative input is rewritten against it.
# -----------------------------------------------------------------------------
readonly CONTAINER_WORKSPACE="/workspace"
readonly CONTAINER_REPORTS="/reports"
readonly CONTAINER_TRIVY_CACHE="/home/app/.cache/trivy"

WORKSPACE="${ARK_WORKSPACE:-${GITHUB_WORKSPACE:-$PWD}}"
[ -d "$WORKSPACE" ] || die "workspace not found: $WORKSPACE"

COMMAND="${ARK_COMMAND:-full-scan}"
SCANNER_IMAGE="${ARK_SCANNER_IMAGE:-ghcr.io/tooark/security-scanner}"
SCANNER_VERSION="${ARK_SCANNER_VERSION:-1.10}"
REPORTS_DIR="${ARK_REPORTS_DIR:-scan-reports}"

case "$COMMAND" in
  full-scan | image-scan | filesystem-scan | config-scan | repo-scan | dockerfile-lint | secret-scan) ;;
  *) die "unsupported command: $COMMAND" ;;
esac

# -----------------------------------------------------------------------------
# Rewrites a host-relative path into its path inside the container.
# Absolute paths and URLs are passed through untouched.
# -----------------------------------------------------------------------------
to_container_path() {
  local value="$1"
  case "$value" in
    "") printf '' ;;
    *://*) printf '%s' "$value" ;;
    /*) printf '%s' "$value" ;;
    "." | "./") printf '%s' "$CONTAINER_WORKSPACE" ;;
    ./*) printf '%s/%s' "$CONTAINER_WORKSPACE" "${value#./}" ;;
    *) printf '%s/%s' "$CONTAINER_WORKSPACE" "$value" ;;
  esac
}

# -----------------------------------------------------------------------------
# Host directories. They are created before the run and opened up because the
# image drops privileges to the non-root `app` user (uid 1000), which does not
# match the runner user.
# -----------------------------------------------------------------------------
HOST_REPORTS="$WORKSPACE/$REPORTS_DIR"
case "$REPORTS_DIR" in /*) HOST_REPORTS="$REPORTS_DIR" ;; esac
mkdir -p "$HOST_REPORTS"
# Recursive: a second scan in the same job would otherwise fail to truncate the
# reports the first one left behind, which are owned by the runner user by then.
chmod -R a+rwX "$HOST_REPORTS"

DOCKER_ARGS=(run --rm)
DOCKER_ARGS+=(-v "$WORKSPACE:$CONTAINER_WORKSPACE")
DOCKER_ARGS+=(-v "$HOST_REPORTS:$CONTAINER_REPORTS")

if [ "${ARK_TRIVY_CACHE:-true}" = "true" ]; then
  HOST_TRIVY_CACHE="${RUNNER_TEMP:-/tmp}/ark-trivy-cache"
  mkdir -p "$HOST_TRIVY_CACHE"
  # Recursive: a database restored by actions/cache belongs to the runner user,
  # and the container user must be able to refresh it in place.
  chmod -R a+rwX "$HOST_TRIVY_CACHE"
  DOCKER_ARGS+=(-v "$HOST_TRIVY_CACHE:$CONTAINER_TRIVY_CACHE")
fi

if [ "${ARK_DOCKER_SOCKET:-false}" = "true" ]; then
  [ -S /var/run/docker.sock ] || die "docker-socket requested but /var/run/docker.sock is not a socket"
  DOCKER_ARGS+=(-v /var/run/docker.sock:/var/run/docker.sock)
fi

# -----------------------------------------------------------------------------
# Environment. An input is forwarded only when it carries a value; a blank one
# leaves the variable to whatever the workflow set as `env:`, which
# pass_job_env hands over further down.
# -----------------------------------------------------------------------------

# Names already decided here, one per line, so the job environment cannot
# override them further down. FULL_SCAN_PATH starts in the list because
# full-scan always receives --path, rewritten for the container.
FORWARDED=$'\nFULL_SCAN_PATH\n'

add_env() {
  local name="$1" value="$2"
  [ -n "$value" ] || return 0
  DOCKER_ARGS+=(-e "$name=$value")
  FORWARDED+="$name"$'\n'
  log "  $name=$value"
}

# Forwards $ARK_IN_<name> as <name> when it carries a value.
add_env_from_input() {
  local name value
  for name in "$@"; do
    eval "value=\${ARK_IN_${name}:-}"
    add_env "$name" "$value"
  done
}

log "input overrides:"

add_env "REPORT_DIR" "$CONTAINER_REPORTS"
add_env "TRIVY_CACHE_DIR" "$CONTAINER_TRIVY_CACHE"

# git refuses to read a repository owned by another uid; the container user is
# not the runner user, so declare the mount as safe via env-only git config.
add_env "GIT_CONFIG_COUNT" "1"
add_env "GIT_CONFIG_KEY_0" "safe.directory"
add_env "GIT_CONFIG_VALUE_0" "$CONTAINER_WORKSPACE"

add_env_from_input \
  FULL_SCAN_DOCKERFILES FULL_SCAN_MODE \
  FULL_SCAN_SKIP_IMAGE FULL_SCAN_SKIP_LINT FULL_SCAN_SKIP_SECRETS \
  SBOM_FORMAT \
  TRIVY_SEVERITY TRIVY_SEVERITY_FAIL TRIVY_IGNORE_UNFIXED TRIVY_IGNORE_UNFIXED_FAIL \
  TRIVY_EXIT_CODE TRIVY_FORMAT TRIVY_SCANNERS TRIVY_TIMEOUT TRIVY_SERVER TRIVY_IGNOREFILE \
  HADOLINT_FAILURE_LEVEL HADOLINT_CONFIG HADOLINT_FORMAT HADOLINT_LOG_MAX_FINDINGS \
  BETTERLEAKS_BASELINE BETTERLEAKS_CONFIG BETTERLEAKS_FORMAT \
  BETTERLEAKS_FAIL_ON_FINDINGS BETTERLEAKS_REDACT BETTERLEAKS_LOG_MAX_FINDINGS \
  REPORT_URL REPORT_FAIL_ON_ERROR

# -----------------------------------------------------------------------------
# Job environment. `docker run` starts the container with an empty environment,
# so a variable the workflow sets with `env:` reaches the tools only if it is
# passed on here. That covers three things: a setting whose input was left
# blank, the secrets (which never travel as inputs), and the variables that
# have no input at all, such as TRIVY_SKIP_DB_UPDATE or REPORT_METHOD. This is
# the middle of "input > workflow env > image default".
#
# Passed by name, so docker reads the value from this process: it lands neither
# in argv, where any other process on the runner could read it, nor in the log.
# -----------------------------------------------------------------------------
readonly JOB_ENV_RE='^(TRIVY|HADOLINT|BETTERLEAKS|SBOM|FULL_SCAN|REPORT)_[A-Z0-9_]+$'

pass_job_env() {
  local name names passed=()
  names="$(compgen -e | sort)"
  while IFS= read -r name; do
    if [[ ! $name =~ $JOB_ENV_RE ]] || [ -z "${!name}" ]; then
      continue
    fi
    # An input that won, or a path this script owns.
    if [[ $FORWARDED == *$'\n'"$name"$'\n'* ]]; then
      continue
    fi
    DOCKER_ARGS+=(-e "$name")
    passed+=("$name")
  done <<<"$names"

  if [ "${#passed[@]}" -gt 0 ]; then
    log "from the job env:"
    for name in "${passed[@]}"; do
      log "  $name"
    done
  fi
}

# CI metadata: ark-tools auto-detects GitHub Actions from these.
# GITHUB_WORKSPACE is remapped so the in-container path detection stays valid.
DOCKER_ARGS+=(-e "GITHUB_WORKSPACE=$CONTAINER_WORKSPACE")
for gh_var in GITHUB_ACTIONS GITHUB_REF_NAME GITHUB_HEAD_REF GITHUB_SHA GITHUB_REPOSITORY \
  GITHUB_ACTOR GITHUB_RUN_ID GITHUB_JOB GITHUB_SERVER_URL; do
  eval "gh_value=\${${gh_var}:-}"
  if [ -n "${gh_value}" ]; then
    DOCKER_ARGS+=(-e "$gh_var=$gh_value")
  fi
done

# Scanner identity, for the report's `image` object. The image records its own
# build version, but only the caller knows the name and tag it was run under —
# a mirror, a floating tag — and the digest that tag resolved to. The job env
# still wins over all three.
IMAGE_REF="${SCANNER_IMAGE}:${SCANNER_VERSION}"

# Pull only when the image is missing, as `docker run` would, so the digest read
# below is the one that runs. A failed pull is left for `docker run` to report,
# where soft-fail still applies to it.
if ! docker image inspect "$IMAGE_REF" >/dev/null 2>&1; then
  docker pull --quiet "$IMAGE_REF" >/dev/null || true
fi

# RepoDigests holds name@sha256:<digest> per repository the image was pulled
# from; the envelope wants the bare sha256:<digest> of this one. A locally built
# image has none, and the digest is then left out.
IMAGE_DIGEST="${ARK_IMAGE_DIGEST:-}"
if [ -z "$IMAGE_DIGEST" ]; then
  while IFS= read -r repo_digest; do
    case "$repo_digest" in
      "$SCANNER_IMAGE"@sha256:*)
        IMAGE_DIGEST="${repo_digest#*@}"
        break
      ;;
    esac
  done < <(docker image inspect --format '{{range .RepoDigests}}{{println .}}{{end}}' "$IMAGE_REF" 2>/dev/null || true)
fi

add_env "ARK_IMAGE_NAME" "${ARK_IMAGE_NAME:-$SCANNER_IMAGE}"
add_env "ARK_IMAGE_TAG" "${ARK_IMAGE_TAG:-$SCANNER_VERSION}"
add_env "ARK_IMAGE_DIGEST" "$IMAGE_DIGEST"

# -----------------------------------------------------------------------------
# ark-tools arguments.
# -----------------------------------------------------------------------------
ARGS=("$COMMAND")

IMAGE_INPUT="${ARK_IN_IMAGE:-}"
PATH_INPUT="$(to_container_path "${ARK_IN_PATH:-}")"
TARGET_INPUT="$(to_container_path "${ARK_IN_TARGET:-}")"
DOCKERFILE_INPUT="$(to_container_path "${ARK_IN_DOCKERFILE:-}")"

case "$COMMAND" in
  full-scan)
    if [ -n "$IMAGE_INPUT" ]; then
      ARGS+=("$IMAGE_INPUT")
    elif [ -z "${ARK_IN_FULL_SCAN_SKIP_IMAGE:-}" ] && [ -z "${FULL_SCAN_SKIP_IMAGE:-}" ]; then
      log "no image input:"
      add_env "FULL_SCAN_SKIP_IMAGE" "true"
    fi
    ARGS+=(--path "${PATH_INPUT:-$CONTAINER_WORKSPACE}")
    if [ "${ARK_IN_SBOM:-false}" = "true" ]; then
      ARGS+=(--sbom)
    fi
  ;;
  image-scan)
    [ -n "$IMAGE_INPUT" ] || die "the 'image' input is required for image-scan"
    if [ "${ARK_IN_SBOM:-false}" = "true" ]; then
      ARGS+=(--sbom)
    fi
    ARGS+=("$IMAGE_INPUT")
  ;;
  filesystem-scan)
    if [ "${ARK_IN_SBOM:-false}" = "true" ]; then
      ARGS+=(--sbom)
    fi
    ARGS+=("${PATH_INPUT:-$CONTAINER_WORKSPACE}")
  ;;
  config-scan)
    ARGS+=("${PATH_INPUT:-$CONTAINER_WORKSPACE}")
  ;;
  repo-scan)
    ARGS+=("${TARGET_INPUT:-$CONTAINER_WORKSPACE}")
  ;;
  dockerfile-lint)
    ARGS+=("${DOCKERFILE_INPUT:-$CONTAINER_WORKSPACE/Dockerfile}")
  ;;
  secret-scan)
    if [ "${ARK_IN_NO_GIT:-}" = "true" ]; then
      ARGS+=(--no-git)
    fi
    ARGS+=("${PATH_INPUT:-$CONTAINER_WORKSPACE}")
  ;;
esac

if [ -n "${ARK_IN_EXTRA_ARGS:-}" ]; then
  # Word splitting is intentional here (extra_args is a flag string, not one
  # argument) but pathname expansion is not: -f stops a value such as '*' from
  # expanding against the files in the repository.
  set -f
  # shellcheck disable=SC2206
  EXTRA=(${ARK_IN_EXTRA_ARGS})
  set +f
  ARGS+=(-- "${EXTRA[@]}")
fi

# Last, so that everything decided above is already in FORWARDED.
pass_job_env

# -----------------------------------------------------------------------------
# Run.
# -----------------------------------------------------------------------------
log "image:   $IMAGE_REF"
log "command: ark-tools ${ARGS[*]}"

exit_code=0
docker "${DOCKER_ARGS[@]}" "$IMAGE_REF" "${ARGS[@]}" || exit_code=$?

# Reports are written by the container user; hand them back to the runner so
# later steps (upload-artifact, custom parsing) can read and delete them.
if command -v sudo >/dev/null 2>&1; then
  sudo chown -R "$(id -u):$(id -g)" "$HOST_REPORTS" 2>/dev/null || true
fi

# Close the world-writable window the scan needed. Findings can be sensitive,
# and on a shared self-hosted runner another job could otherwise rewrite them.
chmod -R go-w "$HOST_REPORTS" 2>/dev/null || true

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  {
    printf 'exit-code=%s\n' "$exit_code"
    printf 'reports-dir=%s\n' "$HOST_REPORTS"
    printf 'report=%s\n' "$HOST_REPORTS/full-scan-report.json"
  } >>"$GITHUB_OUTPUT"
fi

log "reports in: $HOST_REPORTS"
log "exit code:  $exit_code"

if [ "$exit_code" -ne 0 ] && [ "${ARK_SOFT_FAIL:-false}" = "true" ]; then
  log "soft-fail is on; not failing the step"
  exit 0
fi

exit "$exit_code"
