<#
.SYNOPSIS
    CKA Bench task runner — the primary entry point on Windows.

.DESCRIPTION
    Replaces 'make' on Windows. Finds Git Bash automatically and delegates
    task scripts (setup/verify/cleanup) to it. Cluster management stays in
    native PowerShell. No SHELL detection gymnastics required.

.PARAMETER Command
    The operation to run. Run '.\run.ps1 help' to list all commands.

.PARAMETER Task
    Task ID, e.g. task-01-broken-service. Required for prep/verify/clean/solve/scenario.

.PARAMETER Timeout
    Agent timeout in seconds (default: 300). Applies to solve and suite.

.EXAMPLE
    .\run.ps1 help
    .\run.ps1 check
    .\run.ps1 cluster-create
    .\run.ps1 prep    -Task task-01-broken-service
    .\run.ps1 verify  -Task task-01-broken-service
    .\run.ps1 clean   -Task task-01-broken-service
    .\run.ps1 solve-local -Task task-01-broken-service
    .\run.ps1 solve   -Task task-01-broken-service
    .\run.ps1 suite
    .\run.ps1 scenario -Task task-01-broken-service
    .\run.ps1 scenario -Task all
#>
param(
    [Parameter(Position = 0)]
    [string]$Command = 'help',

    [string]$Task    = '',
    [int]   $Timeout = 300
)

Set-StrictMode -Version Latest

$RepoRoot = $PSScriptRoot

# ── PATH bootstrap ─────────────────────────────────────────────────────────────
# Refresh from registry so WinGet-installed tools (kind, kubectl) are visible
# without needing a terminal restart after winget install.
$env:Path = ([System.Environment]::GetEnvironmentVariable('Path', 'Machine'),
             [System.Environment]::GetEnvironmentVariable('Path', 'User') |
             Where-Object { $_ }) -join ';'

# Also expose GnuWin32 make in the current session if installed but not on PATH
$gnuWin32 = 'C:\Program Files (x86)\GnuWin32\bin'
if ((Test-Path $gnuWin32) -and $env:Path -notlike "*GnuWin32*") {
    $env:Path += ";$gnuWin32"
}

# ── Find Git Bash ──────────────────────────────────────────────────────────────
function Find-GitBash {
    $candidates = @(
        "C:\Program Files\Git\bin\bash.exe",
        "C:\Program Files (x86)\Git\bin\bash.exe",
        "$env:LOCALAPPDATA\Programs\Git\bin\bash.exe",
        "$env:USERPROFILE\AppData\Local\Programs\Git\bin\bash.exe",
        "$env:USERPROFILE\scoop\apps\git\current\bin\bash.exe"
    )
    # Derive from git.exe location when Git is on PATH
    $gitExe = Get-Command git -EA SilentlyContinue
    if ($gitExe) {
        # git.exe is typically in …\Git\cmd\git.exe; bash.exe is in …\Git\bin\bash.exe
        $gitRoot = Split-Path (Split-Path $gitExe.Source)
        $candidates = @("$gitRoot\bin\bash.exe") + $candidates
    }
    foreach ($c in $candidates) {
        if (Test-Path $c) { return $c }
    }
    return $null
}

$script:BASH = Find-GitBash

# ── Helpers ───────────────────────────────────────────────────────────────────

