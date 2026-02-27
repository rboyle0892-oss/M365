param(
    [Parameter(Mandatory = $true)] [string]$EnvironmentUrl,
    [Parameter(Mandatory = $true)] [string]$ValuesJsonPath,
    [Parameter(Mandatory = $true)] [string]$TenantId,
    [Parameter(Mandatory = $true)] [string]$ClientId,
    [Parameter(Mandatory = $true)] [string]$ClientSecret
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $ValuesJsonPath)) {
    throw "Values JSON file not found: $ValuesJsonPath"
}

$values = Get-Content -Path $ValuesJsonPath -Raw | ConvertFrom-Json
if (-not $values) {
    throw "No values found in $ValuesJsonPath"
}

Write-Host "Authenticating to $EnvironmentUrl"
pac auth create --environment $EnvironmentUrl --tenant $TenantId --applicationId $ClientId --clientSecret $ClientSecret | Out-Null

$keys = $values.PSObject.Properties.Name
foreach ($schemaName in $keys) {
    $val = [string]$values.$schemaName
    if ([string]::IsNullOrWhiteSpace($val)) {
        Write-Warning "Skipping '$schemaName' because value is empty."
        continue
    }

    Write-Host "Setting environment variable '$schemaName'"
    pac envvar set --schemaName $schemaName --value "$val"
}

Write-Host "Environment variable update complete."
