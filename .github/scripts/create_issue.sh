#!/usr/bin/env bash
# Creates or updates a GitHub issue from a rendered template with YAML frontmatter.
#
# Usage: <rendered template> | create_issue.sh [ISSUE_NUMBER]
#   ISSUE_NUMBER: if provided, updates the existing issue instead of creating one.
#
# Frontmatter fields:
#   title: (required) Issue title
#   labels: (optional) Single string or YAML list
set -euo pipefail

ISSUE_NUMBER="${1:-}"
INPUT="$(cat)"

# Split frontmatter and body
FRONTMATTER=$(echo "$INPUT" | sed -n '/^---$/,/^---$/p' | sed '1d;$d')
BODY=$(echo "$INPUT" | sed '1,/^---$/d' | sed '1,/^---$/d')

# Extract title
TITLE=$(echo "$FRONTMATTER" | sed -n 's/^title: *//p')
if [ -z "$TITLE" ]; then
  echo "Error: missing 'title' in frontmatter" >&2
  exit 1
fi

# Extract labels — handle both "labels: foo" and "labels:\n- foo\n- bar"
LABELS=""
INLINE=$(echo "$FRONTMATTER" | sed -n 's/^labels: *\(.\+\)/\1/p')
if [ -n "$INLINE" ]; then
  LABELS=$(echo "$INLINE" | sed 's/, */,/g' | tr -d '"'"'")
else
  LIST=$(echo "$FRONTMATTER" | sed -n '/^labels:/,/^[^ -]/p' | grep '^  *- ' | sed 's/^ *- *//' | tr -d '"'"'" || true)
  if [ -n "$LIST" ]; then
    LABELS=$(echo "$LIST" | paste -sd, -)
  fi
fi

LABEL_ARGS=""
if [ -n "$LABELS" ]; then
  LABEL_ARGS="--label $LABELS"
fi

if [ -n "$ISSUE_NUMBER" ]; then
  # Update existing issue
  # shellcheck disable=SC2086
  gh issue edit "$ISSUE_NUMBER" --title "$TITLE" --body "$BODY" $LABEL_ARGS
else
  # Create new issue
  # shellcheck disable=SC2086
  gh issue create --title "$TITLE" --body "$BODY" $LABEL_ARGS
fi
