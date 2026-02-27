param(
    [Parameter(Mandatory = $true)] [string]$EnvironmentUrl,
    [Parameter(Mandatory = $true)] [string]$SolutionZip,
    [switch]$PublishWorkflows,
    [Parameter(Mandatory = $true)] [string]$TenantId,
    [Parameter(Mandatory = $true)] [string]$ClientId,
    [Parameter(Mandatory = $true)] [string]$ClientSecret
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $SolutionZip)) {
    throw "Solution zip not found: $SolutionZip"
}

Write-Host "Authenticating to target environment $EnvironmentUrl"
pac auth create --environment $EnvironmentUrl --tenant $TenantId --applicationId $ClientId --clientSecret $ClientSecret | Out-Null

$holdingArg = "false"
$publishArg = if ($PublishWorkflows.IsPresent) { "true" } else { "false" }

Write-Host "Importing solution from $SolutionZip"
pac solution import --path $SolutionZip --async true --max-async-wait-time 60 --activate-plugins true --publish-changes $publishArg --convert-to-managed false --stage-and-upgrade $holdingArg

Write-Host "Solution import completed."
