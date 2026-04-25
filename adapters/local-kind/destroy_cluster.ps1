<#
.SYNOPSIS
    Destroys the cka-bench kind cluster.
#>
param()

$env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' +
            [System.Environment]::GetEnvironmentVariable('Path','User')

$ClusterName = if ($env:CLUSTER_NAME) { $env:CLUSTER_NAME } else { 'cka-bench' }

$existing = (kind get clusters 2>&1) | Where-Object { $_ -is [string] }
if ($existing -notcontains $ClusterName) {
    Write-Host "[kind] Cluster '$ClusterName' does not exist. Nothing to destroy."
    exit 0
}

Write-Host "[kind] Destroying cluster '$ClusterName'..."
kind delete cluster --name $ClusterName

# kind delete cluster does not remove kubeconfig context/cluster entries — clean them up.
$ctx = "kind-$ClusterName"
Write-Host "[kind] Cleaning up kubeconfig context '$ctx'..."
kubectl config delete-context $ctx 2>&1 | Out-Null
kubectl config delete-cluster $ctx 2>&1 | Out-Null
Write-Host "[kind] Done."
exit 0
