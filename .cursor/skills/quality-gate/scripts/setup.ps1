#Requires -Version 5.1
param(
    [switch]$Force,
    [switch]$GitHooks,
    [switch]$WithRadon,
    [string]$Dir = ""
)

$LEFTHOOK_VERSION = "2.0.2"
$GITLEAKS_VERSION = "8.28.0"
$RUFF_VERSION = "0.12.11"
$MYPY_VERSION = "1.17.1"
$BANDIT_VERSION = "1.8.6"
$PIP_AUDIT_VERSION = "2.9.0"
$VULTURE_VERSION = "2.14"
$RADON_VERSION = "6.0.1"
$GOLANGCI_LINT_VERSION = "2.4.0"
$BIOME_VERSION = "2.2.0"

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$TemplateDir = Join-Path $ScriptDir "templates"
$BinDir = Join-Path $env:USERPROFILE ".local\bin"

if ($env:QUALITY_GATE_RADON -eq "1") { $WithRadon = $true }
if (-not $Dir) { $Dir = (Get-Location).Path }

New-Item -ItemType Directory -Force -Path $BinDir | Out-Null
$env:Path = "$BinDir;$env:Path"
Set-Location $Dir

function Test-Cmd($p_name) {
    return [bool](Get-Command $p_name -ErrorAction SilentlyContinue)
}

function Install-UvTool($p_spec, $p_bin) {
    if (Test-Cmd $p_bin) {
        Write-Host "skip $p_bin (already on PATH)"
        return
    }
    if (-not (Test-Cmd "uv")) {
        throw "uv is required to install $p_spec. Install uv first."
    }
    uv tool install $p_spec
}

function Test-HasPython {
    if ((Test-Path "pyproject.toml") -or (Test-Path "uv.lock")) { return $true }
    return [bool](Get-ChildItem -Recurse -Filter "*.py" -File -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch "\\\.venv\\|\\node_modules\\|\\\.git\\" } |
        Select-Object -First 1)
}

function Test-HasGo {
    if (Test-Path "go.mod") { return $true }
    return [bool](Get-ChildItem -Recurse -Filter "*.go" -File -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch "\\\.venv\\|\\node_modules\\|\\\.git\\" } |
        Select-Object -First 1)
}

function Test-HasJs { return Test-Path "package.json" }

function Test-PyprojectHas($p_section) {
    if (-not (Test-Path "pyproject.toml")) { return $false }
    return Select-String -Path "pyproject.toml" -Pattern "^\[$([regex]::Escape($p_section))\]" -Quiet
}

function Install-Lefthook {
    if (Test-Cmd "lefthook") { Write-Host "skip lefthook (already on PATH)"; return }
    if (Test-Cmd "winget") {
        winget install --id evilmartians.lefthook -e --accept-source-agreements --accept-package-agreements
        return
    }
    if (Test-Cmd "scoop") { scoop install lefthook; return }
    if (Test-Cmd "npm") { npm install -g "@evilmartians/lefthook@$LEFTHOOK_VERSION"; return }
    throw "failed to install lefthook. See https://lefthook.dev/installation"
}

function Install-Gitleaks {
    if (Test-Cmd "gitleaks") { Write-Host "skip gitleaks (already on PATH)"; return }
    if (Test-Cmd "winget") {
        winget install --id Gitleaks.Gitleaks -e --accept-source-agreements --accept-package-agreements
        return
    }
    if (Test-Cmd "scoop") { scoop install gitleaks; return }
    throw "failed to install gitleaks. See https://github.com/gitleaks/gitleaks/releases"
}

function Install-GolangciLint {
    if (Test-Cmd "golangci-lint") { Write-Host "skip golangci-lint (already on PATH)"; return }
    $p_ps1 = "$env:TEMP\golangci-lint-install.ps1"
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/golangci/golangci-lint/HEAD/install.ps1" -OutFile $p_ps1
    & $p_ps1 -BinDir $BinDir -Version "v$GOLANGCI_LINT_VERSION"
}

function Install-Biome {
    if (Test-Cmd "biome") { Write-Host "skip biome (already on PATH)"; return }
    if (Test-Cmd "npm") { npm install -g "@biomejs/biome@$BIOME_VERSION"; return }
    throw "failed to install biome (need npm or a biome binary on PATH)."
}

