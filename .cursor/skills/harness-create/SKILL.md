---
name: harness-create
description: >-
  Bootstraps the one-shot spec in /docs (DOC mode of documentation-harness):
  brief, architecture, models, features with the user's 4 answers, contracts,
  non-negotiables, discretion, CHANGELOG, and installs docs-pointer plus
  default-architecture. Use when starting a project or creating /docs.
  Brownfield with existing code prefers legacy-explainer first when present.
disable-model-invocation: true
---

# Harness create

This skill **is** DOC mode of [`documentation-harness`](../documentation-harness/SKILL.md). Do not write `docs/harness/` for new bootstraps — the spec is `/docs`.

When invoked:

1. Read and follow **DOC mode** in `documentation-harness/SKILL.md`.
2. Use `documentation-harness/templates.md` (do not invent sections). Follow `default-architecture` and `quality-gate`.
3. BUILD and SYNC stay on `documentation-harness`.

If `/docs` already exists and is filled, do not overwrite without a diff and explicit confirmation. Offer SYNC or a new feature file instead.
