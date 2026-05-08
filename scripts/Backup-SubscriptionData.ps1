<#
.SYNOPSIS
    Backs up Subscription Billing custom field data before migrating the
    tableextension from SKC Customizations to the Subscription Billing
    Community Patch app.

.DESCRIPTION
    Reads Subscription Line custom fields (AutoRenewal, ExtensionTermBackup,
    NoticePeriodBackup, TermUntilBackup) and SubQuantityHistory records via
    the BC API, then exports them to timestamped CSV files.

    Run this BEFORE uninstalling the SKC Customizations version that removes
    the SubscriptionLine003SKC tableextension.

.PARAMETER BaseUrl
    BC API base URL, e.g. https://api.businesscentral.dynamics.com/v2.0/tenant/environment

.PARAMETER CompanyId
    The BC company GUID.

.PARAMETER ClientId
    Entra app (client) ID for S2S authentication.

.PARAMETER ClientSecret
    Entra app client secret.

.PARAMETER TenantId
    Entra tenant ID or domain (e.g. skc.lu).

.PARAMETER BackupFolder
    Folder to write CSV files. Defaults to ./backups.

.EXAMPLE
    .\Backup-SubscriptionData.ps1 `
        -BaseUrl "https://api.businesscentral.dynamics.com/v2.0/skc.lu/Production" `
        -CompanyId "6dd00b28-9c4c-ec11-9f08-000d3a4c026b" `
        -ClientId "7d36be52-772d-4234-ac08-eee1258f09ec" `
        -ClientSecret (Read-Host -AsSecureString "Secret") `
        -TenantId "skc.lu"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$BaseUrl,

    [Parameter(Mandatory)]
    [string]$CompanyId,

    [Parameter(Mandatory)]
    [string]$ClientId,

    [Parameter(Mandatory)]
    [string]$ClientSecret,

    [Parameter(Mandatory)]
    [string]$TenantId,

    [string]$BackupFolder = (Join-Path $PSScriptRoot "..\backups")
)

$ErrorActionPreference = "Stop"
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

if (-not (Test-Path $BackupFolder)) {
    New-Item -ItemType Directory -Path $BackupFolder -Force | Out-Null
}

function Get-BearerToken {
    $body = @{
        grant_type    = "client_credentials"
        client_id     = $ClientId
        client_secret = $ClientSecret
        scope         = "https://api.businesscentral.dynamics.com/.default"
    }
    $tokenUrl = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"
    $response = Invoke-RestMethod -Uri $tokenUrl -Method Post -Body $body -ContentType "application/x-www-form-urlencoded"
    return $response.access_token
}

function Invoke-BcApi {
    param(
        [string]$Token,
        [string]$Url
    )
    $headers = @{
        Authorization = "Bearer $Token"
        Accept        = "application/json"
    }

    $allRecords = @()
    $nextUrl = $Url

    while ($nextUrl) {
        $response = Invoke-RestMethod -Uri $nextUrl -Headers $headers -Method Get
        if ($response.value) {
            $allRecords += $response.value
        }
        $nextUrl = $response.'@odata.nextLink'
    }

    return $allRecords
}

Write-Host "=== Subscription Data Backup ===" -ForegroundColor Cyan
Write-Host "Timestamp: $timestamp"
Write-Host "Backup folder: $BackupFolder"
Write-Host ""

Write-Host "Acquiring bearer token..." -ForegroundColor Yellow
$token = Get-BearerToken
Write-Host "Token acquired." -ForegroundColor Green

# --- Backup Subscription Lines (custom fields) ---
Write-Host ""
Write-Host "Fetching Subscription Lines with custom fields..." -ForegroundColor Yellow
$subLinesUrl = "$BaseUrl/api/skconsulting/subscriptionBilling/v1.0/companies($CompanyId)/subscriptionLines?`$select=systemId,entryNo,subscriptionNo,autoRenewal,extensionTermBackup,closed"
$subLines = Invoke-BcApi -Token $token -Url $subLinesUrl

$subLinesCsvPath = Join-Path $BackupFolder "SubscriptionLines_$timestamp.csv"
if ($subLines.Count -gt 0) {
    $subLines | Select-Object systemId, entryNo, subscriptionNo, autoRenewal, extensionTermBackup, closed |
        Export-Csv -Path $subLinesCsvPath -NoTypeInformation -Encoding UTF8
    Write-Host "  Exported $($subLines.Count) subscription lines to $subLinesCsvPath" -ForegroundColor Green
}
else {
    Write-Host "  No subscription lines found." -ForegroundColor DarkYellow
}

# --- Backup full Subscription Lines (all fields for safety) ---
Write-Host ""
Write-Host "Fetching full Subscription Line data..." -ForegroundColor Yellow
$subLinesFullUrl = "$BaseUrl/api/skconsulting/subscriptionBilling/v1.0/companies($CompanyId)/subscriptionLines"
$subLinesFull = Invoke-BcApi -Token $token -Url $subLinesFullUrl

$subLinesFullCsvPath = Join-Path $BackupFolder "SubscriptionLines_Full_$timestamp.csv"
if ($subLinesFull.Count -gt 0) {
    $subLinesFull | Export-Csv -Path $subLinesFullCsvPath -NoTypeInformation -Encoding UTF8
    Write-Host "  Exported $($subLinesFull.Count) full subscription lines to $subLinesFullCsvPath" -ForegroundColor Green
}
else {
    Write-Host "  No subscription lines found." -ForegroundColor DarkYellow
}

# --- Backup SubQuantityHistory ---
Write-Host ""
Write-Host "Fetching Subscription Quantity History..." -ForegroundColor Yellow

$qtyHistoryUrl = "$BaseUrl/ODataV4/Company('$CompanyId')/SubQuantityHistory003SKC"
try {
    $qtyHistory = Invoke-BcApi -Token $token -Url $qtyHistoryUrl

    $qtyHistoryCsvPath = Join-Path $BackupFolder "SubQuantityHistory_$timestamp.csv"
    if ($qtyHistory.Count -gt 0) {
        $qtyHistory | Export-Csv -Path $qtyHistoryCsvPath -NoTypeInformation -Encoding UTF8
        Write-Host "  Exported $($qtyHistory.Count) quantity history records to $qtyHistoryCsvPath" -ForegroundColor Green
    }
    else {
        Write-Host "  No quantity history records found." -ForegroundColor DarkYellow
    }
}
catch {
    Write-Host "  Warning: Could not fetch SubQuantityHistory via OData. Error: $($_.Exception.Message)" -ForegroundColor DarkYellow
    Write-Host "  This table may not be exposed via OData. Manual export from BC may be needed." -ForegroundColor DarkYellow
}

# --- Summary ---
Write-Host ""
Write-Host "=== Backup Summary ===" -ForegroundColor Cyan
Write-Host "  Subscription Lines: $($subLines.Count) records"
Write-Host "  Subscription Lines (full): $($subLinesFull.Count) records"
try { Write-Host "  Quantity History: $($qtyHistory.Count) records" } catch { Write-Host "  Quantity History: N/A (see warning above)" }
Write-Host "  Files written to: $BackupFolder"
Write-Host "=== Done ===" -ForegroundColor Green
