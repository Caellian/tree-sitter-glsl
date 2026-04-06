---
paths:
  - "extensions.js"
---

- Each key in the `EXTENSIONS` object in `extensions.js` is a Khronos extension name (e.g. `GL_EXT_...`).
- When adding an extension to `extensions.js`, use the `/add-extension` skill.
- See the `ExtensionEntry` typedef at the top of `extensions.js` for available fields.
- `grammarExtension` entries in `extensions.js` are rule builders merged into `grammar.js` via `collectExtensionRules()`. Inject them at appropriate `choice()` points in `grammar.js` using `extRule($, 'rule_name')`.
- Keep entries in `extensions.js` sorted alphabetically within their vendor group.
- After modifying `extensions.js`, run `node scripts/generate_highlights.js` to regenerate `queries/highlights.scm`.
