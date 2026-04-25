<#
.SYNOPSIS
    Checks all prerequisites for CKA Bench and optionally installs missing ones.
.PARAMETER Install
    Attempt to automatically install missing tools where possible.
.EXAMPLE
    .\scripts\check_prerequisites.ps1
    .\scripts\check_prerequisites.ps1 -Install
#>
param(
    [switch]$Install
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'SilentlyContinue'

# Refresh PATH from the registry so tools installed in this session (e.g. via
# winget) are visible without requiring a terminal restart.
$machinePath = [System.Environment]::GetEnvironmentVariable('Path', 'Machine')
$userPath    = [System.Environment]::GetEnvironmentVariable('Path', 'User')
$env:Path    = ($machinePath, $userPath | Where-Object { $_ }) -join ';'

$script:MissingCount = 0
$script:WarningCount = 0

# ── Output helpers ─────────────────────────────────────────────────────────────

function Write-Ok     { param($msg) Write-Host "  [OK]      $msg" -ForegroundColor Green }
function Write-Miss   { param($msg) Write-Host "  [MISSING] $msg" -ForegroundColor Red;    $script:MissingCount++ }
function Write-Warn   { param($msg) Write-Host "  [WARN]    $msg" -ForegroundColor Yellow; $script:WarningCount++ }
function Write-Info   { param($msg) Write-Host "  [INFO]    $msg" -ForegroundColor Cyan }
function Write-Header { param($msg) Write-Host "`n$msg" -ForegroundColor White }

# ── Generic helpers ────────────────────────────────────────────────────────────

function Test-Command {
    param([string]$Name)
    return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

# Run a command and return stdout as a trimmed string. Never throws.
function Get-Output {
    param([string]$Exe, [string[]]$Arguments = @())
    try {
        $result = & $Exe @Arguments 2>&1 | Where-Object { $_ -is [string] }
        return ($result | Out-String).Trim()
    } catch {
        return ''
    }
}

# Run a command and return $true if it exits 0.
function Test-ExitZero {
    param([string]$Exe, [string[]]$Arguments = @())
    try {
        & $Exe @Arguments 2>&1 | Out-Null
        return $LASTEXITCODE -eq 0
    } catch {
        return $false
    }
}

function Get-PackageManager {
    if (Test-Command 'winget') { return 'winget' }
    if (Test-Command 'choco')  { return 'choco'  }
    return ''
}

# ── Python helpers ─────────────────────────────────────────────────────────────

function Find-Python {
    foreach ($cmd in @('py', 'python', 'python3')) {
        $info = Get-Command $cmd -ErrorAction SilentlyContinue
        if (-not $info) { continue }
        # Skip the Windows Store stub — it opens the Store instead of running Python
        if ($info.Source -match 'WindowsApps') { continue }
        # Use --version to avoid any argument-quoting issues with -c scripts
        $verLine = Get-Output $cmd @('--version')   # e.g. "Python 3.13.2"
        if ($verLine -match 'Python (\d+)\.(\d+)') {
            if ([int]$Matches[1] -ge 3 -and [int]$Matches[2] -ge 9) {
                return $cmd
            }
        }
    }
    return ''
}

function Test-PythonPackage {
    param([string]$PythonCmd, [string]$ImportName)
    $ver = Get-Output $PythonCmd @(
        '-c', "import $ImportName; print(getattr($ImportName, '__version__', 'installed'))"
    )
    if ($ver -and $ver -notmatch 'Error|Traceback') { return $ver }
    return ''
}

# ── Install helpers ────────────────────────────────────────────────────────────

function Install-Kind {
    $pm = Get-PackageManager
    if ($pm -eq 'winget') { winget install --id Kubernetes.kind --silent --accept-package-agreements --accept-source-agreements; return }
    if ($pm -eq 'choco')  { choco install kind -y; return }
    Write-Warn "No package manager found. Install kind manually:"
    Write-Info "  https://kind.sigs.k8s.io/docs/user/quick-start/#installation"
}

function Install-Kubectl {
    $pm = Get-PackageManager
    if ($pm -eq 'winget') { winget install --id Kubernetes.kubectl --silent --accept-package-agreements --accept-source-agreements; return }
    if ($pm -eq 'choco')  { choco install kubernetes-cli -y; return }
    Write-Warn "No package manager found. Install kubectl manually:"
    Write-Info "  https://kubernetes.io/docs/tasks/tools/install-kubectl-windows/"
}

function Install-PythonPackages {
    param([string]$PythonCmd)
    $req = Join-Path (Split-Path -Parent $PSScriptRoot) 'requirements.txt'
    Write-Info "Running: $PythonCmd -m pip install -r $req"
    & $PythonCmd -m pip install -r $req
}

function Install-ClaudeCli {
    if (Test-Command 'npm') {
        npm install -g '@anthropic-ai/claude-code'
    } else {
        Write-Warn "npm not found. Install Node.js first: https://nodejs.org"
        Write-Info "Then run: npm install -g @anthropic-ai/claude-code"
    }
}

# ── Banner ─────────────────────────────────────────────────────────────────────

Write-Host ''
Write-Host '============================================================' -ForegroundColor White
Write-Host '  CKA Bench - Prerequisite Check'                            -ForegroundColor White
Write-Host '============================================================' -ForegroundColor White
Write-Host "  Mode : $(if ($Install) { 'check + install' } else { 'check only' })" -ForegroundColor White
if (-not $Install) {
    Write-Host '  Tip  : rerun with -Install to auto-install missing tools' -ForegroundColor DarkGray
}

# ── 1. Docker ─────────────────────────────────────────────────────────────────

Write-Header '1. Docker  (required by kind)'

if (Test-Command 'docker') {
    # Capture version on its own; test daemon separately
    $dockerVer = Get-Output 'docker' @('--version')
    $daemonOk  = Test-ExitZero 'docker' @('info')
    if ($daemonOk) {
        Write-Ok $dockerVer
    } else {
        Write-Warn "$dockerVer - daemon not running. Start Docker Desktop."
    }
} else {
    Write-Miss 'docker not found'
    Write-Info 'Download Docker Desktop: https://www.docker.com/products/docker-desktop/'
    Write-Info '(Cannot be installed automatically)'
}

# ── 2. kind ───────────────────────────────────────────────────────────────────

Write-Header '2. kind  (local Kubernetes clusters)'

if (Test-Command 'kind') {
    Write-Ok (Get-Output 'kind' @('--version'))
} else {
    Write-Miss 'kind not found'
    if ($Install) {
        Write-Info 'Installing kind...'
        Install-Kind
        if (Test-Command 'kind') { Write-Ok 'kind installed successfully' }
    } else {
        $pm = Get-PackageManager
        if     ($pm -eq 'winget') { Write-Info 'Run: winget install Kubernetes.kind' }
        elseif ($pm -eq 'choco')  { Write-Info 'Run: choco install kind' }
        else                      { Write-Info 'See: https://kind.sigs.k8s.io/docs/user/quick-start/#installation' }
    }
}

# ── 3. kubectl ────────────────────────────────────────────────────────────────

Write-Header '3. kubectl'

if (Test-Command 'kubectl') {
    # --short is deprecated; -o json is the reliable route in recent versions
    $ver = ''
    try {
        $json = (& kubectl version --client -o json 2>&1 | Where-Object { $_ -is [string] }) | ConvertFrom-Json
        $ver  = $json.clientVersion.gitVersion
    } catch {}
    if (-not $ver) {
        # Fallback: grab the first line that mentions "Client"
        $raw = Get-Output 'kubectl' @('version', '--client')
        $ver = ($raw -split "`n" | Where-Object { $_ -match 'Client' } | Select-Object -First 1).Trim()
    }
    if (-not $ver) { $ver = 'kubectl found' }
    Write-Ok $ver
} else {
    Write-Miss 'kubectl not found'
    if ($Install) {
        Write-Info 'Installing kubectl...'
        Install-Kubectl
        if (Test-Command 'kubectl') { Write-Ok 'kubectl installed successfully' }
    } else {
        $pm = Get-PackageManager
        if     ($pm -eq 'winget') { Write-Info 'Run: winget install Kubernetes.kubectl' }
        elseif ($pm -eq 'choco')  { Write-Info 'Run: choco install kubernetes-cli' }
        else                      { Write-Info 'See: https://kubernetes.io/docs/tasks/tools/install-kubectl-windows/' }
    }
}

# ── 4. Python 3.9+ ────────────────────────────────────────────────────────────

Write-Header '4. Python 3.9+'

$pythonCmd = Find-Python
if ($pythonCmd) {
    Write-Ok (Get-Output $pythonCmd @('--version'))
} else {
    Write-Miss 'Python 3.9+ not found'
    $pm = Get-PackageManager
    if     ($pm -eq 'winget') { Write-Info 'Run: winget install Python.Python.3.12' }
    elseif ($pm -eq 'choco')  { Write-Info 'Run: choco install python' }
    else                      { Write-Info 'Download: https://www.python.org/downloads/' }
}

# ── 5. Python packages ────────────────────────────────────────────────────────

Write-Header '5. Python packages  (anthropic, pyyaml)'

$pkgsMissing = $false

if ($pythonCmd) {
    foreach ($spec in @(@('anthropic', 'anthropic'), @('pyyaml', 'yaml'))) {
        $name = $spec[0]; $imp = $spec[1]
        $ver  = Test-PythonPackage $pythonCmd $imp
        if ($ver) { Write-Ok "$name ($ver)" }
        else      { Write-Miss "$name not installed"; $pkgsMissing = $true }
    }
    if ($pkgsMissing) {
        if ($Install) {
            Install-PythonPackages $pythonCmd
        } else {
            Write-Info 'Run: pip install -r requirements.txt'
        }
    }
} else {
    Write-Warn 'Skipping package check - Python not found'
}

# ── 6. Git for Windows / Git Bash ────────────────────────────────────────────

Write-Header '6. Git for Windows  (required for task commands via run.ps1)'

$gitBashCandidates = @(
    'C:\Program Files\Git\bin\bash.exe',
    'C:\Program Files (x86)\Git\bin\bash.exe',
    "$env:LOCALAPPDATA\Programs\Git\bin\bash.exe",
    "$env:USERPROFILE\scoop\apps\git\current\bin\bash.exe"
)
$gitExe = Get-Command git -EA SilentlyContinue
if ($gitExe) {
    $gitRoot = Split-Path (Split-Path $gitExe.Source)
    $gitBashCandidates = @("$gitRoot\bin\bash.exe") + $gitBashCandidates
}
$gitBashPath = $gitBashCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1

if ($gitBashPath) {
    $gitVer = Get-Output 'git' @('--version')
    Write-Ok "$gitVer  (bash at $gitBashPath)"
} else {
    Write-Miss 'Git for Windows not found - run.ps1 task commands (prep/verify/clean/solve) require Git Bash'
    if ($Install) {
        Write-Warn 'Git for Windows cannot be auto-installed here'
    }
    Write-Info 'Download: https://git-scm.com/download/win'
    Write-Info '(Choose "Git Bash" during installation)'
}

# ── 7. make ───────────────────────────────────────────────────────────────────

Write-Header '7. make  (optional - for Linux/Mac or advanced Windows use)'

# GnuWin32 winget package does not add itself to PATH — probe the known install
# location so we can report it found even without a PATH entry.
$makeExe = 'make'
if (-not (Test-Command 'make')) {
    $gnuWin32 = 'C:\Program Files (x86)\GnuWin32\bin\make.exe'
    if (Test-Path $gnuWin32) {
        $makeExe = $gnuWin32
        # Also add to the session PATH so subsequent make calls work
        $env:Path = "$env:Path;$(Split-Path $gnuWin32)"
    } else {
        $makeExe = ''
    }
}

if ($makeExe) {
    Write-Ok ((Get-Output $makeExe @('--version')) -split "`n" | Select-Object -First 1)
} else {
    Write-Warn 'make not found - Makefile targets unavailable, but scripts work directly'
    $pm = Get-PackageManager
    if     ($pm -eq 'winget') { Write-Info 'Run: winget install GnuWin32.Make' }
    elseif ($pm -eq 'choco')  { Write-Info 'Run: choco install make' }
}

# ── 7. claude CLI ─────────────────────────────────────────────────────────────

Write-Header '8. claude CLI  (optional - for local /solve agent mode)'

if (Test-Command 'claude') {
    $ver = Get-Output 'claude' @('--version')
    Write-Ok $(if ($ver) { $ver } else { 'claude CLI found' })
} else {
    Write-Warn "claude CLI not found - '.\run.ps1 solve-local' and /solve will not work"
    if ($Install) {
        Write-Info 'Installing claude CLI via npm...'
        Install-ClaudeCli
        if (Test-Command 'claude') { Write-Ok 'claude CLI installed successfully' }
    } else {
        Write-Info 'Install Claude Code: https://claude.ai/code'
        Write-Info 'Or run: npm install -g @anthropic-ai/claude-code'
    }
}

# ── 8. ANTHROPIC_API_KEY ──────────────────────────────────────────────────────

Write-Header '9. ANTHROPIC_API_KEY  (optional - for API agent mode)'

$apiKey = $env:ANTHROPIC_API_KEY
if ($apiKey) {
    Write-Ok "Set ($($apiKey.Length) chars)"
} else {
    Write-Warn "Not set - '.\run.ps1 solve' and '.\run.ps1 suite' will not work"
    Write-Info '$env:ANTHROPIC_API_KEY = "sk-ant-..."'
    Write-Info 'Only needed for API-based solver. Local /solve mode does not require it.'
}

# ── Summary ───────────────────────────────────────────────────────────────────

Write-Host ''
Write-Host '============================================================' -ForegroundColor White
Write-Host '  Summary'                                                    -ForegroundColor White
Write-Host '============================================================' -ForegroundColor White

if ($script:MissingCount -eq 0 -and $script:WarningCount -eq 0) {
    Write-Host '  All prerequisites satisfied.' -ForegroundColor Green
    Write-Host '  Next step: .\run.ps1 cluster-create' -ForegroundColor Green
} elseif ($script:MissingCount -eq 0) {
    Write-Host "  Required tools OK. $($script:WarningCount) warning(s) - see above." -ForegroundColor Yellow
    Write-Host '  You can proceed with: .\run.ps1 cluster-create'                     -ForegroundColor Yellow
} else {
    Write-Host "  $($script:MissingCount) required tool(s) missing. Install them and re-run." -ForegroundColor Red
    if (-not $Install) {
        Write-Host '  Or rerun with: .\scripts\check_prerequisites.ps1 -Install' -ForegroundColor Cyan
    }
}
Write-Host ''
