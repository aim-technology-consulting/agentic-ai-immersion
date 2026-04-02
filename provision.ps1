#!/usr/bin/env pwsh

# ============================================================================
# Azure Resource Provisioning Script
# Creates all necessary Azure resources for the Agentic AI Immersion workshop
# ============================================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ---------------------------------------------------------------------------
# Output helpers
# ---------------------------------------------------------------------------
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

# ---------------------------------------------------------------------------
# Wait for a CognitiveServices resource to finish provisioning
# ---------------------------------------------------------------------------
function Wait-Provisioning {
    param([string]$ResourceGroup, [string]$AccountName, [string]$SubId, [string]$ProjectName = "")

    $url = if ($ProjectName) {
        "https://management.azure.com/subscriptions/$SubId/resourceGroups/$ResourceGroup/providers/Microsoft.CognitiveServices/accounts/$AccountName/projects/$ProjectName`?api-version=2025-04-01-preview"
    } else {
        $null
    }

    for ($i = 0; $i -lt 30; $i++) {
        if ($url) {
            $state = (Invoke-AzJson @("rest", "--method", "GET", "--url", $url)).properties.provisioningState
        } else {
            $state = (Invoke-AzJson @("cognitiveservices", "account", "show",
                "--name", $AccountName, "--resource-group", $ResourceGroup)).properties.provisioningState
        }
        if ($state -eq "Succeeded") { return }
        if ($state -eq "Failed")    { throw "Provisioning failed" }
        Write-Host "    ... $state, waiting 10s" -ForegroundColor DarkGray
        Start-Sleep 10
    }
    throw "Timed out waiting for provisioning"
}

# ---------------------------------------------------------------------------
# STEP 1 — Azure login & subscription
# ---------------------------------------------------------------------------
function Get-SubscriptionInfo {
    Write-Step "Verifying Azure login..."
    try { Invoke-Az @("account", "show") | Out-Null } catch {
        Write-Warn "Not logged in — running az login"
        Invoke-Az @("login") | Out-Null
    }

    $account = Invoke-AzJson @("account", "show",
        "--query", "{id:id, tenantId:tenantId, name:name}")

    Write-Success "Logged in"
    Write-Host "  Current subscription: $($account.name)" -ForegroundColor Cyan

    $confirm = Read-Host "  Use this subscription? (y/n)"
    if ($confirm -notmatch "^[Yy]$") {
        $subs = Invoke-AzJson @("account", "list",
            "--query", "[].{id:id, name:name}")
        for ($i = 0; $i -lt $subs.Count; $i++) {
            Write-Host "  $($i+1). $($subs[$i].name)  [$($subs[$i].id)]"
        }
        $sel = [int](Read-Host "  Select subscription number") - 1
        Invoke-Az @("account", "set", "--subscription", $subs[$sel].id) | Out-Null
        $account = Invoke-AzJson @("account", "show",
            "--query", "{id:id, tenantId:tenantId, name:name}")
    }

    Write-Success "Subscription: $($account.name)"
    return $account
}

# ---------------------------------------------------------------------------
# STEP 2 — Resource group
# ---------------------------------------------------------------------------
function New-WorkshopResourceGroup {
    param([string]$SubId)

    Write-Step "Creating resource group..."

    $name = Read-Host "  Enter resource group name (e.g. rg-ai-workshop)"

    # Region is fixed to North Central US — required for hosted-agents (preview feature).
    # All other workshop notebooks also work in this region.
    $location = "northcentralus"
    Write-Host "  Region: North Central US (northcentralus) — required for hosted-agents support" -ForegroundColor Cyan

    Invoke-Az @("group", "create",
        "--name", $name,
        "--location", $location,
        "--subscription", $SubId) | Out-Null

    Write-Success "Resource group '$name' created in $location"
    return @{ Name = $name; Location = $location }
}

