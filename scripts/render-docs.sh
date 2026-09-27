#!/usr/bin/env bash
# =============================================================================
# Renders the onboarding guide: copies docs/ to an output directory and fills
# every {{PLACEHOLDER}} in its HTML with the value VERSION declares, so a
# version bump is an edit to VERSION and nothing else.
#
#   ./scripts/render-docs.sh            # writes _site/
#   ./scripts/render-docs.sh out/dir    # writes out/dir/
#
# Every KEY=value in VERSION is a placeholder. Three more are derived from it:
#
#   COMPONENT_MAJOR   the floating vMAJOR tag         (1.2.0 -> 1)
#   COMPONENT_MINOR   the floating vMAJOR.MINOR tag   (1.2.0 -> 1.2)
#   SCANNER_RELEASE   SCANNER_VERSION padded to MAJOR.MINOR.PATCH (1.10 ->
#                     1.10.0), the form Tooark/base-images names its releases
#
# A placeholder with no value fails the render instead of shipping "{{...}}" to
# readers. Only UPPER_SNAKE names count, so the GitHub Actions expressions the
# guide quotes -- ${{ inputs.image }} -- are left alone.
#
# Pages publishes the output (.github/workflows/pages.yml) and check-sync.sh
# checks it. Opening docs/index.html directly shows the raw placeholders.
# =============================================================================
set -euo pipefail

cd "$(dirname "$0")/.."

out="${1:-_site}"

names=()
values=()

while IFS='=' read -r key value; do
  key="${key%$'\r'}"
  value="${value%$'\r'}"
  case "$key" in
    '' | '#'*) continue ;;
  esac
  if [[ ! $key =~ ^[A-Z][A-Z0-9_]*$ ]]; then
    printf 'VERSION: %s is not an UPPER_SNAKE key\n' "$key" >&2
    exit 1
  fi
  names+=("$key")
  values+=("$value")
done < VERSION

lookup() {
  local i
  for i in "${!names[@]}"; do
    if [ "${names[$i]}" = "$1" ]; then
      printf '%s' "${values[$i]}"
      return 0
    fi
  done
  printf 'VERSION is missing %s\n' "$1" >&2
  return 1
}

component="$(lookup COMPONENT_VERSION)"
scanner="$(lookup SCANNER_VERSION)"

case "$scanner" in
  *.*.*) scanner_release="$scanner" ;;
  *.*) scanner_release="$scanner.0" ;;
  *) scanner_release="$scanner.0.0" ;;
esac

names+=(COMPONENT_MAJOR COMPONENT_MINOR SCANNER_RELEASE)
values+=("${component%%.*}" "${component%.*}" "$scanner_release")

# One sed expression per placeholder. The value is escaped for the replacement
# side: SCANNER_IMAGE alone carries slashes, and nothing stops a future value
# from carrying the delimiter or an ampersand.
sed_args=()
for i in "${!names[@]}"; do
  value="${values[$i]}"
  value="${value//\\/\\\\}"
  value="${value//|/\\|}"
  value="${value//&/\\&}"
  sed_args+=(-e "s|{{${names[$i]}}}|${value}|g")
done

mkdir -p "$out"
cp -R docs/. "$out"/

# A temporary file rather than sed -i, whose syntax differs between GNU and BSD.
while IFS= read -r -d '' file; do
  sed "${sed_args[@]}" "$file" > "$file.tmp"
  mv "$file.tmp" "$file"
done < <(find "$out" -type f -name '*.html' -print0)

if leftovers="$(grep -rnoE '\{\{[A-Z][A-Z0-9_]*\}\}' --include='*.html' "$out")"; then
  # Rendering keeps every line where it was, so point at the source file.
  printf 'placeholders with no value in VERSION:\n%s\n' "${leftovers//"$out"\//docs/}" >&2
  exit 1
fi

printf 'rendered docs/ into %s\n' "$out"
