#!/usr/bin/env bash
set -euo pipefail

LEFTHOOK_VERSION="2.0.2"
GITLEAKS_VERSION="8.28.0"
RUFF_VERSION="0.12.11"
MYPY_VERSION="1.17.1"
BANDIT_VERSION="1.8.6"
PIP_AUDIT_VERSION="2.9.0"
VULTURE_VERSION="2.14"
RADON_VERSION="6.0.1"
GOLANGCI_LINT_VERSION="2.4.0"
BIOME_VERSION="2.2.0"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="${SCRIPT_DIR}/templates"
BIN_DIR="${HOME}/.local/bin"

FORCE=0
GIT_HOOKS=0
WITH_RADON=0
ROOT="$(pwd)"

usage() {
  echo "usage: setup.sh [--force] [--git-hooks] [--with-radon] [--dir PATH]" >&2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --force) FORCE=1; shift ;;
    --git-hooks) GIT_HOOKS=1; shift ;;
    --with-radon) WITH_RADON=1; shift ;;
    --dir)
      ROOT="$(cd "$2" && pwd)"
      shift 2
      ;;
    -h|--help) usage; exit 0 ;;
    *) usage; exit 1 ;;
  esac
done

if [[ "${QUALITY_GATE_RADON:-}" == "1" ]]; then
  WITH_RADON=1
fi

mkdir -p "$BIN_DIR"
export PATH="${BIN_DIR}:${PATH}"

cd "$ROOT"

need_force() {
  local p_path="$1"
  if [[ -e "$p_path" && "$FORCE" -eq 0 ]]; then
    echo "skip existing ${p_path} (pass --force to overwrite)"
    return 1
  fi
  return 0
}

install_uv_tool() {
  local p_pkg="$1"
  local p_bin="$2"
  if command -v "$p_bin" >/dev/null 2>&1; then
    echo "skip ${p_bin} (already on PATH)"
    return 0
  fi
  if ! command -v uv >/dev/null 2>&1; then
    echo "uv is required to install ${p_pkg}. Install uv first." >&2
    return 1
  fi
  uv tool install "${p_pkg}"
}

lefthook_asset() {
  local p_os p_arch
  p_os="$(uname -s)"
  p_arch="$(uname -m)"
  case "$p_os" in
    Linux) p_os="Linux" ;;
    Darwin) p_os="MacOS" ;;
    *) return 1 ;;
  esac
  case "$p_arch" in
    x86_64|amd64) p_arch="x86_64" ;;
    arm64|aarch64) p_arch="arm64" ;;
    *) return 1 ;;
  esac
  echo "lefthook_${LEFTHOOK_VERSION}_${p_os}_${p_arch}.gz"
}

gitleaks_asset() {
  local p_os p_arch
  p_os="$(uname -s)"
  p_arch="$(uname -m)"
  case "$p_os" in
    Linux) p_os="linux" ;;
    Darwin) p_os="darwin" ;;
    *) return 1 ;;
  esac
  case "$p_arch" in
    x86_64|amd64) p_arch="x64" ;;
    arm64|aarch64) p_arch="arm64" ;;
    *) return 1 ;;
  esac
  echo "gitleaks_${GITLEAKS_VERSION}_${p_os}_${p_arch}.tar.gz"
}

install_lefthook() {
  if command -v lefthook >/dev/null 2>&1; then
    echo "skip lefthook (already on PATH)"
    return 0
  fi
  if command -v mise >/dev/null 2>&1; then
    if mise use -g "lefthook@${LEFTHOOK_VERSION}"; then
      return 0
    fi
  fi
  local p_asset p_url p_tmp
  p_asset="$(lefthook_asset)" || true
  if [[ -n "${p_asset:-}" ]]; then
    p_url="https://github.com/evilmartians/lefthook/releases/download/v${LEFTHOOK_VERSION}/${p_asset}"
    p_tmp="$(mktemp)"
    if curl -fsSL "$p_url" -o "$p_tmp"; then
      gunzip -c "$p_tmp" > "${BIN_DIR}/lefthook"
      chmod +x "${BIN_DIR}/lefthook"
      rm -f "$p_tmp"
      echo "installed lefthook ${LEFTHOOK_VERSION} -> ${BIN_DIR}/lefthook"
      return 0
    fi
    rm -f "$p_tmp"
  fi
  if command -v npm >/dev/null 2>&1; then
    npm install -g "@evilmartians/lefthook@${LEFTHOOK_VERSION}"
    return 0
  fi
  echo "failed to install lefthook. See https://lefthook.dev/installation" >&2
  return 1
}

