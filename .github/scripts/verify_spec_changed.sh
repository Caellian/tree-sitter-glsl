#!/usr/bin/env bash
# Checks whether a specification submodule update contains meaningful
# grammar-affecting changes. Exits 0 if safe to auto-sync, 1 if manual
# review is needed.
#
# Usage: verify_spec_changed.sh [CHECK_BASE] [REMOTE]
#   CHECK_BASE: SHA to diff against for deciding if changes are meaningful.
#               Defaults to HEAD. When an existing issue reported up to some
#               SHA, pass that SHA so only NEW changes since then are checked.
#   REMOTE:     Upstream SHA to compare to. Defaults to origin/main.
#
# The rendered template always uses HEAD as BASE (the full span), regardless
# of CHECK_BASE.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd specification

HEAD_SHA="$(git rev-parse HEAD)"
CHECK_BASE="${1:-$HEAD_SHA}"
REMOTE="${2:-$(git rev-parse origin/main)}"

if [ "$CHECK_BASE" = "$REMOTE" ]; then
  echo "up-to-date"
  exit 0
fi

# Only these paths can contain grammar-affecting changes
WATCHED_PATHS=(
  'chapters/'
  'extensions/'
)

# Chapters that are prose-only (no grammar, keywords, or builtins)
IGNORED_CHAPTERS=(
  'chapters/acknowledgements.adoc'
  'chapters/introduction.adoc'
  'chapters/interfacematching.adoc'
  'chapters/iocounting.adoc'
  'chapters/overview.adoc'
  'chapters/preamble.adoc'
  'chapters/references.adoc'
  'chapters/spirvmappings.adoc'
)

# Diff patterns that are cosmetic, not semantic.
# grammar.adoc gets its own BNF extraction in check.sh so these only
# need to cover prose/formatting noise in other chapter files.
NOISE_PATTERNS=(
  # Copyright year bumps
  '^[-+]// Copyright'
  # SPDX headers
  '^[-+]// SPDX-'
  # Asciidoc comments
  '^[-+]// '
  # Asciidoc image directives (path refactors)
  '^[-+]image:'
  # Asciidoc section headings (=== Foo, ==== Bar)
  '^[-+]=+ '
  # Asciidoc block delimiters (--, ..., ****)
  '^[-+][-\.]{2,}$'
  '^[-+]\*{4,}$'
  # Asciidoc conditionals (ifdef/endif/ifndef)
  '^[-+](ifdef|endif|ifndef)::'
  # Asciidoc role/attribute markers ([role=, [cols=, etc.)
  '^[-+]\['
  # Asciidoc table rows
  '^[-+]\|'
  # Blank/whitespace-only lines
  '^[-+]$'
  '^[-+][[:space:]]*$'
  # Asciidoc cross-reference and attribute substitutions
  '^[-+]<<'
  # Asciidoc inline pass-through markup
  '^[-+]pass:\['
)

# Filter to only watched paths
WATCHED_PATTERN=$(printf '|^%s' "${WATCHED_PATHS[@]}")
WATCHED_PATTERN="${WATCHED_PATTERN:1}" # strip leading |
CHANGED=$(git diff --name-only "$CHECK_BASE" "$REMOTE" | grep -E "$WATCHED_PATTERN" || true)

# Remove ignored chapters
for ignored in "${IGNORED_CHAPTERS[@]}"; do
  CHANGED=$(echo "$CHANGED" | grep -v -F "$ignored" || true)
done
CHANGED=$(echo "$CHANGED" | grep '.' || true)

if [ -z "$CHANGED" ]; then
  echo "safe"
  exit 0
fi

# Normalize asciidoc markup to detect cosmetic-only rewrites
normalize() {
  sed -E \
    -e 's/pass:\[([^]]*)\]/\1/g' \
    -e 's/\{[a-zA-Z_]+\}//g' \
    -e 's/\*([^*]*)\*/\1/g' \
    -e 's/_([^_]*)_/\1/g' \
    -e 's/`([^`]*)`/\1/g' \
    -e 's/[[:space:]]+/ /g' \
    -e 's/^ //' -e 's/ $//'
}

# For each remaining file, check if the diff is only noise
MEANINGFUL=false
for file in $CHANGED; do
  # Extension files are always meaningful
  if [[ "$file" == extensions/* ]]; then
    MEANINGFUL=true
    break
  fi

  DIFF_LINES=$(git diff "$CHECK_BASE" "$REMOTE" -w -- "$file" \
    | grep '^[-+]' \
    | grep -v '^[-+][-+][-+]' \
    || true)

  FILTERED="$DIFF_LINES"
  for pat in "${NOISE_PATTERNS[@]}"; do
    FILTERED=$(echo "$FILTERED" | grep -v -E "$pat" || true)
  done

  if [ -z "$FILTERED" ]; then
    continue
  fi

  OLD_NORM=$(echo "$FILTERED" | grep '^-' | sed 's/^-//' | normalize | sort)
  NEW_NORM=$(echo "$FILTERED" | grep '^+' | sed 's/^+//' | normalize | sort)

  if [ "$OLD_NORM" != "$NEW_NORM" ]; then
    MEANINGFUL=true
    break
  fi
done

if [ "$MEANINGFUL" = false ]; then
  echo "safe"
  exit 0
fi

# Render issue template — always uses HEAD as base (full span)
BASE_SHA_SHORT=$(git rev-parse --short "$HEAD_SHA")
TARGET_SHA_SHORT=$(git rev-parse --short "$REMOTE")
TEMPLATE="$(cat "$REPO_ROOT/.github/templates/SPEC_CHANGE_ISSUE.md")"

echo "$TEMPLATE" \
  | sed "s/{{BASE_SHA}}/$BASE_SHA_SHORT/g" \
  | sed "s/{{BASE_SHA_LONG}}/$HEAD_SHA/g" \
  | sed "s/{{TARGET_SHA}}/$TARGET_SHA_SHORT/g" \
  | sed "s/{{TARGET_SHA_LONG}}/$REMOTE/g"

exit 1
