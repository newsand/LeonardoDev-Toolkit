---
name: documentation-harness
description: >-
  Plans, builds, and keeps the one-shot spec in /docs in sync (DOC, BUILD, SYNC
  modes). Named operations, modular monolith, schema-first, TDD phases
  (Red → fase{N} → Green). Use when the user asks to document/plan a project,
  build from /docs, or when code and /docs diverged.
---

# Documentation harness

Golden rule: **any ambiguity in the spec becomes a guaranteed bug in the output.** `/docs` is spec + dependency graph + acceptance + decision ledger — not project prose.

Before drafting `01-architecture.md` / `05-non-negotiables.md`, follow:

- `.cursor/skills/default-architecture/SKILL.md`
- `.cursor/skills/quality-gate/SKILL.md`

Do not default to MVC, Clean, Hexagonal, DDD, or CQRS.

**Sync:** a code change that alters `/docs` updates that doc in the same step. A `/docs` edit that requires new behavior needs a code plan and confirmation first.

Read [templates.md](templates.md) before creating or editing `/docs`. Do not invent sections.

Brownfield without `/docs`: `legacy-explainer` if present, then this skill. New spec is `/docs`, not `docs/harness/`.

## Triggers

- document / plan / specify → **DOC**
- build from complete `/docs` → **BUILD**
- build requested but `/docs` missing → **DOC** first
- `stop` hook / code↔docs drift → **SYNC**

## DOC mode

Do not write product code.

1. Extract what context already answers. Do not re-ask.
2. Draft `/docs` from [templates.md](templates.md).
3. Gaps → one batched AskQuestion (data edges, errors, dependencies, non-goals, transaction/idempotency per operation).
4. Features **one at a time**, 4 answers **verbatim from the user** (never invent). Without all 4 → pending, do not write the file.
5. Each feature lists **operations** (commands/queries/jobs) and I/O/error contracts.
6. Validate: 4 answers; `Depends on` points at existing files; testable acceptance; explicit errors; abstraction heuristic filled if extracting.
7. Checklist below. Install `docs-pointer.mdc` and `default-architecture.mdc` if missing.
8. State: "spec ready — BUILD when you want."

Do not overwrite a filled spec without a diff and confirmation.

## Spec vs implementation

| | System | Where |
|--|--------|--------|
| What to build | One-shot spec | `/docs` |
| How to build | TDD phases | `docs/tdd/fase{N}.md` + `fase{N}Task.md` |

BUILD reads `/docs` and runs **one phase at a time**: Red (`tester`) → handoff → Green (`coder`) → Refactor → Verify. No `fase{N}*` → no Green.

## BUILD mode

1. Read **all** of `/docs`.
2. Split `03-features/` operations into **phases**. One phase = one testable slice. Present `N, N+1, …` with the `/docs` cut for each.
3. Gap: covered by `06-discretion.md` → decide. Else conservative + `CHANGELOG.md`. No questions in BUILD.
4. **Each phase, in order** — do not skip; do not merge Red+Green in one step unless the user asked for both in the same message (handoff **before** any production code):
   1. **Red** (`tester` + `tester` skill): failing tests from acceptance/`04-contracts`; triangulation; confirm Red; write `docs/tdd/fase{N}.md` + `fase{N}Task.md` (context cites the `/docs` feature/operation).
   2. **Green** (`coder`): only the `fase{N}Task.md` checklist. Minimal code.
   3. **Refactor** (`refactor`) if the phase left an obvious smell — no behavior change.
   4. **Verify** (`tester`): re-run the phase tests; row in `docs/testsReadme.md`.
5. Then the next phase. Quality gate (Lefthook, check-only) at feature end. `CHANGELOG.md` + `graphify update .` if Graphify exists.

## SYNC mode

1. `git diff` (+ untracked).
2. Does it change contracts (`04`), models (`02`), a feature/operation (`03`), or promote `06-discretion`?
3. Yes → update the doc in the same step.
4. Unjustified contradiction → stop and ask.
5. Ledger in `CHANGELOG.md`. Origin = `/docs` → code plan + confirmation.

## Checklist (spec ready)

- [ ] Unit of design = named operation (not MVC/layers)
- [ ] Every operation has I/O, errors, and (if command) transaction/idempotency
- [ ] Features: errors + user's 4 answers + testable acceptance
- [ ] Fields: rules for missing/null/duplicate
- [ ] Feature dependencies declared
- [ ] `00-brief.md` has non-goals
- [ ] `06-discretion.md` covers small decisions
- [ ] Endpoints in `04-contracts.md`
- [ ] `05-non-negotiables.md` includes the quality gate (Lefthook, linter, gitleaks, coverage)
- [ ] `docs-pointer.mdc` + `default-architecture.mdc` installed
