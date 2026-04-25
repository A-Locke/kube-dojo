<#
.SYNOPSIS
    Destroys and recreates the cka-bench kind cluster.
#>
param()

$env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' +
            [System.Environment]::GetEnvironmentVariable('Path','User')

$ScriptDir = $PSScriptRoot
Write-Host "[kind] Resetting cluster..."
& "$ScriptDir\destroy_cluster.ps1"
& "$ScriptDir\create_cluster.ps1"
Write-Host "[kind] Cluster reset complete."
