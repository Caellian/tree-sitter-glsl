---
title: Specification changed
labels: specification
---

Automation workflow detected a drift from currently pinned specification ([`{{BASE_SHA}}`](https://github.com/KhronosGroup/GLSL/commit/{{BASE_SHA_LONG}})) and upstream ([`{{TARGET_SHA}}`](https://github.com/KhronosGroup/GLSL/commit/{{TARGET_SHA_LONG}})).

This signals you might need to update the grammar to account for these [changes](https://github.com/KhronosGroup/GLSL/compare/{{BASE_SHA_LONG}}...{{TARGET_SHA_LONG}}).

To dismiss these changes and fast-forward the pinned specification commit, use `/fast-forward`.

Any future drift will be merged into this issue automatically.
