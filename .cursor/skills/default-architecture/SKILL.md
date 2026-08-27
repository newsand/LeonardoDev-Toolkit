---
name: default-architecture
description: >-
  Default system shape for implementation: named operations (command/query/job),
  modular monolith, schema-first, cheap-to-change code. Use when writing /docs
  architecture, choosing structure, or deciding whether to add a layer or
  abstraction.
---

# Default architecture

The system is organized around **named operations** (`create_user`, `list_orders`, `approve_payment`), not around entities or horizontal layers (`domain/`, `infra/`, `usecase/`). Do not use MVC, Clean, Hexagonal, DDD, or CQRS as the default skeleton.

## Prefer (cheap to change, cheap in tokens)

Modular monolith. Transaction Script or a short pipeline. Plain functions. Schema-first (types and validation in one place). Local query object / SQL next to the operation. Active Record or table-driven rules when data and behavior stay together. Facade only when it hides real complexity. Configuration object instead of scattered conditionals.

## Avoid by default (expensive)

Microservices, event sourcing, full CQRS, heavy Clean/Hexagonal, DI containers, generic repositories, duplicated DTO/Entity/ViewModel stacks, factories that only add indirection, MVC as the project skeleton, empty pass-through services, a dumping-ground `shared`/`helpers`/`utils` package.

## Before you abstract

Answer all five. If the abstraction fails any, keep the logic inline.

- Does it remove real duplication, or only look elegant?
- Does it shorten or lengthen the main operation?
- Does it improve locality or spread behavior?
- Does it reduce change risk or add coupling?
- Is it stable enough to become structure?

## When SQL vs module vs inline

- **Inline** until duplication is real and the five questions pass.
- **Direct SQL / local query object** when the query *is* the behavior — do not hide it behind a generic repository.
- **Shared module** only for a stable capability used by two or more operations.
- **Subfolders inside a feature** when that feature's operations no longer fit one file without hurting locality.
- Lateral dependency that became a long linear chain → flatten; do not add a layer to hide it.

## Contracts

- HTTP (or other entry) uses an explicit schema.
- Command returns an explicit result. Query returns an explicit projection.
- Internal exceptions do not leak raw to clients.
- Side effects are visible in the operation (no hidden I/O).
- Spell out: validation, errors, serialization, idempotency, timeout/cancel, retries, payload versioning.

## Consistency

- Command has a clear transaction boundary.
- Query has no side effects.
- External I/O stays outside long transactions (outbox, retry, or compensation for critical side effects).
- Define atomicity, concurrency, double-execution, and races per command.

## Observability

Per operation: structured logs, correlation/request id, timing, failure points. Never log secrets, tokens, or raw PII. The system must answer: which endpoint is slow, which query is heavy, where this command failed, did it double-run, which integration is blocking.

## Tests (aligned with this shape)

- Pure logic → unit tests.
- Real queries → integration tests against a real (ephemeral) database.
- Critical commands → transactional integration tests.
- Few high-value end-to-end tests on the main path.
- Do not mock central infrastructure by default.

## Grow complexity only when

Recurring latency, a clear hotspot, higher concurrency, frequent change conflicts, need for operational isolation, an unstable external dependency, or the domain outgrew acceptable locality. Until then, keep operations small and local.

## Implementation phases

Spec lives in `/docs`. Code is produced in TDD phases: Red (`tester`) → `docs/tdd/fase{N}.md` + `fase{N}Task.md` → Green (`coder`) → Refactor → Verify. No Green without the Red handoff.
