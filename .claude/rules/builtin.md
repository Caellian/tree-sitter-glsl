---
paths:
  - "builtin.js"
---

- `builtin.js` contains core GLSL built-in function, variable, and constant name tables.
- `builtin.js` is used by `scripts/generate_highlights.js` to produce `queries/highlights.scm`.
- Extension-added builtins do NOT go in `builtin.js` — they go in `extensions.js` under `functionNames`, `variableNames`, `constantNames`.
- After modifying `builtin.js`, run `node scripts/generate_highlights.js` to regenerate `queries/highlights.scm`.
