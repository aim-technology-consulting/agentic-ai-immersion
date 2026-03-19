#!/bin/bash

# ============================================================================
# Azure Environment Setup Script
# This script collects necessary Azure values and populates the .env file
# ============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_step() {
    echo -e "${BLUE}▶ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Function to check if Azure CLI is installed
check_azure_cli() {
    if ! command -v az &> /dev/null; then
        print_error "Azure CLI is not installed"
        echo "Install it from: https://learn.microsoft.com/en-us/cli/azure/install-azure-cli"
        exit 1
    fi
    print_success "Azure CLI found"
}

# Function to verify Azure login
verify_azure_login() {
    print_step "Verifying Azure login..."
    if ! az account show &> /dev/null; then
        print_warning "Not logged into Azure. Running 'az login'..."
        az login
    fi
    print_success "Azure login verified"
}

# Function to get current subscription
get_subscription_info() {
    print_step "Getting subscription information..."

    CURRENT_ACCOUNT=$(az account show --query '{subscriptionId:id, tenantId:tenantId, subscriptionName:name}' -o json)

    AZURE_SUBSCRIPTION_ID=$(echo $CURRENT_ACCOUNT | jq -r '.subscriptionId')
    TENANT_ID=$(echo $CURRENT_ACCOUNT | jq -r '.tenantId')
    CURRENT_SUB_NAME=$(echo $CURRENT_ACCOUNT | jq -r '.subscriptionName')

    echo "Current subscription: $CURRENT_SUB_NAME"
    read -p "Use this subscription? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_step "Select a different subscription..."
        SUBSCRIPTIONS=$(az account list --query '[].{id:id, name:name}' -o json)
        echo "Available subscriptions:"
        echo $SUBSCRIPTIONS | jq -r '.[] | "\(.id) - \(.name)"' | nl

        read -p "Enter subscription index (or paste ID): " SUB_INPUT

        if [ ! -z "$SUB_INPUT" ] && [ "$SUB_INPUT" -eq "$SUB_INPUT" ] 2>/dev/null; then
            AZURE_SUBSCRIPTION_ID=$(echo $SUBSCRIPTIONS | jq -r ".[$((SUB_INPUT-1))].id")
        else
            AZURE_SUBSCRIPTION_ID="$SUB_INPUT"
        fi

        az account set --subscription "$AZURE_SUBSCRIPTION_ID"
        TENANT_ID=$(az account show --query 'tenantId' -o tsv)
    fi

    print_success "Subscription ID: $AZURE_SUBSCRIPTION_ID"
    print_success "Tenant ID: $TENANT_ID"
}

# Function to select/create resource group
get_resource_group() {
    print_step "Selecting resource group..."

    RESOURCE_GROUPS=$(az group list --subscription "$AZURE_SUBSCRIPTION_ID" --query '[].{name:name}' -o json)
    RG_COUNT=$(echo $RESOURCE_GROUPS | jq 'length')

    if [ "$RG_COUNT" -eq 0 ]; then
        print_warning "No existing resource groups found"
        read -p "Enter new resource group name: " AZURE_RESOURCE_GROUP
        read -p "Enter region (e.g., eastus, westus, eastus2): " REGION
        az group create --name "$AZURE_RESOURCE_GROUP" --location "$REGION" --subscription "$AZURE_SUBSCRIPTION_ID"
        print_success "Resource group created: $AZURE_RESOURCE_GROUP"
    else
        echo "Available resource groups:"
        echo $RESOURCE_GROUPS | jq -r '.[] | .name' | nl
        echo "$(($RG_COUNT + 1)). Create new resource group"

        read -p "Enter resource group index (1-$((RG_COUNT+1))): " RG_INPUT

        if [ "$RG_INPUT" -eq "$((RG_COUNT + 1))" ] 2>/dev/null; then
            read -p "Enter new resource group name: " AZURE_RESOURCE_GROUP
            read -p "Enter region (e.g., eastus, westus, eastus2): " REGION
            az group create --name "$AZURE_RESOURCE_GROUP" --location "$REGION" --subscription "$AZURE_SUBSCRIPTION_ID"
            print_success "Resource group created: $AZURE_RESOURCE_GROUP"
        elif [ ! -z "$RG_INPUT" ] && [ "$RG_INPUT" -eq "$RG_INPUT" ] 2>/dev/null; then
            AZURE_RESOURCE_GROUP=$(echo $RESOURCE_GROUPS | jq -r ".[$((RG_INPUT-1))].name")
        else
            print_error "Invalid selection"
            exit 1
        fi
    fi

    print_success "Resource group: $AZURE_RESOURCE_GROUP"
}

