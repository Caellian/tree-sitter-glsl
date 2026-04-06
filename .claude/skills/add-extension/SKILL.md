---
name: add-extension
description: Adds a GLSL extension to the parser.
allowed-tools: Bash(echo *), Bash(sed *), Bash(xargs *)
---

Implement following extension(s):
```!
echo "$ARGUMENTS" | sed 's/[, ]\+/\n/g' | xargs -I{} find specification/extensions -name '{}.txt' | sed 's/^/- /'
```

## Steps

1. **Read the extension spec** — identify what it adds: types, functions, variables, constants, keywords, qualifiers, attributes, and/or new grammar productions.

2. **Add an entry to `extensions.js`** — add a new key to the `EXTENSIONS` object, sorted alphabetically within its vendor group. Use the `ExtensionEntry` typedef fields:
   - `typeNames` — built-in type-like names (for highlight queries)
   - `variableNames` — built-in variable names
   - `constantNames` — built-in constant names
   - `functionNames` — built-in function names
   - `definedMacros` — macro aliases with highlight capture role
   - `typeKeywords` — type keywords to add to the grammar's `type_specifier_nonarray`
   - `storageQualifiers` — storage qualifier keywords
   - `precisionQualifiers` — precision qualifier keywords
   - `interpolationQualifiers` — interpolation qualifier keywords
   - `attributes` — layout attribute keywords
   - `includes` — other extension keys whose identifiers this extension includes
   - `grammarExtension` — tree-sitter rule builders for new syntax (see below)

3. **Grammar rules** (only if the extension adds new syntax) — add rule builders to `grammarExtension`. These get merged into `grammar.js` via `collectExtensionRules()`. Inject them into existing rules using `extRule($, 'rule_name')` at the appropriate injection point as specified by the extension document (e.g. `simple_statement` for new statement types).

4. **Regenerate highlights** — if new builtins were added, run `node scripts/generate_highlights.js` to update `queries/highlights.scm`.

5. **Add tests** — add test cases to the corpus in `test/corpus/` covering the new syntax.

## Example: extension with new syntax

```js
// extensions.js
GLSL_EXT_demote_to_helper_invocation: {
  grammarExtension: {
    // Injection: simple_statement
    demote_statement: (_) => seq('demote', ';'),
  },
  functionNames: ['helperInvocationEXT'],
},
```

```js
// grammar.js — injection point in simple_statement
simple_statement: ($) =>
  choice(
    $.expression_statement,
    // ...
    ...extRule($, 'demote_statement'),
  ),
```

## Example: extension with only builtins

```js
// extensions.js
GL_EXT_expect_assume: {functionNames: ['assumeEXT', 'expectEXT']},
```

No grammar changes needed — the names are picked up by `highlights.in` during generation.
