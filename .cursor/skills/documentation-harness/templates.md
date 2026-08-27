# `/docs` layout and templates

One file per feature (never a monolith). Implementation unit = **named operation**, not controller/service/repository layers.

```
/docs
  00-brief.md
  01-architecture.md
  02-data-models.md
  03-features/
    feature-auth.md
  04-contracts.md
  05-non-negotiables.md
  06-discretion.md
  CHANGELOG.md
```

Do not invent sections. Use `TBD:` instead of fabricating a business rule. Follow `default-architecture` and `quality-gate` skills.

## `00-brief.md`

```markdown
# Project: [name]

## Goal in one paragraph
[what it does, for whom, why]

## Mandatory stack
- Language/framework: ...
- Database: ...
- Libraries already decided (do not pick others): ...

## Architecture
Modular monolith + named operations (command/query/job). Not MVC / Clean / Hexagonal / DDD / CQRS by default.

## Non-goals
- Does NOT need ...
```

## `01-architecture.md`

```markdown
## Unit
Named operation (command / query / job): `create_user`, `list_orders`, `approve_payment`.
Not a layer, not an entity.

## Prefer (cheap to change)
Modular monolith. Transaction Script or short pipeline. Plain functions. Schema-first.
Local query object / SQL. Facade only if it hides real complexity.
Active Record or table-driven when data and behavior stay together.

## Avoid by default (expensive)
Microservices, event sourcing, full CQRS, heavy Clean/Hexagonal, DI container,
generic repository, duplicated DTO/Entity/ViewModel, needless factory, MVC as skeleton.

## Before abstracting
- real duplication or only elegance?
- shorter or longer main path?
- better locality or spread behavior?
- less risk or more coupling?
- stable enough to become structure?

## Folder tree
[real tree by operation — not domain/infra/usecase]

## One operation (example)
[HTTP/schema → command|query → effect/projection → response]
Command: clear transaction. Query: no side effects. External I/O outside long transactions.

## Boundaries
- HTTP enters through an explicit schema
- command/query return explicit results
- internal exceptions do not leak raw
- side effects are visible in the operation

## Consistency
- what is atomic; where the transaction opens/closes
- idempotency / retries / timeout
- concurrency and double execution

## Observability
correlation id; structured logs per operation; timing/failure metrics; what NEVER to log (secrets/PII)

## Evolution (when abstraction is no longer premature)
recurring latency, hotspot, concurrency, change conflicts, operational isolation,
unstable external dependency, domain larger than acceptable locality
```

## `02-data-models.md`

Schema-first: type and validation in one place. Explicit edges (null / empty / duplicate).

```markdown
## User
| field | type | required | rule |
|---|---|---|---|
| email | string | yes | unique, lowercase before save |
```

## `03-features/feature-{name}.md`

The 4 answers are **verbatim from the user**. Operations are the feature's spine.

```markdown
# Feature: {Name}

## 4 answers (user)
1. How do you describe the feature?
> [verbatim]
2. What problem does it objectively solve?
> [verbatim]
3. What is the expected solution? What trade-offs does it involve?
> [verbatim]
4. What example or context do we have of the problem and the solution?
> [verbatim]

## Depends on
- feature-{other} (why)

## Operations
| name | kind | does |
|---|---|---|
| create_user | command | ... |
| list_users | query | ... |

## Description / Problem / Solution and trade-offs
[from answers 1–3]

## Flow (given/when/then) per operation
- Given ... When ... Then ...

## Error cases
- [failure] → [behavior]

## Acceptance
- [ ] Unit: pure logic
- [ ] Integration: critical query/command (real DB if the feature touches persistence)
- [ ] Failure does not corrupt state
- E2E only on the high-value main path. No mocking of central infra.

## Example / context
[answer 4]

## Patterns (only if cheap to change)
- [Transaction Script, pipeline, facade, query object, table-driven — not GoF for fashion]
```

## `04-contracts.md`

Per operation/route: input, output, errors, idempotency if command.

```markdown
POST /users  → create_user
Request: { email: string }
Response 200: { id: string }
Response 409: { error: "email_already_exists" }
Idempotency: ...
```

## `05-non-negotiables.md`

```markdown
## Cost and abstraction
- Prefer the cheap list; forbid the expensive list by default (`default-architecture` skill).
- No generic repository, no empty layers, no `shared`/`helpers` dump.

## Quality gate
- Lefthook orchestrates pre-commit/pre-push
- Python: Ruff check. JS/TS: Biome. Secrets: Gitleaks.
- Coverage measured; baseline in `quality-baseline.json` when the gate exists
- Push/CI fails if the gate is red

## Tests
- TDD phases: Red → `docs/tdd/fase{N}.md` + `fase{N}Task.md` → Green → Refactor → Verify
- Acceptance lives in `/docs/03-features` and `/docs/04-contracts` — phases do not invent behavior
- Pure → unit. Real query → DB integration. Critical command → transactional.
- Few E2E. Existing tests immutable (persisted-tester).

## Data
- schema-first; command with transaction; query with no side effects
- External I/O outside long transactions

## Security
- never log passwords, tokens, cards
- no new dependency unless listed in 00-brief.md
```

## `06-discretion.md`

```markdown
- internal names and files inside an operation
- helper library compatible with the stack
- user-facing error messages (clear)
```

## `CHANGELOG.md`

```markdown
## [YYYY-MM-DD] Build / Sync

### Built
- operation/feature ... (order)

### Decisions outside the spec
- [gap] → [decision]

### Spec deviations
- None | ...

### Known follow-ups
- ...
```
