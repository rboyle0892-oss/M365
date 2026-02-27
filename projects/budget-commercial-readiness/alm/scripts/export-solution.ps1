param(
    [Parameter(Mandatory = $true)] [string]$EnvironmentUrl,
    [Parameter(Mandatory = $true)] [string]$SolutionName,
    [Parameter(Mandatory = $true)] [string]$OutputZip,
    [Parameter(Mandatory = $true)] [string]$TenantId,
    [Parameter(Mandatory = $true)] [string]$ClientId,
    [Parameter(Mandatory = $true)] [string]$ClientSecret
)

$ErrorActionPreference = 'Stop'

$outDir = Split-Path -Path $OutputZip -Parent
if (-not (Test-Path $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}

Write-Host "Authenticating to source environment $EnvironmentUrl"
pac auth create --environment $EnvironmentUrl --tenant $TenantId --applicationId $ClientId --clientSecret $ClientSecret | Out-Null

Write-Host "Exporting unmanaged solution '$SolutionName' to '$OutputZip'"
pac solution export --name $SolutionName --path $OutputZip --managed false --include general

if (-not (Test-Path $OutputZip)) {
    throw "Export failed. Output file not found: $OutputZip"
}

Write-Host "Export complete: $OutputZip"