# ---------------------------------------------------------------------------
# STEP 3 — AIServices account
# ---------------------------------------------------------------------------
function New-AIServicesAccount {
    param([string]$ResourceGroup, [string]$Location, [string]$SubId)

    Write-Step "Creating Azure AI Services account..."

    $default = "$ResourceGroup-aiservices"
    $name = Read-Host "  Account name (Enter for '$default')"
    if ([string]::IsNullOrWhiteSpace($name)) { $name = $default }

    # Custom subdomain is required before projects can be created under the account.
    # It must be globally unique — default to the account name itself.
    $customDomain = $name

    # --assign-identity is a boolean flag that takes no argument value.
    Invoke-Az @(
        "cognitiveservices", "account", "create",
        "--name",             $name,
        "--resource-group",   $ResourceGroup,
        "--kind",             "AIServices",
        "--sku",              "S0",
        "--location",         $Location,
        "--subscription",     $SubId,
        "--custom-domain",    $customDomain,
        "--assign-identity",
        "--yes"
    ) | Out-Null

    Write-Host "    waiting for provisioning..." -ForegroundColor DarkGray
    Wait-Provisioning -ResourceGroup $ResourceGroup -AccountName $name -SubId $SubId

    $resource = Invoke-AzJson @(
        "cognitiveservices", "account", "show",
        "--name",           $name,
        "--resource-group", $ResourceGroup,
        "--subscription",   $SubId
    )

    $openaiEndpoint  = $resource.properties.endpoints."OpenAI Language Model Instance API"
    $foundryEndpoint = $resource.properties.endpoints."AI Foundry API"

    Write-Success "AIServices account '$name' ready"
    Write-Success "OpenAI endpoint:  $openaiEndpoint"
    Write-Success "Foundry endpoint: $foundryEndpoint"

    return @{
        Name            = $name
        Id              = $resource.id
        OpenAIEndpoint  = $openaiEndpoint
        FoundryEndpoint = $foundryEndpoint
    }
}

# ---------------------------------------------------------------------------
# STEP 4 — AI Foundry project
# ---------------------------------------------------------------------------
function New-FoundryProject {
    param([string]$ResourceGroup, [string]$Location, [string]$SubId,
          [string]$AccountName, [string]$AccountId)

    Write-Step "Creating AI Foundry project..."

    $default = "ai-workshop"
    $projectName = Read-Host "  Project name (Enter for '$default')"
    if ([string]::IsNullOrWhiteSpace($projectName)) { $projectName = $default }

    $url  = "https://management.azure.com$AccountId/projects/$projectName`?api-version=2025-04-01-preview"
    # The identity block is required — without it the ARM API returns 400 "must enable a managed identity".
    $body = "{`"location`":`"$Location`",`"kind`":`"AIServices`",`"identity`":{`"type`":`"SystemAssigned`"},`"properties`":{}}"

    Invoke-Az @("rest", "--method", "PUT", "--url", $url, "--body", $body) | Out-Null

    Write-Host "    waiting for provisioning..." -ForegroundColor DarkGray
    Wait-Provisioning -ResourceGroup $ResourceGroup -AccountName $AccountName `
        -SubId $SubId -ProjectName $projectName

    $project = Invoke-AzJson @(
        "rest", "--method", "GET", "--url",
        "https://management.azure.com$AccountId/projects/$projectName`?api-version=2025-04-01-preview"
    )

    $endpoint   = $project.properties.endpoints."AI Foundry API"
    $resourceId = $project.id

    Write-Success "Project '$projectName' ready"
    Write-Success "Project endpoint: $endpoint"

    return @{
        Name       = $projectName
        Endpoint   = $endpoint
        ResourceId = $resourceId
    }
}

