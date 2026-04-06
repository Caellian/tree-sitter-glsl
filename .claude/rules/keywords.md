---
paths:
  - "keywords.js"
---

- `keywords.js` contains core GLSL type and qualifier keyword tables, imported by `grammar.js` and expanded into `choice()` rules.
- Extension-added keywords do NOT go in `keywords.js` — they go in `extensions.js` under `typeKeywords`, `storageQualifiers`, etc.
- When adding a keyword to `keywords.js`, make sure it matches the spec token table in `specification/chapters/grammar.adoc`.