install_gitleaks() {
  if command -v gitleaks >/dev/null 2>&1; then
    echo "skip gitleaks (already on PATH)"
    return 0
  fi
  if command -v mise >/dev/null 2>&1; then
    if mise use -g "gitleaks@${GITLEAKS_VERSION}"; then
      return 0
    fi
  fi
  local p_asset p_url p_tmp p_dir
  p_asset="$(gitleaks_asset)" || true
  if [[ -n "${p_asset:-}" ]]; then
    p_url="https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/${p_asset}"
    p_tmp="$(mktemp)"
    p_dir="$(mktemp -d)"
    if curl -fsSL "$p_url" -o "$p_tmp"; then
      tar -xzf "$p_tmp" -C "$p_dir"
      cp "${p_dir}/gitleaks" "${BIN_DIR}/gitleaks"
      chmod +x "${BIN_DIR}/gitleaks"
      rm -rf "$p_tmp" "$p_dir"
      echo "installed gitleaks ${GITLEAKS_VERSION} -> ${BIN_DIR}/gitleaks"
      return 0
    fi
    rm -rf "$p_tmp" "$p_dir"
  fi
  echo "failed to install gitleaks. See https://github.com/gitleaks/gitleaks/releases" >&2
  return 1
}

install_golangci_lint() {
  if command -v golangci-lint >/dev/null 2>&1; then
    echo "skip golangci-lint (already on PATH)"
    return 0
  fi
  curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/HEAD/install.sh \
    | sh -s -- -b "$BIN_DIR" "v${GOLANGCI_LINT_VERSION}"
}

install_biome() {
  if command -v biome >/dev/null 2>&1; then
    echo "skip biome (already on PATH)"
    return 0
  fi
  if command -v npm >/dev/null 2>&1; then
    npm install -g "@biomejs/biome@${BIOME_VERSION}"
    return 0
  fi
  echo "failed to install biome (need npm or a biome binary on PATH)." >&2
  return 1
}

has_python() {
  [[ -f pyproject.toml || -f uv.lock ]] && return 0
  find . \( -path './.venv' -o -path './node_modules' -o -path './.git' \) -prune -o -name '*.py' -print -quit | grep -q .
}

has_go() {
  [[ -f go.mod ]] && return 0
  find . \( -path './.venv' -o -path './node_modules' -o -path './.git' \) -prune -o -name '*.go' -print -quit | grep -q .
}

has_js() {
  [[ -f package.json ]]
}

pyproject_has() {
  local p_section="$1"
  [[ -f pyproject.toml ]] && grep -q "^\[${p_section}\]" pyproject.toml
}