# ---------------------------------------------------------------------------
# STEP 5 — Model deployments
# ---------------------------------------------------------------------------
function New-ModelDeployments {
    param([string]$ResourceGroup, [string]$AccountName, [string]$SubId)

    Write-Step "Deploying models..."

    # List available models and let user pick chat model
    Write-Host "  Fetching available chat models..." -ForegroundColor DarkGray
    # unique_by() is not supported in az CLI's JMESPath — deduplicate on the PowerShell side instead.
    $chatModelsRaw = Invoke-AzJson @(
        "cognitiveservices", "model", "list",
        "--location", (Invoke-AzJson @("group", "show",
            "--name", $ResourceGroup, "--query", "location")).Trim('"'),
        "--query", "[?model.capabilities.chatCompletion=='true' && model.lifecycleStatus!='Deprecated'].{name:model.name, version:model.version} | sort_by(@, &name)"
    )
    $chatModels = $chatModelsRaw | Sort-Object name | Group-Object name | ForEach-Object { $_.Group[0] }

    Write-Host "`n  Available chat models:"
    for ($i = 0; $i -lt [Math]::Min($chatModels.Count, 20); $i++) {
        Write-Host "  $($i+1). $($chatModels[$i].name)"
    }
    $chatSel      = [int](Read-Host "  Select chat model number") - 1
    $chatModel    = $chatModels[$chatSel].name

    # Get versions for selected model
    # unique_by() is not supported in az CLI's JMESPath — deduplicate on the PowerShell side.
    # format is captured so it can be passed to --model-format at deployment time.
    $chatVersionsRaw = Invoke-AzJson @(
        "cognitiveservices", "model", "list",
        "--location", (Invoke-AzJson @("group", "show",
            "--name", $ResourceGroup, "--query", "location")).Trim('"'),
        "--query", "[?model.name=='$chatModel' && model.lifecycleStatus!='Deprecated'].{version:model.version, sku:model.skus[0].name, format:model.format}"
    )
    $chatVersions = $chatVersionsRaw | Group-Object version | ForEach-Object { $_.Group[0] }

    Write-Host "`n  Available versions for $chatModel`:"
    for ($i = 0; $i -lt $chatVersions.Count; $i++) {
        Write-Host "  $($i+1). $($chatVersions[$i].version)  [SKU: $($chatVersions[$i].sku)]"
    }
    $verSel      = [int](Read-Host "  Select version number") - 1
    $chatVersion = $chatVersions[$verSel].version
    $chatSku     = $chatVersions[$verSel].sku
    $chatFormat  = $chatVersions[$verSel].format

    # Deployment name
    $chatDepDefault = $chatModel
    $chatDepName    = Read-Host "  Chat deployment name (Enter for '$chatDepDefault')"
    if ([string]::IsNullOrWhiteSpace($chatDepName)) { $chatDepName = $chatDepDefault }

    Write-Host "  Deploying $chatModel ($chatVersion)..." -ForegroundColor DarkGray
    Invoke-Az @(
        "cognitiveservices", "account", "deployment", "create",
        "--resource-group", $ResourceGroup,
        "--name",           $AccountName,
        "--deployment-name",$chatDepName,
        "--model-name",     $chatModel,
        "--model-version",  $chatVersion,
        "--model-format",   $chatFormat,
        "--sku-capacity",   "50",
        "--sku-name",       $chatSku
    ) | Out-Null
    Write-Success "Chat model deployed: $chatDepName"

    # Embedding model
    $embedDefault = "text-embedding-3-large"
    Write-Host "`n  Deploying embedding model (default: $embedDefault)..." -ForegroundColor DarkGray
    # unique_by() is not supported in az CLI's JMESPath — deduplicate on the PowerShell side.
    # format and sku are captured so they can be passed to the deployment command.
    $embedModelsRaw = Invoke-AzJson @(
        "cognitiveservices", "model", "list",
        "--location", (Invoke-AzJson @("group", "show",
            "--name", $ResourceGroup, "--query", "location")).Trim('"'),
        "--query", "[?model.capabilities.embeddings=='true' && model.lifecycleStatus!='Deprecated'].{name:model.name, version:model.version, format:model.format, sku:model.skus[0].name}"
    )
    $embedModels = $embedModelsRaw | Group-Object name | ForEach-Object { $_.Group[0] }

    Write-Host "`n  Available embedding models:"
    for ($i = 0; $i -lt $embedModels.Count; $i++) {
        Write-Host "  $($i+1). $($embedModels[$i].name)"
    }
    $embedSel     = [int](Read-Host "  Select embedding model number") - 1
    $embedModel   = $embedModels[$embedSel].name
    $embedVersion = $embedModels[$embedSel].version
    $embedFormat  = $embedModels[$embedSel].format
    $embedSku     = $embedModels[$embedSel].sku
    $embedDepName = $embedModel

    Invoke-Az @(
        "cognitiveservices", "account", "deployment", "create",
        "--resource-group", $ResourceGroup,
        "--name",           $AccountName,
        "--deployment-name",$embedDepName,
        "--model-name",     $embedModel,
        "--model-version",  $embedVersion,
        "--model-format",   $embedFormat,
        "--sku-capacity",   "50",
        "--sku-name",       $embedSku
    ) | Out-Null
    Write-Success "Embedding model deployed: $embedDepName"

    return @{
        ChatDeploymentName      = $chatDepName
        EmbeddingDeploymentName = $embedDepName
    }
}

