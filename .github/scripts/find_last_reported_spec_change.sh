#!/usr/bin/env bash
# Finds the most recent open issue with label "specification" and extracts
# the TARGET_SHA_LONG from the compare URL pattern in the body.
#
# Output (stdout):
#   <issue_number> <target_sha>    — if found
#   (empty)                        — if no matching issue
#
# Requires: gh (GitHub CLI), GH_TOKEN in env
set -euo pipefail

BODY=$(gh issue list --label specification --state open --limit 1 --json number,body --jq '.[0] // empty')

if [ -z "$BODY" ]; then
  exit 0
fi

NUMBER=$(echo "$BODY" | jq -r '.number')
TARGET=$(echo "$BODY" | jq -r '.body' | grep -oP 'KhronosGroup/GLSL/compare/[0-9a-f]+\.\.\.\K[0-9a-f]+' || true)

if [ -n "$TARGET" ]; then
  echo "$NUMBER $TARGET"
fi
