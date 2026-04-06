#!/usr/bin/env bash
set -euo pipefail

cd specification
git fetch origin

LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse origin/main)

SHORT=$(git rev-parse --short HEAD)
if [ "$LOCAL" = "$REMOTE" ]; then
  echo "STOP: Specification submodule is already at \`$SHORT\`. Nothing to do."
  echo "You MUST ignore the rest of the instructions. ONLY tell the user the GLSL specification is up to date at \`$SHORT\`."
  exit 0
fi

REMOTE_SHORT=$(git rev-parse --short "$REMOTE")
echo "Specification submodule updated from \`$SHORT\` to \`$REMOTE_SHORT\` and staged. Review the changes below."
echo

echo "## All changed files"
git diff --name-only "$LOCAL" "$REMOTE" | sed 's/^/- /'
echo

echo "## Specification Changes"
CHAPTERS=$(git diff --name-only "$LOCAL" "$REMOTE" | grep '^chapters/' || true)
GRAMMAR_CHANGED=$(echo "$CHAPTERS" | grep '^chapters/grammar.adoc$' || true)
OTHER_CHAPTERS=$(echo "$CHAPTERS" | grep -v '^chapters/grammar.adoc$' | grep '.' || true)

if [ -n "$GRAMMAR_CHANGED" ]; then
  # Extract BNF production names (lines like "_production_name_ : ::")
  # from old and new versions, then diff them
  OLD_PRODS=$(git show "$LOCAL:chapters/grammar.adoc" | grep -oP '(?<=^_)[a-z_]+(?=_ : ::)' | sort)
  NEW_PRODS=$(git show "$REMOTE:chapters/grammar.adoc" | grep -oP '(?<=^_)[a-z_]+(?=_ : ::)' | sort)

  ADDED=$(comm -13 <(echo "$OLD_PRODS") <(echo "$NEW_PRODS"))
  REMOVED=$(comm -23 <(echo "$OLD_PRODS") <(echo "$NEW_PRODS"))

  # For changed: productions present in both but with different content
  COMMON=$(comm -12 <(echo "$OLD_PRODS") <(echo "$NEW_PRODS"))
  CHANGED=""
  for prod in $COMMON; do
    OLD_BLOCK=$(git show "$LOCAL:chapters/grammar.adoc" | sed -n "/^_${prod}_ : ::/,/^$/p")
    NEW_BLOCK=$(git show "$REMOTE:chapters/grammar.adoc" | sed -n "/^_${prod}_ : ::/,/^$/p")
    if [ "$OLD_BLOCK" != "$NEW_BLOCK" ]; then
      CHANGED="$CHANGED $prod"
    fi
  done
  CHANGED=$(echo "$CHANGED" | xargs)

  echo "### grammar.adoc"
  echo

  if [ -n "$ADDED" ]; then
    echo "The following BNF productions were **added** and require new rules. Use \`/add-rule\` to implement them:"
    echo "$ADDED" | sed 's/^/- /'
    echo
  fi

  if [ -n "$CHANGED" ]; then
    echo "The following BNF productions were **changed** and need to be updated:"
    echo "$CHANGED" | tr ' ' '\n' | sed 's/^/- /'
    echo
  fi

  if [ -n "$REMOVED" ]; then
    echo "The following BNF productions were **removed** — verify and remove the corresponding rules:"
    echo "$REMOVED" | sed 's/^/- /'
    echo
  fi

  if [ -z "$ADDED" ] && [ -z "$CHANGED" ] && [ -z "$REMOVED" ]; then
    echo "grammar.adoc changed but no BNF production differences detected (likely comments or formatting only)."
    echo
  fi
fi

if [ -n "$OTHER_CHAPTERS" ]; then
  echo "### Other chapter changes"
  echo "Review the diffs below and consider whether they affect the grammar, keywords, or builtins (\`grammar.js\`, \`keywords.js\`, \`builtin.js\`)."
  echo
  for ch in $OTHER_CHAPTERS; do
    echo "#### $ch"
    echo '```diff'
    git diff "$LOCAL" "$REMOTE" -- "$ch"
    echo '```'
    echo
  done
fi

if [ -z "$CHAPTERS" ]; then
  echo "No chapter changes, you can ignore this section."
fi
echo

echo "## Changed extension files"
EXT_FILES=$(git diff --name-only "$LOCAL" "$REMOTE" | grep '^extensions/' || true)
if [ -n "$EXT_FILES" ]; then
  # Separate added vs modified
  ADDED_EXTS=$(git diff --name-only --diff-filter=A "$LOCAL" "$REMOTE" | grep '^extensions/' | sed 's|.*/||; s|\.txt$||' || true)
  MODIFIED_EXTS=$(git diff --name-only --diff-filter=M "$LOCAL" "$REMOTE" | grep '^extensions/' || true)

  if [ -n "$ADDED_EXTS" ]; then
    echo "Use \`/add-extension\` to add the following new extensions:"
    echo "$ADDED_EXTS" | sed 's/^/- /'
    echo
  fi

  if [ -n "$MODIFIED_EXTS" ]; then
    echo "The following extensions were **modified**. Review the diffs and update their entries in \`extensions.js\` accordingly:"
    echo
    for ext in $MODIFIED_EXTS; do
      NAME=$(echo "$ext" | sed 's|.*/||; s|\.txt$||')
      echo "#### $NAME"
      echo '```diff'
      git diff "$LOCAL" "$REMOTE" -- "$ext"
      echo '```'
      echo
    done
  fi
else
  echo "No extension changes, you can ignore this section."
fi
echo

# Update submodule and stage
git merge --ff-only origin/main --quiet
cd ..
git add specification
