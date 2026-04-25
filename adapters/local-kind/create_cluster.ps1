<#
.SYNOPSIS
    Creates the cka-bench kind cluster and sets the kubectl context.
#>
param()

# Refresh PATH so winget-installed tools are visible
$env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' +
            [System.Environment]::GetEnvironmentVariable('Path','User')

$ClusterName = if ($env:CLUSTER_NAME) { $env:CLUSTER_NAME } else { 'cka-bench' }
$KindConfig  = Join-Path $PSScriptRoot 'kind-config.yaml'

$existing = (kind get clusters 2>&1) | Where-Object { $_ -is [string] }
if ($existing -contains $ClusterName) {
    Write-Host "[kind] Cluster '$ClusterName' already exists. Skipping creation."
    kind export kubeconfig --name $ClusterName
    kubectl config use-context "kind-$ClusterName"
    exit 0
}

Write-Host "[kind] Creating cluster '$ClusterName'..."
kind create cluster --name $ClusterName --config $KindConfig --wait 60s
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "[kind] Exporting kubeconfig..."
kind export kubeconfig --name $ClusterName
kubectl config use-context "kind-$ClusterName"

Write-Host "[kind] Cluster ready. Context: kind-$ClusterName"
kubectl get nodes