# ---------------------------------------------------------------------------
# STEP 6 — Azure AI Search (optional)
# ---------------------------------------------------------------------------
function New-SearchService {
    param([string]$ResourceGroup, [string]$Location, [string]$SubId, [string]$ProjectResourceId)

    Write-Step "Azure AI Search (optional)..."
    $include = Read-Host "  Create an Azure AI Search service? (y/n)"
    if ($include -notmatch "^[Yy]$") {
        Write-Warn "Skipping Azure AI Search"
        return @{
            Endpoint            = "<your-search-endpoint>"
            ApiKey              = "<your-search-api-key>"
            ApiVersion          = "2025-03-01-preview"
            AuthMethod          = "api-search-key"
            IndexName           = "<your-index-name>"
        }
    }

    $skus = @("free", "basic", "standard", "standard2", "standard3")
    Write-Host "`n  Available SKUs:"
    for ($i = 0; $i -lt $skus.Count; $i++) { Write-Host "  $($i+1). $($skus[$i])" }
    $skuSel  = [int](Read-Host "  Select SKU (recommend 'standard' for workshop)") - 1
    $sku     = $skus[$skuSel]

    $default = "$ResourceGroup-search"
    $name    = Read-Host "  Search service name (Enter for '$default')"
    if ([string]::IsNullOrWhiteSpace($name)) { $name = $default }

    Invoke-Az @(
        "search", "service", "create",
        "--name",           $name,
        "--resource-group", $ResourceGroup,
        "--location",       $Location,
        "--sku",            $sku,
        "--subscription",   $SubId
    ) | Out-Null

    $endpoint = "https://$name.search.windows.net"
    $key      = (Invoke-AzJson @(
        "search", "admin-key", "show",
        "--resource-group",   $ResourceGroup,
        "--service-name",     $name,
        "--subscription",     $SubId
    )).primaryKey

    $indexName = Read-Host "  Index name to use (Enter for 'workshop-index')"
    if ([string]::IsNullOrWhiteSpace($indexName)) { $indexName = "workshop-index" }

    # Register search as a connection in the Foundry project
    $connUrl  = "https://management.azure.com$ProjectResourceId/connections/$name`?api-version=2025-04-01-preview"
    $connBody = "{`"properties`":{`"category`":`"CognitiveSearch`",`"target`":`"$endpoint`",`"authType`":`"ApiKey`",`"credentials`":{`"key`":`"$key`"}}}"
    try {
        Invoke-Az @("rest", "--method", "PUT", "--url", $connUrl, "--body", $connBody) | Out-Null
        Write-Success "Search connection registered in Foundry project"
    } catch {
        Write-Warn "Could not register search connection in project (can be added manually)"
    }

    Write-Success "Search service '$name' ready: $endpoint"
    return @{
        Endpoint   = $endpoint
        ApiKey     = $key
        ApiVersion = "2025-03-01-preview"
        AuthMethod = "api-search-key"
        IndexName  = $indexName
    }
}

# ---------------------------------------------------------------------------
# STEP 7 — Bing Search connection (optional)
# ---------------------------------------------------------------------------
function New-BingConnection {
    param([string]$ResourceGroup, [string]$Location, [string]$SubId, [string]$ProjectResourceId)

    Write-Step "Bing Search grounding (optional)..."
    $include = Read-Host "  Create a Bing Search resource and connection? (y/n)"
    if ($include -notmatch "^[Yy]$") {
        Write-Warn "Skipping Bing Search"
        return @{
            ConnectionName = "<your-bing-connection-name>"
            ConnectionId   = "<your-bing-connection-id>"
        }
    }

    $default = "$ResourceGroup-bing"
    $name    = Read-Host "  Bing resource name (Enter for '$default')"
    if ([string]::IsNullOrWhiteSpace($name)) { $name = $default }

    # Create the Bing Grounding resource via Microsoft.Bing/accounts.
    # NOTE: Bing.Search.v7 (Microsoft.CognitiveServices kind) is deprecated and no longer valid.
    # The replacement is Microsoft.Bing/accounts with kind=Bing.Grounding and SKU=G1.
    $bingUrl  = "https://management.azure.com/subscriptions/$SubId/resourceGroups/$ResourceGroup/providers/Microsoft.Bing/accounts/$name`?api-version=2025-05-01-preview"
    $bingBody = "{`"location`":`"global`",`"kind`":`"Bing.Grounding`",`"sku`":{`"name`":`"G1`"},`"properties`":{}}"
    Invoke-Az @("rest", "--method", "PUT", "--url", $bingUrl, "--body", $bingBody) | Out-Null

    $bingKey = (Invoke-AzJson @(
        "rest", "--method", "POST", "--url",
        "https://management.azure.com/subscriptions/$SubId/resourceGroups/$ResourceGroup/providers/Microsoft.Bing/accounts/$name/listKeys`?api-version=2025-05-01-preview"
    )).key1

    # Register as connection in the Foundry project
    $connName = "bing-$name"
    $connUrl  = "https://management.azure.com$ProjectResourceId/connections/$connName`?api-version=2025-04-01-preview"
    $connBody = "{`"properties`":{`"category`":`"GroundingWithBingSearch`",`"target`":`"https://api.bing.microsoft.com`",`"authType`":`"ApiKey`",`"credentials`":{`"key`":`"$bingKey`"}}}"

    $conn = Invoke-AzJson @("rest", "--method", "PUT", "--url", $connUrl, "--body", $connBody)
    $connId = $conn.id

    Write-Success "Bing connection '$connName' created"
    return @{
        ConnectionName = $connName
        ConnectionId   = $connId
    }
}

# ---------------------------------------------------------------------------
# STEP 8 — Write .env
# ---------------------------------------------------------------------------
function Write-EnvFile {
    param(
        [string]$TenantId, [string]$SubId, [string]$ResourceGroup,
        [hashtable]$Account, [hashtable]$Project, [hashtable]$Models,
        [hashtable]$Search, [hashtable]$Bing,
        [string]$ApiKey
    )

    $envPath = Join-Path $PSScriptRoot ".env"

    @"
# =============================================================================
# Agentic AI Immersion Day - Environment Configuration
# Generated by provision.ps1 on $(Get-Date -Format "yyyy-MM-dd HH:mm")
# =============================================================================

# =============================================================================
# AZURE AUTHENTICATION
# =============================================================================
TENANT_ID=$TenantId
AZURE_SUBSCRIPTION_ID=$SubId
AZURE_RESOURCE_GROUP=$ResourceGroup
AZURE_PROJECT_NAME=$($Project.Name)

# =============================================================================
# Microsoft Foundry PROJECT
# =============================================================================
AI_FOUNDRY_PROJECT_ENDPOINT=$($Project.Endpoint)
AZURE_AI_PROJECT_ENDPOINT=$($Project.Endpoint)
PROJECT_RESOURCE_ID=$($Project.ResourceId)

# =============================================================================
# MODEL DEPLOYMENTS
# =============================================================================
AZURE_AI_MODEL_DEPLOYMENT_NAME=$($Models.ChatDeploymentName)
EMBEDDING_MODEL_DEPLOYMENT_NAME=$($Models.EmbeddingDeploymentName)

# =============================================================================
# AZURE OPENAI DIRECT ACCESS
# =============================================================================
AZURE_OPENAI_ENDPOINT=$($Account.OpenAIEndpoint)
AZURE_OPENAI_API_KEY=$ApiKey
AZURE_OPENAI_CHAT_DEPLOYMENT_NAME=$($Models.ChatDeploymentName)

# =============================================================================
# BING GROUNDING
# =============================================================================
GROUNDING_WITH_BING_CONNECTION_NAME=$($Bing.ConnectionName)
BING_CONNECTION_ID=$($Bing.ConnectionId)

# =============================================================================
# AZURE AI SEARCH
# =============================================================================
AZURE_AI_SEARCH_ENDPOINT=$($Search.Endpoint)
AZURE_AI_SEARCH_API_KEY=$($Search.ApiKey)
AZURE_AI_SEARCH_API_VERSION=$($Search.ApiVersion)
SEARCH_AUTHENTICATION_METHOD=$($Search.AuthMethod)
AZURE_SEARCH_INDEX_NAME=$($Search.IndexName)

# =============================================================================
# MCP TOOLS
# =============================================================================
FOUNDRY_MCP_CONNECTION_ID=<your-mcp-connection-id>

# =============================================================================
# OBSERVABILITY & TRACING
# =============================================================================
AZURE_TRACING_GEN_AI_CONTENT_RECORDING_ENABLED=true
AZURE_SDK_TRACING_IMPLEMENTATION=opentelemetry
ENABLE_SENSITIVE_DATA=true

# =============================================================================
# OPTIONAL CONFIGURATION
# =============================================================================
# APPLICATIONINSIGHTS_CONNECTION_STRING=<your-app-insights-connection-string>
# OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4317
# OTEL_SERVICE_NAME=agentic-ai-workshop
# ENABLE_CONSOLE_EXPORTERS=true
"@ | Set-Content -Path $envPath -Encoding utf8

    Write-Success ".env written to $envPath"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
function Main {
    Write-Host ""
    Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║   Azure Resource Provisioning — Agentic AI Immersion          ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""

    $account    = Get-SubscriptionInfo
    $tenantId   = $account.tenantId
    $subId      = $account.id

    $rg         = New-WorkshopResourceGroup -SubId $subId

    $aiAccount  = New-AIServicesAccount -ResourceGroup $rg.Name -Location $rg.Location -SubId $subId

    $apiKey     = (Invoke-AzJson @(
        "cognitiveservices", "account", "keys", "list",
        "--name",           $aiAccount.Name,
        "--resource-group", $rg.Name
    )).key1

    $project    = New-FoundryProject `
        -ResourceGroup $rg.Name -Location $rg.Location `
        -SubId $subId -AccountName $aiAccount.Name -AccountId $aiAccount.Id

    $models     = New-ModelDeployments -ResourceGroup $rg.Name -AccountName $aiAccount.Name -SubId $subId

    $search     = New-SearchService `
        -ResourceGroup $rg.Name -Location $rg.Location `
        -SubId $subId -ProjectResourceId $project.ResourceId

    $bing       = New-BingConnection `
        -ResourceGroup $rg.Name -Location $rg.Location `
        -SubId $subId -ProjectResourceId $project.ResourceId

    Write-EnvFile `
        -TenantId $tenantId -SubId $subId -ResourceGroup $rg.Name `
        -Account $aiAccount -Project $project -Models $models `
        -Search $search -Bing $bing -ApiKey $apiKey

    Write-Host ""
    Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║   Provisioning complete!                                       ║" -ForegroundColor Green
    Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Resource Group : $($rg.Name)" -ForegroundColor Cyan
    Write-Host "  AI Account     : $($aiAccount.Name)" -ForegroundColor Cyan
    Write-Host "  Project        : $($project.Name)" -ForegroundColor Cyan
    Write-Host "  Chat Model     : $($models.ChatDeploymentName)" -ForegroundColor Cyan
    Write-Host "  Embedding Model: $($models.EmbeddingDeploymentName)" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  .env file has been written. Start with:" -ForegroundColor White
    Write-Host "  jupyter notebook agent-framework/agents/" -ForegroundColor White
    Write-Host ""
}

Main
