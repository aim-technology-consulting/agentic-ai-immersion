#!/usr/bin/env pwsh

# ============================================================================
# Patch: Grant project managed identity access to Azure AI Search
#
# Run this once against any environment provisioned before April 2026.
# New environments provisioned with provision.ps1 get this automatically.
# ============================================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Step    { param([string]$msg) Write-Host "`n▶ $msg" -ForegroundColor Blue }
function Write-Success { param([string]$msg) Write-Host "  ✓ $msg" -ForegroundColor Green }
function Write-Warn    { param([string]$msg) Write-Host "  ⚠ $msg" -ForegroundColor Yellow }
function Write-Err     { param([string]$msg) Write-Host "  ✗ $msg" -ForegroundColor Red }

function Invoke-Az {
    param([string[]]$Arguments)
    $output = az @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Err "az $($Arguments -join ' ') failed:`n$output"
        throw "Azure CLI error"
    }
    return $output
}

function Invoke-AzJson {
    param([string[]]$Arguments)
    return (Invoke-Az ($Arguments + @("-o", "json"))) | ConvertFrom-Json
}

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   Patch: Search Roles for Project Managed Identity            ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# ---------------------------------------------------------------------------
# Read .env
# ---------------------------------------------------------------------------
Write-Step "Reading .env..."
$envFile = Join-Path $PSScriptRoot ".env"
if (-not (Test-Path $envFile)) {
    Write-Err ".env not found — run from the repo root"
    exit 1
}

$env = @{}
Get-Content $envFile | Where-Object { $_ -match '^\s*[^#]\S+=\S' } | ForEach-Object {
    $parts = $_ -split '=', 2
    $env[$parts[0].Trim()] = $parts[1].Trim()
}

$subId             = $env['AZURE_SUBSCRIPTION_ID']
$rgName            = $env['AZURE_RESOURCE_GROUP']
$projectResourceId = $env['PROJECT_RESOURCE_ID']

Write-Success "Subscription : $subId"
Write-Success "Resource group: $rgName"

# ---------------------------------------------------------------------------
# Login
# ---------------------------------------------------------------------------
Write-Step "Verifying Azure login..."
try { Invoke-Az @("account", "show") | Out-Null } catch {
    Invoke-Az @("login") | Out-Null
}
$current = Invoke-AzJson @("account", "show", "--query", "{id:id, name:name}")
if ($current.id -ne $subId) {
    Invoke-Az @("account", "set", "--subscription", $subId) | Out-Null
}
Write-Success "Logged in"

# ---------------------------------------------------------------------------
# Get project managed identity principal ID
# ---------------------------------------------------------------------------
Write-Step "Getting project managed identity..."
$project = Invoke-AzJson @(
    "rest", "--method", "GET",
    "--url", "https://management.azure.com$projectResourceId`?api-version=2025-04-01-preview"
)
$principalId = $project.identity.principalId
if (-not $principalId) {
    Write-Err "Could not read managed identity from project — is SystemAssigned identity enabled?"
    exit 1
}
Write-Success "Principal ID: $principalId"

# ---------------------------------------------------------------------------
# Find search service in the resource group
# ---------------------------------------------------------------------------
Write-Step "Finding Azure AI Search service..."
$searchServices = Invoke-AzJson @(
    "search", "service", "list",
    "--resource-group", $rgName,
    "--subscription", $subId
)
if ($searchServices.Count -eq 0) {
    Write-Warn "No Azure AI Search service found in '$rgName' — nothing to patch"
    exit 0
}
$searchId = $searchServices[0].id
Write-Success "Search service: $($searchServices[0].name)"

# ---------------------------------------------------------------------------
# Assign roles
# ---------------------------------------------------------------------------
Write-Step "Assigning search roles to project managed identity..."

foreach ($role in @("Search Index Data Contributor", "Search Index Data Reader")) {
    $existing = Invoke-AzJson @(
        "role", "assignment", "list",
        "--assignee", $principalId,
        "--role", $role,
        "--scope", $searchId,
        "--query", "length(@)"
    )
    if ($existing -gt 0) {
        Write-Warn "Already has '$role' — skipping"
        continue
    }
    Invoke-Az @(
        "role", "assignment", "create",
        "--assignee-object-id", $principalId,
        "--assignee-principal-type", "ServicePrincipal",
        "--role", $role,
        "--scope", $searchId
    ) | Out-Null
    Write-Success "Assigned '$role'"
}

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║   Patch complete                                               ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