# Function to get AI Foundry project details
get_ai_foundry_details() {
    print_step "Getting Azure AI Foundry project details..."

    echo "Looking for AIServices accounts in resource group: $AZURE_RESOURCE_GROUP"

    ACCOUNTS=$(az cognitiveservices account list \
        --resource-group "$AZURE_RESOURCE_GROUP" \
        --subscription "$AZURE_SUBSCRIPTION_ID" \
        --query '[?kind==`AIServices`].{name:name, id:id}' -o json)

    ACCOUNT_COUNT=$(echo $ACCOUNTS | jq 'length')

    if [ "$ACCOUNT_COUNT" -eq 0 ]; then
        print_error "No AIServices resources found in resource group $AZURE_RESOURCE_GROUP"
        exit 1
    elif [ "$ACCOUNT_COUNT" -eq 1 ]; then
        ACCOUNT_INDEX=0
        print_success "Using AI resource: $(echo $ACCOUNTS | jq -r '.[0].name')"
    else
        echo "Available AIServices accounts:"
        echo $ACCOUNTS | jq -r '.[].name' | nl
        read -p "Enter account index (1-$ACCOUNT_COUNT): " ACCOUNT_INPUT
        ACCOUNT_INDEX=$((ACCOUNT_INPUT-1))
    fi

    FOUNDRY_ACCOUNT_NAME=$(echo $ACCOUNTS | jq -r ".[$ACCOUNT_INDEX].name")
    FOUNDRY_ACCOUNT_ID=$(echo $ACCOUNTS | jq -r ".[$ACCOUNT_INDEX].id")

    # List projects under the selected account
    print_step "Listing projects under: $FOUNDRY_ACCOUNT_NAME"

    PROJECTS_JSON=$(az rest --method GET \
        --url "https://management.azure.com${FOUNDRY_ACCOUNT_ID}/projects?api-version=2025-04-01-preview" \
        --query 'value[].{name:name, id:id, endpoint:properties.endpoints."AI Foundry API"}' -o json)

    PROJECT_COUNT=$(echo $PROJECTS_JSON | jq 'length')

    if [ "$PROJECT_COUNT" -eq 0 ]; then
        print_error "No projects found under account $FOUNDRY_ACCOUNT_NAME"
        exit 1
    elif [ "$PROJECT_COUNT" -eq 1 ]; then
        PROJECT_INDEX=0
        AZURE_PROJECT_NAME=$(echo $PROJECTS_JSON | jq -r '.[0].name | split("/")[-1]')
        print_success "Using project: $AZURE_PROJECT_NAME"
    else
        echo "Available projects:"
        echo $PROJECTS_JSON | jq -r '.[].name | split("/")[-1]' | nl
        read -p "Enter project index (1-$PROJECT_COUNT): " PROJECT_INPUT
        PROJECT_INDEX=$((PROJECT_INPUT-1))
        AZURE_PROJECT_NAME=$(echo $PROJECTS_JSON | jq -r ".[$PROJECT_INDEX].name | split(\"/\")[-1]")
    fi

    AI_FOUNDRY_PROJECT_ENDPOINT=$(echo $PROJECTS_JSON | jq -r ".[$PROJECT_INDEX].endpoint")
    PROJECT_RESOURCE_ID=$(echo $PROJECTS_JSON | jq -r ".[$PROJECT_INDEX].id")

    print_success "Project endpoint: $AI_FOUNDRY_PROJECT_ENDPOINT"
    print_success "Project resource ID: $PROJECT_RESOURCE_ID"
    print_success "Project name: $AZURE_PROJECT_NAME"
}

