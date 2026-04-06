---
name: update-spec
description: Updates the GLSL specification submodule and reports changes.
allowed-tools: Bash(git *), Bash(bash *)
---

```!
bash .claude/skills/update-spec/scripts/check.sh
```

If only non-grammar files changed (e.g. `BUILD.adoc`, `README.adoc`, `LICENSE.adoc`), report that the spec was updated but no parser changes are needed.