function Write-LefthookYml {
    if ((Test-Path "lefthook.yml") -and -not $Force) {
        Write-Host "skip existing lefthook.yml (pass -Force to overwrite)"
        return
    }
    $p_python = Test-HasPython
    $p_go = Test-HasGo
    $p_js = Test-HasJs
    $p_jobs = @"
    - name: gitleaks
      run: gitleaks protect --staged --redact --no-banner
"@
    if ($p_python) {
        $p_jobs += @"

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
"@
        if ($WithRadon) {
            $p_jobs += @"

    - name: radon-cc
      glob: "**/*.py"
      exclude:
        - ".venv/**"
      run: sh -c 'radon cc {staged_files} -s -a || true'
"@
        }
    }
    if ($p_go) {
        $p_jobs += @"

    - name: golangci-lint
      glob: "**/*.go"
      run: golangci-lint run --disable=cyclop {staged_files}
    - name: cyclop-report
      glob: "**/*.go"
      run: sh -c 'golangci-lint run --default=none --enable=cyclop {staged_files} || true'
"@
    }
    if ($p_js) {
        $p_jobs += @"

    - name: biome
      glob:
        - "**/*.js"
        - "**/*.ts"
        - "**/*.tsx"
        - "**/*.jsx"
      exclude:
        - "node_modules/**"
      run: biome check {staged_files}
"@
    }
    $p_yml = @"
min_version: 1.10.0
assert_lefthook_installed: true
glob_matcher: doublestar

pre-commit:
  parallel: true
  jobs:
$p_jobs

pre-push:
  jobs:
    - name: gitleaks
      run: gitleaks detect --source . --redact --no-banner
"@
    Set-Content -Path "lefthook.yml" -Value $p_yml -Encoding utf8
    Write-Host "wrote lefthook.yml"
}

Install-Lefthook
Install-Gitleaks

if (Test-HasPython) {
    Install-UvTool "ruff==$RUFF_VERSION" "ruff"
    Install-UvTool "mypy==$MYPY_VERSION" "mypy"
    Install-UvTool "bandit==$BANDIT_VERSION" "bandit"
    Install-UvTool "pip-audit==$PIP_AUDIT_VERSION" "pip-audit"
    Install-UvTool "vulture==$VULTURE_VERSION" "vulture"
    if ($WithRadon) { Install-UvTool "radon==$RADON_VERSION" "radon" }
    if (Test-PyprojectHas "tool.ruff") {
        Write-Host "skip ruff.toml (pyproject [tool.ruff])"
    } elseif ((Test-Path "ruff.toml") -and -not $Force) {
        Write-Host "skip existing ruff.toml (pass -Force to overwrite)"
    } else {
        Copy-Item (Join-Path $TemplateDir "ruff.toml") "ruff.toml"
        Write-Host "wrote ruff.toml"
    }
    if (Test-PyprojectHas "tool.mypy") {
        Write-Host "skip mypy.ini (pyproject [tool.mypy])"
    } elseif (((Test-Path "mypy.ini") -or (Test-Path ".mypy.ini")) -and -not $Force) {
        Write-Host "skip existing mypy config (pass -Force to overwrite)"
    } else {
        Copy-Item (Join-Path $TemplateDir "mypy.ini") "mypy.ini"
        Write-Host "wrote mypy.ini"
    }
}

if (Test-HasGo) {
    Install-GolangciLint
    $p_hasGolangci = (Test-Path ".golangci.yml") -or (Test-Path ".golangci.yaml") -or (Test-Path "golangci.yml") -or (Test-Path "golangci.yaml")
    if ($p_hasGolangci -and -not $Force) {
        Write-Host "skip existing golangci config (pass -Force to overwrite)"
    } else {
        Copy-Item (Join-Path $TemplateDir "golangci.yml") ".golangci.yml"
        Write-Host "wrote .golangci.yml"
    }
}

if (Test-HasJs) {
    Install-Biome
    if (((Test-Path "biome.json") -or (Test-Path "biome.jsonc")) -and -not $Force) {
        Write-Host "skip existing biome.json (pass -Force to overwrite)"
    } else {
        Copy-Item (Join-Path $TemplateDir "biome.json") "biome.json"
        Write-Host "wrote biome.json"
    }
}

Write-LefthookYml

if ((Test-Path "quality-baseline.json") -and -not $Force) {
    Write-Host "skip existing quality-baseline.json (pass -Force to overwrite)"
} else {
    Copy-Item (Join-Path $TemplateDir "quality-baseline.json") "quality-baseline.json"
    Write-Host "wrote quality-baseline.json"
}

if ($GitHooks) { lefthook install }

Write-Host "quality-gate SETUP done in $Dir"