# Function to get OpenAI deployments — auto-discovered from the selected AIServices account
get_openai_details() {
    print_step "Getting Azure OpenAI deployment details..."

    # Get endpoints and key from the AIServices account
    FOUNDRY_RESOURCE=$(az cognitiveservices account show \
        --name "$FOUNDRY_ACCOUNT_NAME" \
        --resource-group "$AZURE_RESOURCE_GROUP" \
        --subscription "$AZURE_SUBSCRIPTION_ID" -o json)

    AZURE_OPENAI_ENDPOINT=$(echo $FOUNDRY_RESOURCE | jq -r \
        '.properties.endpoints["OpenAI Language Model Instance API"] // empty')

    if [ -z "$AZURE_OPENAI_ENDPOINT" ]; then
        print_error "Could not determine Azure OpenAI endpoint from resource $FOUNDRY_ACCOUNT_NAME"
        exit 1
    fi

    # Auto-fetch API key
    AZURE_OPENAI_API_KEY=$(az cognitiveservices account keys list \
        --name "$FOUNDRY_ACCOUNT_NAME" \
        --resource-group "$AZURE_RESOURCE_GROUP" \
        --subscription "$AZURE_SUBSCRIPTION_ID" \
        --query 'key1' -o tsv)

    print_success "OpenAI endpoint: $AZURE_OPENAI_ENDPOINT"
    print_success "API key: retrieved"

    # List deployments and let user select
    DEPLOYMENTS=$(az cognitiveservices account deployment list \
        --resource-group "$AZURE_RESOURCE_GROUP" \
        --name "$FOUNDRY_ACCOUNT_NAME" \
        --query '[].{name:name, model:properties.model.name}' -o json)

    DEPLOYMENT_COUNT=$(echo $DEPLOYMENTS | jq 'length')

    if [ "$DEPLOYMENT_COUNT" -eq 0 ]; then
        print_error "No model deployments found under $FOUNDRY_ACCOUNT_NAME"
        exit 1
    fi

    echo "Available model deployments:"
    echo $DEPLOYMENTS | jq -r '.[] | "\(.name)  [\(.model)]"' | nl

    read -p "Select chat model deployment index: " CHAT_INPUT
    AZURE_OPENAI_CHAT_DEPLOYMENT_NAME=$(echo $DEPLOYMENTS | jq -r ".[$((CHAT_INPUT-1))].name")
    AZURE_AI_MODEL_DEPLOYMENT_NAME="$AZURE_OPENAI_CHAT_DEPLOYMENT_NAME"

    echo ""
    echo $DEPLOYMENTS | jq -r '.[] | "\(.name)  [\(.model)]"' | nl
    read -p "Select embedding model deployment index (Enter to use default 'text-embedding-3-large'): " EMBED_INPUT
    if [ ! -z "$EMBED_INPUT" ] && [ "$EMBED_INPUT" -eq "$EMBED_INPUT" ] 2>/dev/null; then
        EMBEDDING_MODEL_DEPLOYMENT_NAME=$(echo $DEPLOYMENTS | jq -r ".[$((EMBED_INPUT-1))].name")
    else
        EMBEDDING_MODEL_DEPLOYMENT_NAME="text-embedding-3-large"
    fi

    print_success "Chat model: $AZURE_OPENAI_CHAT_DEPLOYMENT_NAME"
    print_success "Embedding model: $EMBEDDING_MODEL_DEPLOYMENT_NAME"
}

# Helper: list connections for the selected project
list_project_connections() {
    az rest --method GET \
        --url "https://management.azure.com${PROJECT_RESOURCE_ID}/connections?api-version=2025-04-01-preview" \
        --query 'value[].{name:name, id:id, category:properties.category}' -o json 2>/dev/null \
        || echo "[]"
}

