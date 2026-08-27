#!/usr/bin/env bash
set -euo pipefail

SETUP_HINT=".cursor/skills/quality-gate/scripts/setup.sh"

if ! command -v lefthook >/dev/null 2>&1; then
  echo "lefthook not found. Run quality-gate SETUP: ${SETUP_HINT}" >&2
  exit 1
fi

if [[ ! -f lefthook.yml && ! -f lefthook.yaml && ! -f .lefthook.yml ]]; then
  echo "lefthook.yml not found. Run quality-gate SETUP: ${SETUP_HINT}" >&2
  exit 1
fi

lefthook validate

if [[ $# -eq 0 ]]; then
  lefthook run pre-commit --all-files
else
  lefthook run pre-commit "$@"
fi
