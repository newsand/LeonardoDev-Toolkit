---
name: quality-gate
description: >-
  Sets up machine-level quality-gate CLIs and runs check-only Lefthook.
  Use when bootstrapping a project, adding pre-commit, installing lefthook,
  ruff, mypy, bandit, pip-audit, vulture, golangci-lint, biome, or gitleaks,
  or when reviewing / running the gate. SETUP installs to PATH (never project
  deps). RUN is scripts/check.sh. Check-only during review — do not auto-fix.
---

# Quality gate

Two modes. Never add these CLIs to `pyproject.toml` / `package.json` / `go.mod`.

| Mode | When | What |
|------|------|------|
| **SETUP** | User asked to set up the gate, or `project` after bootstrap (AskQuestion) | Install missing CLIs to user PATH; write thin repo configs; `lefthook install` only if the user wants git hooks |
| **RUN** | Review, “run the gate”, lefthook git hooks | `.cursor/skills/quality-gate/scripts/check.sh` — check-only, no `--fix` |

RUN never installs. Missing CLI or missing `lefthook.yml` → stop and point to SETUP.

## SETUP

Run from the **target repo** root:

```bash
.cursor/skills/quality-gate/scripts/setup.sh          # Linux/macOS
.cursor/skills/quality-gate/scripts/setup.ps1         # Windows
```

Flags: `--force` (overwrite existing configs), `--git-hooks` (`lefthook install`), `--with-radon` (or `QUALITY_GATE_RADON=1`).

Detect stacks (install only matches). Always Lefthook + Gitleaks.

| Signal | CLIs |
|--------|------|
| `pyproject.toml` / `uv.lock` / `*.py` | `uv tool install`: ruff, mypy, bandit, pip-audit, vulture; radon only if `--with-radon` |
| `package.json` | Biome (global/standalone, not `devDependency`) |
| `go.mod` / `*.go` | golangci-lint (one binary, not module deps) |

Skip a CLI if it is already on PATH. Need `uv` for the Python tools.

**Repo files** (skip if present unless `--force`): `lefthook.yml`, `quality-baseline.json`, plus stack configs below.

### Python

Generated `ruff.toml` enables lint **S** (flake8-bandit subset). Keep dedicated **Bandit** as well.

Lefthook `*.py`: `ruff check` (no `--fix`), `ruff format --check`, `mypy`, `bandit`, `vulture`. Lockfile/venv: `pip-audit` (`uv export --frozen | pip-audit -r -` or `--path .venv`).

**radon**: optional. Report only (`|| true` / exit 0). Never fails commit, push, or check.sh.

### Go

One CLI. Generated `.golangci.yml` is golangci-lint **v2**: `linters.default: none` and enable-only:

- govet, staticcheck (includes **gosimple** in v2), errcheck, unused, ineffassign, gosec, cyclop

Lefthook: blocking `golangci-lint run --disable=cyclop`; cyclop report job `golangci-lint run --default=none --enable=cyclop || true`. Cyclop never fails the gate.

### JS/TS

`biome check` (no `--write`).

### Coverage

Stays in the project env (pytest-cov, jest `--coverage`, `go test -cover`). SETUP does not install test runners.

`quality-baseline.json`: min coverage, lint fail level, gitleaks fail. **No** complexity fail threshold.

## RUN

```bash
.cursor/skills/quality-gate/scripts/check.sh
.cursor/skills/quality-gate/scripts/check.sh --file path/a --file path/b
```

`lefthook validate` then `lefthook run pre-commit` (`--all-files` if no `--file`). Exit non-zero on red except radon/cyclop (report only). Do not `lefthook install`. Do not format/`--fix`.

Git commit/push uses Lefthook git hooks **after** SETUP `--git-hooks`. Agent review uses check.sh only.

No extra Cursor hook. No extra lefthook skill.