# Function to get Azure AI Search details
get_search_details() {
    print_step "Configuring Azure AI Search (optional)..."

    # First try connections in the project
    ALL_CONNECTIONS=$(list_project_connections)
    SEARCH_CONNECTIONS=$(echo $ALL_CONNECTIONS | jq '[.[] | select(.category == "CognitiveSearch" or (.name | ascii_downcase | test("search")))]')
    SEARCH_COUNT=$(echo $SEARCH_CONNECTIONS | jq 'length')

    if [ "$SEARCH_COUNT" -gt 0 ]; then
        echo "Available Azure AI Search connections in project:"
        echo $SEARCH_CONNECTIONS | jq -r '.[].name | split("/")[-1]' | nl
        echo "$((SEARCH_COUNT + 1)). Skip (use placeholders)"
        read -p "Enter selection (1-$((SEARCH_COUNT+1))): " SEARCH_INPUT

        if [ "$SEARCH_INPUT" -ne "$((SEARCH_COUNT + 1))" ] 2>/dev/null; then
            SEARCH_IDX=$((SEARCH_INPUT-1))
            AZURE_SEARCH_INDEX_NAME=$(echo $SEARCH_CONNECTIONS | jq -r ".[$SEARCH_IDX].name | split(\"/\")[-1]")
            # Get endpoint and key from the connection details
            SEARCH_CONN_ID=$(echo $SEARCH_CONNECTIONS | jq -r ".[$SEARCH_IDX].id")
            SEARCH_CONN=$(az rest --method GET --url "https://management.azure.com${SEARCH_CONN_ID}?api-version=2025-04-01-preview" -o json 2>/dev/null)
            AZURE_AI_SEARCH_ENDPOINT=$(echo $SEARCH_CONN | jq -r '.properties.target // empty')
            AZURE_AI_SEARCH_API_KEY=$(echo $SEARCH_CONN | jq -r '.properties.credentials.key // empty')
            AZURE_AI_SEARCH_API_VERSION="2025-03-01-preview"
            SEARCH_AUTHENTICATION_METHOD="api-search-key"
            print_success "Azure AI Search configured from project connection"
            return
        fi
    fi

    # Fall back to listing Azure Search services in the subscription
    SEARCH_SERVICES=$(az search service list \
        --resource-group "$AZURE_RESOURCE_GROUP" \
        --query '[].{name:name, endpoint:join("", ["https://", name, ".search.windows.net"])}' \
        -o json 2>/dev/null || echo "[]")
    SERVICE_COUNT=$(echo $SEARCH_SERVICES | jq 'length')

    if [ "$SERVICE_COUNT" -gt 0 ]; then
        echo "Available Azure AI Search services in resource group:"
        echo $SEARCH_SERVICES | jq -r '.[].name' | nl
        echo "$((SERVICE_COUNT + 1)). Skip (use placeholders)"
        read -p "Enter selection (1-$((SERVICE_COUNT+1))): " SEARCH_INPUT

        if [ "$SEARCH_INPUT" -ne "$((SERVICE_COUNT + 1))" ] 2>/dev/null; then
            SEARCH_IDX=$((SEARCH_INPUT-1))
            SEARCH_SERVICE_NAME=$(echo $SEARCH_SERVICES | jq -r ".[$SEARCH_IDX].name")
            AZURE_AI_SEARCH_ENDPOINT=$(echo $SEARCH_SERVICES | jq -r ".[$SEARCH_IDX].endpoint")
            AZURE_AI_SEARCH_API_KEY=$(az search admin-key show \
                --resource-group "$AZURE_RESOURCE_GROUP" \
                --service-name "$SEARCH_SERVICE_NAME" \
                --query 'primaryKey' -o tsv)
            read -p "Enter search index name: " AZURE_SEARCH_INDEX_NAME
            AZURE_AI_SEARCH_API_VERSION="2025-03-01-preview"
            SEARCH_AUTHENTICATION_METHOD="api-search-key"
            print_success "Azure AI Search configured"
            return
        fi
    fi

    # Nothing found / skipped
    AZURE_AI_SEARCH_ENDPOINT="<your-search-endpoint>"
    AZURE_AI_SEARCH_API_KEY="<your-search-api-key>"
    AZURE_AI_SEARCH_API_VERSION="2025-03-01-preview"
    SEARCH_AUTHENTICATION_METHOD="api-search-key"
    AZURE_SEARCH_INDEX_NAME="<your-index-name>"
    print_warning "Azure AI Search configuration skipped"
}

