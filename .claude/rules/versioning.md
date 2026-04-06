---
paths:
  - package.json
  - package-lock.json
  - Cargo.toml
  - Cargo.lock
  - pyproject.toml
  - Makefile
  - CMakeLists.txt
  - tree-sitter.json
  - .github/workflows/publish.yml
---

- `tree-sitter.json` and git tags are the source of truth for version.
- Registry versions (npm, crates, PyPI) are injected from the git tag by `.github/workflows/publish.yml`.
- `package.json`, `Cargo.toml`, and `pyproject.toml` contain `0.0.0-dev` placeholders — never update them manually.
- `Makefile` and `CMakeLists.txt` read the version from `tree-sitter.json` at build time.
