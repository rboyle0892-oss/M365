param(
    [Parameter(Mandatory = $true)] [string]$EnvironmentUrl,
    [Parameter(Mandatory = $true)] [string]$TenantId,
    [Parameter(Mandatory = $true)] [string]$ClientId,
    [Parameter(Mandatory = $true)] [string]$ClientSecret
)

$ErrorActionPreference = 'Stop'

Write-Host "Authenticating to $EnvironmentUrl"
pac auth create --environment $EnvironmentUrl --tenant $TenantId --applicationId $ClientId --clientSecret $ClientSecret | Out-Null

Write-Host "Current pac auth profiles:"
pac auth list

Write-Host "Executing whoami against Dataverse..."
pac org who
