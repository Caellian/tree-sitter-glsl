---
paths:
  - "grammar.js"
---

- When adding rules to `grammar.js`, use the `/add-rule` skill.
- Type keywords (e.g. `vec3`, `sampler2D`) are defined in `keywords.js`, not in `grammar.js`. Extension-added type keywords go in `extensions.js` under `typeKeywords`.
- Built-in function/variable/constant names belong in `builtin.js` or `extensions.js`, not in `grammar.js`.
- Extension-specific grammar rules live in `extensions.js` under `grammarExtension` and are injected into `grammar.js` via `extRule($, 'rule_name')`.
- The `OPT` object in `grammar.js` controls feature gates. Non-spec syntax ALWAYS requires an `OPT` gate or an `extensions.js` entry.
