#!/usr/bin/env pwsh
# teardown-search.ps1
# Deletes the Azure AI Search service and its Foundry connection, then clears
# the search keys from .env. Run this after a workshop session to stop billing.

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Step    { param([string]$msg) Write-Host "`n▶ $msg" -ForegroundColor Blue }
function Write-Success { param([string]$msg) Write-Host "  ✓ $msg" -ForegroundColor Green }
function Write-Warn    { param([string]$msg) Write-Host "  ⚠ $msg" -ForegroundColor Yellow }

# ---------------------------------------------------------------------------
# Read .env
# ---------------------------------------------------------------------------
$envPath = Join-Path $PSScriptRoot ".env"
if (-not (Test-Path $envPath)) { throw ".env not found at $envPath" }

$envVars = @{}
Get-Content $envPath | ForEach-Object {
    if ($_ -match '^\s*([^#=\s][^=]*)\s*=\s*(.*)\s*$') {
        $envVars[$Matches[1].Trim()] = $Matches[2].Trim()
    }
}

$subId             = $envVars["AZURE_SUBSCRIPTION_ID"]
$resourceGroup     = $envVars["AZURE_RESOURCE_GROUP"]
$projectResourceId = $envVars["PROJECT_RESOURCE_ID"]
$searchEndpoint    = $envVars["AZURE_AI_SEARCH_ENDPOINT"]

if (-not $subId -or -not $resourceGroup -or -not $projectResourceId) {
    throw "Missing AZURE_SUBSCRIPTION_ID, AZURE_RESOURCE_GROUP, or PROJECT_RESOURCE_ID in .env"
}

# Derive service name from endpoint URL
if ([string]::IsNullOrWhiteSpace($searchEndpoint) -or $searchEndpoint -eq "<your-search-endpoint>") {
    Write-Warn "AZURE_AI_SEARCH_ENDPOINT is not set — nothing to delete"
    exit 0
}
$serviceName = ([uri]$searchEndpoint).Host.Split('.')[0]

# ---------------------------------------------------------------------------
# Confirm
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "  About to DELETE:" -ForegroundColor Yellow
Write-Host "    Search service : $serviceName" -ForegroundColor Yellow
Write-Host "    Foundry connection: $serviceName" -ForegroundColor Yellow
Write-Host ""
$confirm = Read-Host "  Confirm deletion? (y/N)"
if ($confirm -notmatch "^[Yy]$") {
    Write-Warn "Cancelled"
    exit 0
}

# ---------------------------------------------------------------------------
# Delete Foundry connection
# ---------------------------------------------------------------------------
Write-Step "Removing Foundry connection '$serviceName'..."
try {
    az rest --method DELETE `
        --url "https://management.azure.com$projectResourceId/connections/$serviceName" `
        --url-parameters "api-version=2025-04-01-preview" | Out-Null
    Write-Success "Foundry connection deleted"
}
catch {
    Write-Warn "Could not delete Foundry connection (may not exist): $($_.Exception.Message)"
}

# ---------------------------------------------------------------------------
# Delete search service
# ---------------------------------------------------------------------------
Write-Step "Deleting search service '$serviceName'..."
try {
    az search service delete `
        --name $serviceName `
        --resource-group $resourceGroup `
        --subscription $subId `
        --yes | Out-Null
    Write-Success "Search service deleted"
}
catch {
    Write-Warn "Could not delete search service: $($_.Exception.Message)"
}

# ---------------------------------------------------------------------------
# Clear search values in .env
# ---------------------------------------------------------------------------
Write-Step "Clearing search values in .env..."

$content = Get-Content $envPath -Raw
$content = $content -replace '(?m)^AZURE_AI_SEARCH_ENDPOINT=.*$', "AZURE_AI_SEARCH_ENDPOINT=<not-provisioned>"
$content = $content -replace '(?m)^AZURE_AI_SEARCH_API_KEY=.*$',  "AZURE_AI_SEARCH_API_KEY=<not-provisioned>"

Set-Content -Path $envPath -Value $content.TrimEnd() -Encoding utf8
Write-Success ".env cleared"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║  Search service torn down — billing stopped                    ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "  Run setup-search.ps1 before the next workshop session." -ForegroundColor White
Write-Host ""