# Function to get Bing Search connection (from project connections)
get_bing_connection() {
    print_step "Configuring Bing Search grounding (optional)..."

    ALL_CONNECTIONS=$(list_project_connections)
    BING_CONNECTIONS=$(echo $ALL_CONNECTIONS | jq '[.[] | select(.category == "GroundingWithBingSearch" or (.name | ascii_downcase | test("bing")))]')
    BING_COUNT=$(echo $BING_CONNECTIONS | jq 'length')

    if [ "$BING_COUNT" -eq 0 ]; then
        print_warning "No Bing Search connections found in project — skipping"
        GROUNDING_WITH_BING_CONNECTION_NAME="<your-bing-connection-name>"
        BING_CONNECTION_ID="<your-bing-connection-id>"
        return
    fi

    echo "Available Bing Search connections:"
    echo $BING_CONNECTIONS | jq -r '.[].name | split("/")[-1]' | nl
    echo "$((BING_COUNT + 1)). Skip (use placeholders)"
    read -p "Enter selection (1-$((BING_COUNT+1))): " BING_INPUT

    if [ "$BING_INPUT" -eq "$((BING_COUNT + 1))" ] 2>/dev/null; then
        GROUNDING_WITH_BING_CONNECTION_NAME="<your-bing-connection-name>"
        BING_CONNECTION_ID="<your-bing-connection-id>"
        print_warning "Bing Search configuration skipped"
    else
        BING_IDX=$((BING_INPUT-1))
        GROUNDING_WITH_BING_CONNECTION_NAME=$(echo $BING_CONNECTIONS | jq -r ".[$BING_IDX].name | split(\"/\")[-1]")
        BING_CONNECTION_ID=$(echo $BING_CONNECTIONS | jq -r ".[$BING_IDX].id")
        print_success "Bing connection: $GROUNDING_WITH_BING_CONNECTION_NAME"
    fi
}

# Function to get MCP connection (from project connections)
get_mcp_connection() {
    print_step "Configuring MCP Tools (optional)..."

    ALL_CONNECTIONS=$(list_project_connections)
    MCP_CONNECTIONS=$(echo $ALL_CONNECTIONS | jq '[.[] | select(.category == "MCP" or (.name | ascii_downcase | test("mcp")))]')
    MCP_COUNT=$(echo $MCP_CONNECTIONS | jq 'length')

    if [ "$MCP_COUNT" -eq 0 ]; then
        print_warning "No MCP connections found in project — skipping"
        FOUNDRY_MCP_CONNECTION_ID="<your-mcp-connection-id>"
        return
    fi

    echo "Available MCP connections:"
    echo $MCP_CONNECTIONS | jq -r '.[].name | split("/")[-1]' | nl
    echo "$((MCP_COUNT + 1)). Skip (use placeholders)"
    read -p "Enter selection (1-$((MCP_COUNT+1))): " MCP_INPUT

    if [ "$MCP_INPUT" -eq "$((MCP_COUNT + 1))" ] 2>/dev/null; then
        FOUNDRY_MCP_CONNECTION_ID="<your-mcp-connection-id>"
        print_warning "MCP connection configuration skipped"
    else
        MCP_IDX=$((MCP_INPUT-1))
        FOUNDRY_MCP_CONNECTION_ID=$(echo $MCP_CONNECTIONS | jq -r ".[$MCP_IDX].id")
        print_success "MCP connection configured"
    fi
}