function Invoke-Bash {
    param(
        [string]  $Script,
        [string[]]$ScriptArgs = @()
    )
    if (-not $script:BASH) {
        Write-Host ''
        Write-Host 'ERROR: Git Bash not found.' -ForegroundColor Red
        Write-Host 'Install Git for Windows: https://git-scm.com/download/win' -ForegroundColor Yellow
        Write-Host 'Then re-run this command.' -ForegroundColor Yellow
        exit 1
    }
    & $script:BASH $Script @ScriptArgs
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

function Require-Task {
    param([string]$Cmd)
    if (-not $Task) {
        Write-Host "ERROR: -Task is required for '$Cmd'." -ForegroundColor Red
        Write-Host "Usage:  .\run.ps1 $Cmd -Task <task-id>" -ForegroundColor Yellow
        Write-Host ''
        Write-Host 'Available tasks:' -ForegroundColor White
        if (Test-Path "$RepoRoot\tasks") {
            Get-ChildItem "$RepoRoot\tasks" -Directory | Sort-Object Name |
                ForEach-Object { Write-Host "  $($_.Name)" }
        }
        exit 1
    }
    if (-not (Test-Path "$RepoRoot\tasks\$Task")) {
        Write-Host "ERROR: Task '$Task' not found." -ForegroundColor Red
        Write-Host 'Available tasks:' -ForegroundColor White
        Get-ChildItem "$RepoRoot\tasks" -Directory | Sort-Object Name |
            ForEach-Object { Write-Host "  $($_.Name)" }
        exit 1
    }
}

function Show-Help {
    $bashStatus = if ($script:BASH) { "found: $($script:BASH)" } else { 'NOT FOUND - install Git for Windows' }
    Write-Host ''
    Write-Host '============================================================' -ForegroundColor White
    Write-Host '  CKA Bench  -  Windows Task Runner' -ForegroundColor White
    Write-Host '============================================================' -ForegroundColor White
    Write-Host "  Git Bash : $bashStatus" -ForegroundColor $(if ($script:BASH) { 'Green' } else { 'Red' })
    Write-Host ''
    Write-Host 'SETUP' -ForegroundColor White
    Write-Host '  .\run.ps1 check                      Check all prerequisites'
    Write-Host '  .\run.ps1 check-install              Check and auto-install missing tools'
    Write-Host ''
    Write-Host 'CLUSTER' -ForegroundColor White
    Write-Host '  .\run.ps1 cluster-create             Create local kind cluster'
    Write-Host '  .\run.ps1 cluster-destroy            Destroy kind cluster'
    Write-Host '  .\run.ps1 cluster-reset              Destroy and recreate cluster'
    Write-Host ''
    Write-Host 'TASK WORKFLOW' -ForegroundColor White
    Write-Host '  .\run.ps1 prep    -Task <id>         Inject broken state, print prompt'
    Write-Host '  .\run.ps1 verify  -Task <id>         Run deterministic verification'
    Write-Host '  .\run.ps1 clean   -Task <id>         Remove task resources'
    Write-Host ''
    Write-Host 'AGENT SOLVER' -ForegroundColor White
    Write-Host '  .\run.ps1 solve-local -Task <id>     Solve via local claude CLI (no API key)'
    Write-Host '  .\run.ps1 solve   -Task <id>         Solve via Anthropic API (needs ANTHROPIC_API_KEY)'
    Write-Host '  .\run.ps1 suite-local                Run all tasks via local claude CLI, aggregate results'
    Write-Host '  .\run.ps1 suite-local -Task "t1 t2"  Run specific tasks via local claude CLI'
    Write-Host '  .\run.ps1 suite                      Run all tasks via Anthropic API (needs API key)'
    Write-Host '  .\run.ps1 suite   -Task "t1 t2"      Run specific tasks via Anthropic API'
    Write-Host ''
    Write-Host '  In VS Code with Claude Code: type /solve <task-id> or /prep <task-id>'
    Write-Host ''
    Write-Host 'KILLERCODA' -ForegroundColor White
    Write-Host '  .\run.ps1 scenario -Task <id>        Generate Killercoda scenario files'
    Write-Host '  .\run.ps1 scenario -Task all         Generate all scenarios'
    Write-Host ''
    Write-Host 'AVAILABLE TASKS' -ForegroundColor White
    if (Test-Path "$RepoRoot\tasks") {
        Get-ChildItem "$RepoRoot\tasks" -Directory | Sort-Object Name |
            ForEach-Object { Write-Host "  $($_.Name)" }
    }
    Write-Host ''
}

# ── Dispatch ──────────────────────────────────────────────────────────────────

switch ($Command.ToLower()) {

    'help' {
        Show-Help
    }

    'check' {
        & "$RepoRoot\scripts\check_prerequisites.ps1"
    }

    'check-install' {
        & "$RepoRoot\scripts\check_prerequisites.ps1" -Install
    }

    'cluster-create' {
        & "$RepoRoot\adapters\local-kind\create_cluster.ps1"
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }

    'cluster-destroy' {
        & "$RepoRoot\adapters\local-kind\destroy_cluster.ps1"
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }

    'cluster-reset' {
        & "$RepoRoot\adapters\local-kind\reset_cluster.ps1"
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }

    'prep' {
        Require-Task 'prep'
        Invoke-Bash "$RepoRoot\prep-env\start.sh" @($Task)
    }

    'verify' {
        Require-Task 'verify'
        Invoke-Bash "$RepoRoot\tasks\$Task\verify.sh"
    }

    'clean' {
        Require-Task 'clean'
        Invoke-Bash "$RepoRoot\tasks\$Task\cleanup.sh"
    }

    'solve-local' {
        Require-Task 'solve-local'
        Invoke-Bash "$RepoRoot\solver-agent\agent_local.sh" @($Task)
    }

    'solve' {
        Require-Task 'solve'
        python "$RepoRoot\harness\run_task.py" --task $Task --mode agent --timeout $Timeout
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }

    'suite' {
        if ($Task) {
            python "$RepoRoot\harness\run_suite.py" --tasks $Task --mode agent --timeout $Timeout
        } else {
            python "$RepoRoot\harness\run_suite.py" --mode agent --timeout $Timeout
        }
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }

    'suite-local' {
        if ($Task) {
            python "$RepoRoot\harness\run_suite.py" --tasks $Task --mode local --timeout $Timeout
        } else {
            python "$RepoRoot\harness\run_suite.py" --mode local --timeout $Timeout
        }
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }

    'scenario' {
        if ($Task -ne 'all') { Require-Task 'scenario' }
        if (-not $Task) {
            Write-Host "ERROR: -Task is required. Use -Task <id> or -Task all." -ForegroundColor Red
            exit 1
        }
        python "$RepoRoot\adapters\killercoda\generate_scenario.py" $Task
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }

    default {
        Write-Host "Unknown command: '$Command'" -ForegroundColor Red
        Show-Help
        exit 1
    }
}
