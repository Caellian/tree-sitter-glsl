#!/usr/bin/env bash
# Generates release notes for a tag by comparing against the previous tag.
#
# Usage: release_notes.sh <tag>
#   Outputs markdown to stdout.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TAG="${1:?Usage: $0 <tag>}"
REPO_URL="${GITHUB_REPOSITORY:+https://github.com/$GITHUB_REPOSITORY}"
REPO_URL="${REPO_URL:-$(git remote get-url origin 2>/dev/null | sed 's/\.git$//' | sed 's|git@github.com:|https://github.com/|')}"
PREV=$(git tag --sort=-v:refname | grep '^v' | sed -n '2p' || true)
RANGE="${PREV:+$PREV..}$TAG"

# ── AST changes ─────────────────────────────────────────────────────────

if [ -n "$PREV" ]; then
  OLD_JSON=$(mktemp)
  NEW_JSON=$(mktemp)
  trap 'rm -f "$OLD_JSON" "$NEW_JSON"' EXIT

  git show "$PREV:src/node-types.json" > "$OLD_JSON" 2>/dev/null || true
  git show "$TAG:src/node-types.json" > "$NEW_JSON" 2>/dev/null || true

  if [ -s "$OLD_JSON" ] && [ -s "$NEW_JSON" ]; then
    AST_DIFF=$(node "$SCRIPT_DIR/diff_node_types.js" "$OLD_JSON" "$NEW_JSON" || true)
    if [ -n "$AST_DIFF" ]; then
      echo "## AST changes"
      echo
      echo "$AST_DIFF"
      echo
    fi
  fi
fi

# ── Extensions ──────────────────────────────────────────────────────────

EXT_DIFF=$(git diff --name-only $RANGE -- extensions.js 2>/dev/null || true)
if [ -n "$EXT_DIFF" ]; then
  ADDED_EXTS=$(git diff $RANGE -- extensions.js | grep -oP '^\+  \K[A-Z][A-Z_a-z0-9]+(?=:)' || true)
  REMOVED_EXTS=$(git diff $RANGE -- extensions.js | grep -oP '^-  \K[A-Z][A-Z_a-z0-9]+(?=:)' || true)

  if [ -n "$ADDED_EXTS" ]; then
    echo "## New extensions"
    echo
    echo "$ADDED_EXTS" | sed 's/^/- `/' | sed 's/$/`/'
    echo
  fi

  if [ -n "$REMOVED_EXTS" ]; then
    echo "## Removed extensions"
    echo
    echo "$REMOVED_EXTS" | sed 's/^/- `/' | sed 's/$/`/'
    echo
  fi
fi

# ── Keywords ────────────────────────────────────────────────────────────

KW_DIFF=$(git diff $RANGE -- keywords.js 2>/dev/null || true)
if [ -n "$KW_DIFF" ]; then
  ADDED_KW=$(echo "$KW_DIFF" | grep -oP "^\+\s+'\K[a-zA-Z_][a-zA-Z0-9_]*(?=')" || true)
  REMOVED_KW=$(echo "$KW_DIFF" | grep -oP "^-\s+'\K[a-zA-Z_][a-zA-Z0-9_]*(?=')" || true)

  if [ -n "$ADDED_KW" ] || [ -n "$REMOVED_KW" ]; then
    echo "## Keyword changes"
    echo
    if [ -n "$ADDED_KW" ]; then
      echo "Added:"
      echo "$ADDED_KW" | sed 's/^/- `/' | sed 's/$/`/'
    fi
    if [ -n "$REMOVED_KW" ]; then
      echo "Removed:"
      echo "$REMOVED_KW" | sed 's/^/- `/' | sed 's/$/`/'
    fi
    echo
  fi
fi

# ── Builtins ────────────────────────────────────────────────────────────

BUILTIN_DIFF=$(git diff $RANGE -- builtin.js 2>/dev/null || true)
if [ -n "$BUILTIN_DIFF" ]; then
  ADDED_BI=$(echo "$BUILTIN_DIFF" | grep -oP "^\+\s+'\K[a-zA-Z_][a-zA-Z0-9_]*(?=')" || true)
  REMOVED_BI=$(echo "$BUILTIN_DIFF" | grep -oP "^-\s+'\K[a-zA-Z_][a-zA-Z0-9_]*(?=')" || true)

  if [ -n "$ADDED_BI" ] || [ -n "$REMOVED_BI" ]; then
    echo "## Built-in changes"
    echo
    if [ -n "$ADDED_BI" ]; then
      echo "Added:"
      echo "$ADDED_BI" | sed 's/^/- `/' | sed 's/$/`/'
    fi
    if [ -n "$REMOVED_BI" ]; then
      echo "Removed:"
      echo "$REMOVED_BI" | sed 's/^/- `/' | sed 's/$/`/'
    fi
    echo
  fi
fi

# ── Queries ─────────────────────────────────────────────────────────────

QUERY_DIFF=$(git diff --name-only $RANGE -- 'queries/*.scm' 2>/dev/null || true)
if [ -n "$QUERY_DIFF" ]; then
  echo "## Query changes"
  echo
  echo "$QUERY_DIFF" | sed 's|queries/||' | sed 's/^/- /'
  echo
fi

# ── Merged PRs ──────────────────────────────────────────────────────────

if [ -n "$PREV" ]; then
  AFTER=$(git log -1 --format=%aI "$PREV")
  BEFORE=$(git log -1 --format=%aI "$TAG")
  PRS=$(gh pr list --state merged --base main \
    --json number,title,mergedAt,author \
    --jq "[.[] | select(.mergedAt > \"$AFTER\" and .mergedAt <= \"$BEFORE\")] | sort_by(.number) | .[] | \"\(.number)\t\(.title)\t\(.author.login)\"" 2>/dev/null || true)
  if [ -n "$PRS" ]; then
    echo "## Merged pull requests"
    echo
    echo "$PRS" | while IFS=$'\t' read -r num title author; do
      echo "- ${title} ([#${num}](${REPO_URL}/pull/${num})) by @${author}"
    done
    echo
    echo "Thank you<sup>\*</sup> for contributing!"
    echo "<sup>\* - machine generated appraisal</sup>"
    echo
  fi
fi

# ── Commits ─────────────────────────────────────────────────────────────

echo "## Commits"
echo
git log --pretty=format:"- %s ([%h](${REPO_URL}/commit/%H))" $RANGE --no-merges
echo