write_lefthook_yml() {
  if ! need_force lefthook.yml; then
    return 0
  fi
  local p_python=0 p_go=0 p_js=0
  has_python && p_python=1
  has_go && p_go=1
  has_js && p_js=1

  {
    cat <<'EOF'
min_version: 1.10.0
assert_lefthook_installed: true
glob_matcher: doublestar

pre-commit:
  parallel: true
  jobs:
    - name: gitleaks
      run: gitleaks protect --staged --redact --no-banner
EOF
    if [[ "$p_python" -eq 1 ]]; then
      cat <<'EOF'
    - name: ruff-check
      glob: "**/*.py"
      exclude:
        - ".venv/**"
      run: ruff check {staged_files}
    - name: ruff-format
      glob: "**/*.py"
      exclude:
        - ".venv/**"
      run: ruff format --check {staged_files}
    - name: mypy
      glob: "**/*.py"
      exclude:
        - ".venv/**"
      run: mypy {staged_files}
    - name: bandit
      glob: "**/*.py"
      exclude:
        - ".venv/**"
      run: bandit -q {staged_files}
    - name: vulture
      glob: "**/*.py"
      exclude:
        - ".venv/**"
      run: vulture {staged_files}
    - name: pip-audit
      glob:
        - "uv.lock"
        - "pyproject.toml"
        - "requirements*.txt"
      run: sh -c 'if [ -f uv.lock ] && command -v uv >/dev/null 2>&1; then uv export --frozen | pip-audit -r -; elif [ -d .venv ]; then pip-audit --path .venv; elif [ -f requirements.txt ]; then pip-audit -r requirements.txt; else pip-audit; fi'
EOF
      if [[ "$WITH_RADON" -eq 1 ]]; then
        cat <<'EOF'
    - name: radon-cc
      glob: "**/*.py"
      exclude:
        - ".venv/**"
      run: sh -c 'radon cc {staged_files} -s -a || true'
EOF
      fi
    fi
    if [[ "$p_go" -eq 1 ]]; then
      cat <<'EOF'
    - name: golangci-lint
      glob: "**/*.go"
      run: golangci-lint run --disable=cyclop {staged_files}
    - name: cyclop-report
      glob: "**/*.go"
      run: sh -c 'golangci-lint run --default=none --enable=cyclop {staged_files} || true'
EOF
    fi
    if [[ "$p_js" -eq 1 ]]; then
      cat <<'EOF'
    - name: biome
      glob:
        - "**/*.js"
        - "**/*.ts"
        - "**/*.tsx"
        - "**/*.jsx"
      exclude:
        - "node_modules/**"
      run: biome check {staged_files}
EOF
    fi
    cat <<'EOF'

pre-push:
  jobs:
    - name: gitleaks
      run: gitleaks detect --source . --redact --no-banner
EOF
  } > lefthook.yml
  echo "wrote lefthook.yml"
}

install_lefthook
install_gitleaks

if has_python; then
  install_uv_tool "ruff==${RUFF_VERSION}" ruff
  install_uv_tool "mypy==${MYPY_VERSION}" mypy
  install_uv_tool "bandit==${BANDIT_VERSION}" bandit
  install_uv_tool "pip-audit==${PIP_AUDIT_VERSION}" pip-audit
  install_uv_tool "vulture==${VULTURE_VERSION}" vulture
  if [[ "$WITH_RADON" -eq 1 ]]; then
    install_uv_tool "radon==${RADON_VERSION}" radon
  fi
  if pyproject_has "tool.ruff"; then
    echo "skip ruff.toml (pyproject [tool.ruff])"
  elif [[ -f ruff.toml && "$FORCE" -eq 0 ]]; then
    echo "skip existing ruff.toml (pass --force to overwrite)"
  else
    cp "${TEMPLATE_DIR}/ruff.toml" ruff.toml
    echo "wrote ruff.toml"
  fi
  if pyproject_has "tool.mypy"; then
    echo "skip mypy.ini (pyproject [tool.mypy])"
  elif { [[ -f mypy.ini ]] || [[ -f .mypy.ini ]]; } && [[ "$FORCE" -eq 0 ]]; then
    echo "skip existing mypy config (pass --force to overwrite)"
  else
    cp "${TEMPLATE_DIR}/mypy.ini" mypy.ini
    echo "wrote mypy.ini"
  fi
fi

if has_go; then
  install_golangci_lint
  if { [[ -f .golangci.yml ]] || [[ -f .golangci.yaml ]] || [[ -f golangci.yml ]] || [[ -f golangci.yaml ]]; } && [[ "$FORCE" -eq 0 ]]; then
    echo "skip existing golangci config (pass --force to overwrite)"
  else
    cp "${TEMPLATE_DIR}/golangci.yml" .golangci.yml
    echo "wrote .golangci.yml"
  fi
fi

if has_js; then
  install_biome
  if { [[ -f biome.json ]] || [[ -f biome.jsonc ]]; } && [[ "$FORCE" -eq 0 ]]; then
    echo "skip existing biome.json (pass --force to overwrite)"
  else
    cp "${TEMPLATE_DIR}/biome.json" biome.json
    echo "wrote biome.json"
  fi
fi

write_lefthook_yml

if need_force quality-baseline.json; then
  cp "${TEMPLATE_DIR}/quality-baseline.json" quality-baseline.json
  echo "wrote quality-baseline.json"
fi

if [[ "$GIT_HOOKS" -eq 1 ]]; then
  lefthook install
fi

case ":${PATH}:" in
  *":${BIN_DIR}:"*) ;;
  *) echo "warning: add ${BIN_DIR} to PATH" ;;
esac

echo "quality-gate SETUP done in ${ROOT}"