# Function to create .env file
create_env_file() {
    print_step "Creating .env file..."

    cat > .env << 'EOF'
# =============================================================================
# 🚀 Agentic AI Immersion Day - Environment Configuration
# =============================================================================
# This file contains all environment variables needed for the workshop.
# =============================================================================

# =============================================================================
# 🔐 AZURE AUTHENTICATION (Required for all notebooks)
# =============================================================================

EOF

    cat >> .env << EOF
TENANT_ID=$TENANT_ID
AZURE_SUBSCRIPTION_ID=$AZURE_SUBSCRIPTION_ID
AZURE_RESOURCE_GROUP=$AZURE_RESOURCE_GROUP
AZURE_PROJECT_NAME=$AZURE_PROJECT_NAME

# =============================================================================
# 🤖 Microsoft Foundry PROJECT (Required for azure-ai-agents/ notebooks)
# =============================================================================

AI_FOUNDRY_PROJECT_ENDPOINT=$AI_FOUNDRY_PROJECT_ENDPOINT
PROJECT_RESOURCE_ID=$PROJECT_RESOURCE_ID

# =============================================================================
# 🧠 MODEL DEPLOYMENTS (Required)
# =============================================================================

AZURE_AI_MODEL_DEPLOYMENT_NAME=$AZURE_AI_MODEL_DEPLOYMENT_NAME
EMBEDDING_MODEL_DEPLOYMENT_NAME=$EMBEDDING_MODEL_DEPLOYMENT_NAME

# =============================================================================
# 🔗 AZURE OPENAI DIRECT ACCESS (Required for Agent Framework)
# =============================================================================

AZURE_OPENAI_ENDPOINT=$AZURE_OPENAI_ENDPOINT
AZURE_OPENAI_API_KEY=$AZURE_OPENAI_API_KEY
AZURE_OPENAI_CHAT_DEPLOYMENT_NAME=$AZURE_OPENAI_CHAT_DEPLOYMENT_NAME

# =============================================================================
# 🌐 BING GROUNDING (Required for Bing search notebooks)
# =============================================================================

GROUNDING_WITH_BING_CONNECTION_NAME=$GROUNDING_WITH_BING_CONNECTION_NAME
BING_CONNECTION_ID=$BING_CONNECTION_ID

# =============================================================================
# 🔍 AZURE AI SEARCH / FOUNDRY IQ (Required for search & knowledge notebooks)
# =============================================================================

AZURE_AI_SEARCH_ENDPOINT=$AZURE_AI_SEARCH_ENDPOINT
AZURE_AI_SEARCH_API_KEY=$AZURE_AI_SEARCH_API_KEY
AZURE_AI_SEARCH_API_VERSION=$AZURE_AI_SEARCH_API_VERSION
SEARCH_AUTHENTICATION_METHOD=$SEARCH_AUTHENTICATION_METHOD
AZURE_SEARCH_INDEX_NAME=$AZURE_SEARCH_INDEX_NAME

# =============================================================================
# 🔧 MCP TOOLS (Required for 7-mcp-tools.ipynb)
# =============================================================================

FOUNDRY_MCP_CONNECTION_ID=$FOUNDRY_MCP_CONNECTION_ID

# =============================================================================
# 📊 OBSERVABILITY & TRACING (Required for observability notebooks)
# =============================================================================

AZURE_TRACING_GEN_AI_CONTENT_RECORDING_ENABLED=true
AZURE_SDK_TRACING_IMPLEMENTATION=opentelemetry
ENABLE_SENSITIVE_DATA=true

# =============================================================================
# OPTIONAL CONFIGURATION
# =============================================================================
# Application Insights (auto-discovered from project if not set)
# APPLICATIONINSIGHTS_CONNECTION_STRING=<your-app-insights-connection-string>

# OTLP Endpoint for Aspire Dashboard, Jaeger, etc.
# OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4317
# OTEL_SERVICE_NAME=agentic-ai-workshop

# Console exporters for debugging
# ENABLE_CONSOLE_EXPORTERS=true
EOF

    print_success ".env file created successfully!"
    echo ""
    echo "📋 Summary of configured values:"
    echo "  Subscription: $AZURE_SUBSCRIPTION_ID"
    echo "  Resource Group: $AZURE_RESOURCE_GROUP"
    echo "  AI Project: $AZURE_PROJECT_NAME"
    echo "  Chat Model: $AZURE_OPENAI_CHAT_DEPLOYMENT_NAME"
    echo ""
}

# Main execution
main() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║     Azure Environment Setup for Agentic AI Immersion          ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""

    check_azure_cli
    verify_azure_login
    get_subscription_info
    get_resource_group
    get_ai_foundry_details
    get_openai_details
    get_search_details
    get_bing_connection
    get_mcp_connection
    create_env_file

    print_success "Setup complete! You can now run the notebooks."
    echo ""
    echo "Next steps:"
    echo "  1. Review the generated .env file"
    echo "  2. Start with: jupyter notebook agent-framework/agents/"
    echo ""
}

# Run main function
main
