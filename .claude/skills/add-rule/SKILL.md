---
name: add-rule
description: Adds a new grammar rule from GLSL specification.
---

Implement $ARGUMENTS BNF productions by referencing:
- Core grammar BNF: `specification/chapters/grammar.adoc`
- Extension specs: `specification/extensions/{vendor}/{extension}.txt`

1. **Collect dependencies** — for each listed production, inspect its BNF in the grammar document and recursively gather all rules it references. Skip any already implemented in grammar.js; reference them directly.

2. **Transform BNF to tree-sitter** — convert each production into a JavaScript rule definition in grammar.js. Simplify BNF patterns where tree-sitter has direct equivalents:
   - Left-recursive lists → `repeat()` / `repeat1()`
   - Alternations → `choice()`
   - Optional terms → `optional()`

3. **Cite the BNF** — add the original grammar notation in a ` ```bnf ``` ` block in the JSDoc comment above each rule.

4. **Place rules in the correct section** of `grammar.js`. Rules are organized by spec chapter:
   - `// ── Top-level ──` — `translation_unit`, `external_declaration`, `function_definition`
   - `// ── Expressions ──` — all expression precedence levels, function calls
   - `// ── Types ──` — `type`, `type_qualifier`, `type_specifier`, qualifiers
   - `// ── Structs ──` — `struct_specifier`, field declarations
   - `// ── Declarations ──` — `declaration`, `declarator_list`, `function_declarator`
   - `// ── Initializers ──` — `initializer`, `initializer_list`
   - `// ── Statements ──` — control flow, compound statements, jumps
   - `// ── Lexical ──` — literals, identifiers, comments
   - `// ── Preprocessor ──` — `#define`, `#if`, `#pragma`, etc.

   New type keywords go in `keywords.js`. New built-in names go in `builtin.js`. Extension-specific additions go in `extensions.js`. Only grammar productions go in `grammar.js`.

5. **No behavioral changes** — the grammar must accept exactly the same input the spec defines. Deviations are only allowed when they improve AST quality or tree-sitter ergonomics without changing the accepted language.

## Allowed deviations

These patterns are established throughout grammar.js. Follow them consistently:

### Hiding pass-through rules (prefix with `_`)

When a spec rule is a transparent wrapper (one alternative is just a pass-through to a child), make it hidden. This flattens the AST so consumers don't see pointless nesting.

- `_primary_expression`, `_postfix_expression`, `_unary_expression` — hidden; identifiers and literals appear directly in the tree without wrapper chains.
- `_expression`, `_assignment_expression`, `_conditional_expression` — hidden; the base case passes through, only the operator form surfaces as a visible node.
- `_external_declaration` — hidden so top-level items appear directly under `translation_unit`.
- `_constant_expression`, `_initializer`, `_declaration_statement` — 1:1 pass-throughs, hidden.
- `_statement_no_new_scope`, `compound_statement_no_new_scope` — identical to `statement`/`compound_statement` because tree-sitter doesn't enforce scoping; hidden.

**Rule:** if a spec production is `X : Y | Z` and one branch is just a pass-through to a child, make it `_x` (hidden) and let the meaningful branches be visible named nodes.

### Collapsing deep spec chains

When the spec uses multiple levels of indirection with no semantic content, collapse them into a single node.

- `function_call` collapses the 6-level chain: `function_call → function_call_or_method → function_call_generic → function_call_header_* → function_call_header → function_identifier`.
- `function_declarator` merges `function_prototype`, `function_declarator`, `function_header_with_parameters`, and `function_header` — the `(` `)` delimiters live in one node.
- `if_statement` inlines `selection_rest_statement`.
- `switch_statement` inlines `switch_statement_list`.

**Rule:** if the spec splits a construct across multiple productions only for parsing mechanics (not semantic grouping), collapse them. Cite all collapsed productions in one BNF block.

### Extracting named sub-nodes from hidden rules

When a hidden rule has multiple meaningful alternatives, extract each as a visible named node.

- `_postfix_expression` → `subscript_expression`, `field_expression`, `function_call`, `update_expression`
- `_unary_expression` → `unary_expression` (operator form), `update_expression` (prefix ++/--)
- Binary precedence ladder: each `_*_expression` has a hidden pass-through plus a `_*_operation` helper aliased to `binary_expression`.

**Rule:** the hidden parent holds the `choice()`; each branch with actual syntax (operators, delimiters) becomes a named node.

### Unifying aliased nodes

When the spec has separate syntactic forms that are semantically identical, alias them to one node type.

- `_postfix_update` and `_prefix_update` both alias to `update_expression`.
- All `_*_operation` helpers alias to `binary_expression`.
- `_subsequent_declarator` aliases to `declarator`.

### Renaming for clarity

Spec names are preserved where possible, but some are renamed to be more descriptive for AST consumers:

- `fully_specified_type` → `type`
- `struct_specifier` keeps its name, but `struct_declaration_list` → `field_declaration_list`, `struct_declaration` → `field_declaration`, `struct_declarator` → `field_declarator`
- `init_declarator_list` → `declarator_list`, `single_declaration` → `declarator`
- `selection_statement` → `if_statement`
- `integer_expression`, `variable_identifier`, `parameter_type_specifier`, `parameter_declarator` — inlined (not separate rules)
- `comma_expression` is extracted from `expression` as a visible node for the comma-operator form

### Adding `field()` labels

The spec BNF has no field names. Add them for AST ergonomics: `name`, `type`, `value`, `condition`, `consequence`, `alternative`, `left`, `right`, `operator`, `argument`, `function`, `arguments`, `field`, `index`, `return_type`, `parameters`, `instance_name`.

### OPT-gated extensions

Non-spec features are gated behind `OPT.*` flags and documented at the affected rules:
- `OPT.MACRO_PARSING` — preprocessor directives in struct/statement contexts
- `OPT.MACRO_EXPANSION` — unexpanded macros as types/qualifiers/expressions
- `OPT.MULTILINGUAL` — `#ifdef __cplusplus` language guards
- `OPT.ESSL` — restricts to OpenGL ES subset
- Extension rules from `extensions.js` are injected via `extRule($, name)`

**Rule:** never add non-spec syntax without an OPT gate or extension entry.

## Example

A rule with hidden pass-through, visible named node, BNF citation, and field labels:

```js
/**
 * ```bnf
 * conditional_expression :
 *     logical_or_expression
 *     logical_or_expression QUESTION expression COLON
 *     assignment_expression
 * ```
 *
 * @param {GrammarSymbols<string>} $
 */
_conditional_expression: ($) =>
  choice($._logical_or_expression, $.conditional_expression),

/**
 * Tree-sitter compromise: visible conditional node only when `?:`
 * is present; the spec base case stays hidden in _conditional_expression.
 *
 * @param {GrammarSymbols<string>} $
 */
conditional_expression: ($) =>
  prec.right(
    PRECEDENCE.CONDITIONAL,
    seq(
      field('condition', $._logical_or_expression),
      '?',
      field('consequence', $._expression),
      ':',
      field('alternative', $._assignment_expression),
    ),
  ),
```
