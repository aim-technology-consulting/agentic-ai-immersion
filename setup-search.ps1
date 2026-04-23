#!/usr/bin/env pwsh
# setup-search.ps1
# Creates an Azure AI Search service (Standard S1) and registers it in the
# Foundry project, then patches .env. Run this before a workshop session.

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Step    { param([string]$msg) Write-Host "`n▶ $msg" -ForegroundColor Blue }
function Write-Success { param([string]$msg) Write-Host "  ✓ $msg" -ForegroundColor Green }
function Write-Warn    { param([string]$msg) Write-Host "  ⚠ $msg" -ForegroundColor Yellow }

# ---------------------------------------------------------------------------
# Read .env
# ---------------------------------------------------------------------------
$envPath = Join-Path $PSScriptRoot ".env"
if (-not (Test-Path $envPath)) { throw ".env not found at $envPath — run provision.ps1 first" }

$envVars = @{}
Get-Content $envPath | ForEach-Object {
    if ($_ -match '^\s*([^#=\s][^=]*)\s*=\s*(.*)\s*$') {
        $envVars[$Matches[1].Trim()] = $Matches[2].Trim()
    }
}

$subId             = $envVars["AZURE_SUBSCRIPTION_ID"]
$resourceGroup     = $envVars["AZURE_RESOURCE_GROUP"]
$projectResourceId = $envVars["PROJECT_RESOURCE_ID"]

if (-not $subId -or -not $resourceGroup -or -not $projectResourceId) {
    throw "Missing AZURE_SUBSCRIPTION_ID, AZURE_RESOURCE_GROUP, or PROJECT_RESOURCE_ID in .env"
}

Write-Step "Read from .env"
Write-Host "  Subscription : $subId" -ForegroundColor Cyan
Write-Host "  Resource Group: $resourceGroup" -ForegroundColor Cyan

# ---------------------------------------------------------------------------
# Create search service
# ---------------------------------------------------------------------------
Write-Step "Creating Azure AI Search service (Standard, Central US)..."

$suffix  = -join ((97..122) | Get-Random -Count 4 | ForEach-Object { [char]$_ })
$name    = "$resourceGroup-search-$suffix"
$location = "centralus"

$created = $false
while (-not $created) {
    try {
        az search service create `
            --name $name `
            --resource-group $resourceGroup `
            --location $location `
            --sku standard `
            --subscription $subId | Out-Null
        $created = $true
    }
    catch {
        $msg = $_.Exception.Message
        if ($msg -match "already exists") {
            $suffix = -join ((97..122) | Get-Random -Count 4 | ForEach-Object { [char]$_ })
            $name   = "$resourceGroup-search-$suffix"
            Write-Warn "Name collision — retrying as '$name'"
        }
        elseif ($msg -match "InsufficientResourcesAvailable") {
            Write-Warn "No capacity in $location"
            $location = Read-Host "  Enter alternate region (Enter for 'eastus')"
            if ([string]::IsNullOrWhiteSpace($location)) { $location = "eastus" }
        }
        else { throw }
    }
}

Write-Success "Search service '$name' created — waiting for it to be ready..."

# Poll until running (typically 3-6 min for Standard)
for ($i = 0; $i -lt 40; $i++) {
    $status = (az search service show `
        --name $name `
        --resource-group $resourceGroup `
        --subscription $subId `
        --query "status" -o tsv 2>$null).Trim()
    if ($status -eq "running") { break }
    Write-Host "    ... $status, waiting 15s ($([int]($i*15/60))m $($i*15 % 60)s elapsed)" -ForegroundColor DarkGray
    Start-Sleep 15
}
if ($status -ne "running") { throw "Search service did not reach 'running' status in time" }
Write-Success "Service is running"

# ---------------------------------------------------------------------------
# Get admin key
# ---------------------------------------------------------------------------
Write-Step "Retrieving admin key..."
$adminKey = (az search admin-key show `
    --resource-group $resourceGroup `
    --service-name $name `
    --subscription $subId `
    --query "primaryKey" -o tsv).Trim()
Write-Success "Admin key retrieved"

# ---------------------------------------------------------------------------
# Register as Foundry connection
# ---------------------------------------------------------------------------
Write-Step "Registering search connection in Foundry project..."

$endpoint  = "https://$name.search.windows.net"
$connUrl   = "https://management.azure.com$projectResourceId/connections/$name"
$connBody  = "{`"properties`":{`"category`":`"CognitiveSearch`",`"target`":`"$endpoint`",`"authType`":`"ApiKey`",`"credentials`":{`"key`":`"$adminKey`"}}}"

az rest --method PUT --url $connUrl `
    --url-parameters "api-version=2025-04-01-preview" `
    --headers "Content-Type=application/json" `
    --body $connBody | Out-Null

Write-Success "Foundry connection '$name' registered"

# ---------------------------------------------------------------------------
# Patch .env
# ---------------------------------------------------------------------------
Write-Step "Updating .env..."

$content = Get-Content $envPath -Raw

$content = $content -replace '(?m)^AZURE_AI_SEARCH_ENDPOINT=.*$', "AZURE_AI_SEARCH_ENDPOINT=$endpoint"
$content = $content -replace '(?m)^AZURE_AI_SEARCH_API_KEY=.*$',  "AZURE_AI_SEARCH_API_KEY=$adminKey"

Set-Content -Path $envPath -Value $content.TrimEnd() -Encoding utf8

Write-Success ".env updated"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║  Search service ready                                          ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "  Service  : $name" -ForegroundColor Cyan
Write-Host "  Endpoint : $endpoint" -ForegroundColor Cyan
Write-Host "  Connection: $name (registered in Foundry project)" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Run teardown-search.ps1 after the workshop to stop billing." -ForegroundColor White
Write-Host ""
