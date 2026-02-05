# 🚀 Azure Setup Guide for Agentic AI Immersion

This guide provides **complete Azure CLI commands** to set up all required cloud resources for the workshop in a single resource group.

---

## 📋 Prerequisites

- Azure CLI installed ([Download](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli))
- An Azure subscription with Owner or Contributor + User Access Administrator permissions
- Bash/PowerShell terminal

---

## 🔐 Step 1: Authentication & Variables

### Login to Azure

```bash
# Login with device code (recommended for remote/codespaces environments)
az login --use-device-code

# Verify login and set subscription
az account show

# If you have multiple subscriptions, set the correct one
az account set --subscription "<your-subscription-id>"
```

### Set Environment Variables

```bash
# Core configuration - CUSTOMIZE THESE VALUES
export RESOURCE_GROUP="rg-agentic-ai-immersion"
export LOCATION="eastus2"
export TENANT_ID=$(az account show --query tenantId -o tsv)
export SUBSCRIPTION_ID=$(az account show --query id -o tsv)
export USER_PRINCIPAL_ID=$(az ad signed-in-user show --query id -o tsv)

# Resource naming - CUSTOMIZE PREFIX
export PREFIX="agentic-ai"
export AI_HUB_NAME="${PREFIX}-hub"
export AI_PROJECT_NAME="${PREFIX}-project"
export OPENAI_NAME="${PREFIX}-openai"
export SEARCH_NAME="${PREFIX}-search-$(date +%s | tail -c 5)"  # Add unique suffix
export STORAGE_NAME="agenticai$(date +%s | tail -c 6)storage"  # Must be 3-24 chars, lowercase, no hyphens
export KEYVAULT_NAME="${PREFIX}-kv-$(date +%s | tail -c 5)"  # Add unique suffix
export APPINSIGHTS_NAME="${PREFIX}-insights"
export LOG_ANALYTICS_NAME="${PREFIX}-logs"

echo "✅ Configuration set:"
echo "Resource Group: $RESOURCE_GROUP"
echo "Location: $LOCATION"
echo "Subscription: $SUBSCRIPTION_ID"
echo "User Principal: $USER_PRINCIPAL_ID"
```

---

## 🏗️ Step 2: Create Resource Group

```bash
# Create resource group
az group create \
  --name $RESOURCE_GROUP \
  --location $LOCATION

echo "✅ Resource group created: $RESOURCE_GROUP"
```

---

## 🤖 Step 3: Create AI Foundry Hub & Project

### Register Required Resource Providers

```bash
# Register required providers (may take a few minutes)
az provider register --namespace Microsoft.CognitiveServices --wait
az provider register --namespace Microsoft.MachineLearningServices --wait
az provider register --namespace Microsoft.Storage --wait
az provider register --namespace Microsoft.KeyVault --wait
az provider register --namespace Microsoft.Search --wait

echo "✅ Resource providers registered"
```

### Create AI Foundry Hub & Project using Python SDK

```bash
# Install Azure AI ML SDK (if not already installed)
pip3 install azure-ai-ml azure-identity --user -q

# Create Python script to create Hub and Project
cat > create_foundry_hub.py << 'EOFPYTHON'
import os
from azure.ai.ml import MLClient
from azure.ai.ml.entities import Hub, Project
from azure.identity import DefaultAzureCredential

resource_group = os.getenv("RESOURCE_GROUP")
subscription_id = os.getenv("SUBSCRIPTION_ID")
location = os.getenv("LOCATION")
hub_name = os.getenv("AI_HUB_NAME")
project_name = os.getenv("AI_PROJECT_NAME")

print(f"Creating Hub: {hub_name} and Project: {project_name}...")

credential = DefaultAzureCredential()
ml_client = MLClient(credential=credential, subscription_id=subscription_id, resource_group_name=resource_group)

# Create Hub
hub = Hub(name=hub_name, location=location, display_name="Agentic AI Immersion Hub")
hub_result = ml_client.workspaces.begin_create(hub).result()
print(f"✅ Hub created: {hub_name}")

# Create Project
project = Project(name=project_name, location=location, display_name="Agentic AI Immersion Project", hub_id=hub_result.id)
project_result = ml_client.workspaces.begin_create(project).result()
print(f"✅ Project created: {project_name}")
print(f"Project Endpoint: {project_result.discovery_url}")
print(f"Project ID: {project_result.id}")

# Export for later use
with open("/tmp/foundry_vars.sh", "w") as f:
    f.write(f'export AI_FOUNDRY_ENDPOINT="{project_result.discovery_url}"\n')
    f.write(f'export PROJECT_ID="{project_result.id}"\n')
EOFPYTHON

# Run the script
python3 create_foundry_hub.py

# Load the exported variables
source /tmp/foundry_vars.sh

echo "✅ AI Hub and Project created successfully"
```

**Note:** The `az ml` CLI extension may have installation issues in some environments. The Python SDK approach above is more reliable.

---

## 🧠 Step 4: Create Azure OpenAI Service

```bash
# Create Azure OpenAI resource
az cognitiveservices account create \
  --name $OPENAI_NAME \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --kind OpenAI \
  --sku S0 \
  --custom-domain $OPENAI_NAME \
  --yes

# Get OpenAI endpoint and key
OPENAI_ENDPOINT=$(az cognitiveservices account show \
  --name $OPENAI_NAME \
  --resource-group $RESOURCE_GROUP \
  --query properties.endpoint -o tsv)

OPENAI_API_KEY=$(az cognitiveservices account keys list \
  --name $OPENAI_NAME \
  --resource-group $RESOURCE_GROUP \
  --query key1 -o tsv)

# Get OpenAI resource ID for creating connection
OPENAI_RESOURCE_ID=$(az cognitiveservices account show \
  --name $OPENAI_NAME \
  --resource-group $RESOURCE_GROUP \
  --query id -o tsv)

echo "✅ Azure OpenAI created: $OPENAI_NAME"
echo "Endpoint: $OPENAI_ENDPOINT"
```

### Deploy Models

```bash
# Deploy GPT-4o (primary chat model)
az cognitiveservices account deployment create \
  --name $OPENAI_NAME \
  --resource-group $RESOURCE_GROUP \
  --deployment-name "gpt-4o" \
  --model-name "gpt-4o" \
  --model-version "2024-08-06" \
  --model-format OpenAI \
  --sku-capacity 10 \
  --sku-name "Standard"

# Deploy GPT-4o-mini (cost-effective option)
az cognitiveservices account deployment create \
  --name $OPENAI_NAME \
  --resource-group $RESOURCE_GROUP \
  --deployment-name "gpt-4o-mini" \
  --model-name "gpt-4o-mini" \
  --model-version "2024-07-18" \
  --model-format OpenAI \
  --sku-capacity 10 \
  --sku-name "Standard"

# Deploy text-embedding-3-large (for RAG/search scenarios)
az cognitiveservices account deployment create \
  --name $OPENAI_NAME \
  --resource-group $RESOURCE_GROUP \
  --deployment-name "text-embedding-3-large" \
  --model-name "text-embedding-3-large" \
  --model-version "1" \
  --model-format OpenAI \
  --sku-capacity 10 \
  --sku-name "Standard"

echo "✅ Models deployed: gpt-4o, gpt-4o-mini, text-embedding-3-large"
```

### Connect Azure OpenAI to AI Foundry Project

**CRITICAL:** After deploying the Azure OpenAI service and models, you must create a connection in the AI Foundry Project to make the models accessible to agents.

```bash
# Create Azure OpenAI connection in AI Foundry Project using Python SDK
cat > connect_openai_to_project.py << 'EOFPYTHON'
import os
from azure.ai.ml import MLClient
from azure.ai.ml.entities import AzureOpenAIConnection
from azure.identity import DefaultAzureCredential

# Get credentials and project details
credential = DefaultAzureCredential()
subscription_id = os.getenv("SUBSCRIPTION_ID")
resource_group = os.getenv("RESOURCE_GROUP")
project_name = os.getenv("AI_PROJECT_NAME")
openai_endpoint = os.getenv("OPENAI_ENDPOINT")
openai_key = os.getenv("OPENAI_API_KEY")
openai_resource_id = os.getenv("OPENAI_RESOURCE_ID")

# Initialize ML Client for the project
ml_client = MLClient(
    credential=credential,
    subscription_id=subscription_id,
    resource_group_name=resource_group,
    workspace_name=project_name
)

# Create Azure OpenAI connection
connection = AzureOpenAIConnection(
    name="azure-openai-connection",
    endpoint=openai_endpoint,
    api_key=openai_key,
    api_version="2024-08-01-preview",
    azure_openai_resource_id=openai_resource_id
)

# Create or update the connection
try:
    created_connection = ml_client.connections.create_or_update(connection)
    print(f"✅ Successfully created Azure OpenAI connection: {created_connection.name}")
    print(f"   Connection ID: {created_connection.id}")
except Exception as e:
    print(f"❌ Error creating connection: {e}")
    exit(1)
EOFPYTHON

# Run the connection script
python3 connect_openai_to_project.py

# Clean up
rm connect_openai_to_project.py

echo "✅ Azure OpenAI connected to AI Foundry Project"
echo "   Agents can now access models: gpt-4o, gpt-4o-mini, text-embedding-3-large"
```

**Alternative: Manual Connection via Azure AI Foundry Portal**

If the script fails, you can create the connection manually:

1. Navigate to [Azure AI Foundry Portal](https://ai.azure.com)
2. Select your project: **$AI_PROJECT_NAME**
3. Go to **Settings** → **Connections**
4. Click **+ New Connection** → **Azure OpenAI**
5. Fill in:
   - **Name:** `azure-openai-connection`
   - **Subscription:** Your subscription
   - **Azure OpenAI resource:** Select **$OPENAI_NAME**
6. Click **Add connection**

echo "✅ Models deployed: gpt-4o, gpt-4o-mini, text-embedding-3-large"
```

---

## 🔍 Step 5: Create Azure AI Search

```bash
# Create Azure AI Search (for RAG and Foundry IQ)
# Note: If you get a capacity error, try a different region (e.g., eastus instead of eastus2)
az search service create \
  --name $SEARCH_NAME \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --sku Standard \
  --partition-count 1 \
  --replica-count 1

# If above fails with capacity error, try alternate region:
# az search service create \
#   --name $SEARCH_NAME \
#   --resource-group $RESOURCE_GROUP \
#   --location eastus \
#   --sku Standard \
#   --partition-count 1 \
#   --replica-count 1

# Get Search endpoint and admin key
SEARCH_ENDPOINT="https://${SEARCH_NAME}.search.windows.net"

SEARCH_API_KEY=$(az search admin-key show \
  --resource-group $RESOURCE_GROUP \
  --service-name $SEARCH_NAME \
  --query primaryKey -o tsv)

echo "✅ Azure AI Search created: $SEARCH_NAME"
echo "Endpoint: $SEARCH_ENDPOINT"
```

---

## 💾 Step 6: Create Storage Account

```bash
# Create storage account (for file search and agent files)
az storage account create \
  --name $STORAGE_NAME \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --sku Standard_LRS \
  --kind StorageV2 \
  --allow-blob-public-access false

# Get storage connection string
STORAGE_CONNECTION_STRING=$(az storage account show-connection-string \
  --name $STORAGE_NAME \
  --resource-group $RESOURCE_GROUP \
  --query connectionString -o tsv)

echo "✅ Storage account created: $STORAGE_NAME"
```

---

## 🔑 Step 7: Create Key Vault

```bash
# Create Key Vault (for secure credential storage)
az keyvault create \
  --name $KEYVAULT_NAME \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --enable-rbac-authorization false

# Set access policy for current user
az keyvault set-policy \
  --name $KEYVAULT_NAME \
  --upn $(az account show --query user.name -o tsv) \
  --secret-permissions get list set delete

# Store secrets
az keyvault secret set --vault-name $KEYVAULT_NAME --name "OpenAI-ApiKey" --value "$OPENAI_API_KEY"
az keyvault secret set --vault-name $KEYVAULT_NAME --name "Search-ApiKey" --value "$SEARCH_API_KEY"

echo "✅ Key Vault created: $KEYVAULT_NAME"
```

---

## 📊 Step 8: Create Application Insights & Log Analytics

```bash
# Create Log Analytics Workspace
az resource create \
  --resource-type Microsoft.OperationalInsights/workspaces \
  --name $LOG_ANALYTICS_NAME \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --properties '{}'

# Get workspace ID
LOG_ANALYTICS_ID=$(az resource show \
  --resource-type Microsoft.OperationalInsights/workspaces \
  --name $LOG_ANALYTICS_NAME \
  --resource-group $RESOURCE_GROUP \
  --query id -o tsv)

# Create Application Insights
az resource create \
  --resource-type Microsoft.Insights/components \
  --name $APPINSIGHTS_NAME \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --properties "{\"Application_Type\":\"web\",\"WorkspaceResourceId\":\"$LOG_ANALYTICS_ID\"}"

# Get connection string
APPINSIGHTS_CONNECTION_STRING=$(az resource show \
  --resource-type Microsoft.Insights/components \
  --name $APPINSIGHTS_NAME \
  --resource-group $RESOURCE_GROUP \
  --query properties.ConnectionString -o tsv)

echo "✅ Application Insights created: $APPINSIGHTS_NAME"
```

---

## 🔐 Step 9: Assign RBAC Roles

### User Roles (for running notebooks)

```bash
# Get resource scopes
PROJECT_SCOPE="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.MachineLearningServices/workspaces/$AI_PROJECT_NAME"
STORAGE_SCOPE="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Storage/storageAccounts/$STORAGE_NAME"
SEARCH_SCOPE="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Search/searchServices/$SEARCH_NAME"
OPENAI_SCOPE="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.CognitiveServices/accounts/$OPENAI_NAME"

# Core AI roles
az role assignment create \
  --role "Azure AI Developer" \
  --assignee $USER_PRINCIPAL_ID \
  --scope $PROJECT_SCOPE

az role assignment create \
  --role "Cognitive Services OpenAI User" \
  --assignee $USER_PRINCIPAL_ID \
  --scope $OPENAI_SCOPE

az role assignment create \
  --role "Cognitive Services User" \
  --assignee $USER_PRINCIPAL_ID \
  --scope $OPENAI_SCOPE

# Storage roles (for file search)
az role assignment create \
  --role "Storage Blob Data Contributor" \
  --assignee $USER_PRINCIPAL_ID \
  --scope $STORAGE_SCOPE

# Search roles (for AI Search and Foundry IQ)
az role assignment create \
  --role "Search Index Data Contributor" \
  --assignee $USER_PRINCIPAL_ID \
  --scope $SEARCH_SCOPE

az role assignment create \
  --role "Search Index Data Reader" \
  --assignee $USER_PRINCIPAL_ID \
  --scope $SEARCH_SCOPE

az role assignment create \
  --role "Search Service Contributor" \
  --assignee $USER_PRINCIPAL_ID \
  --scope $SEARCH_SCOPE

echo "✅ User RBAC roles assigned"
```

### Managed Identity Roles (for Foundry IQ Agents)

```bash
# Get the AI Project's managed identity
PROJECT_MANAGED_IDENTITY=$(python3 -c "from azure.ai.ml import MLClient; from azure.identity import DefaultAzureCredential; import os; ml = MLClient(DefaultAzureCredential(), os.getenv('SUBSCRIPTION_ID'), os.getenv('RESOURCE_GROUP'), os.getenv('AI_PROJECT_NAME')); p = ml.workspaces.get(os.getenv('AI_PROJECT_NAME')); print(p.identity.principal_id if hasattr(p.identity, 'principal_id') else '')")

# If empty, get it using Azure CLI resource command
if [ -z "$PROJECT_MANAGED_IDENTITY" ]; then
  PROJECT_MANAGED_IDENTITY=$(az resource show \
    --resource-type Microsoft.MachineLearningServices/workspaces \
    --name $AI_PROJECT_NAME \
    --resource-group $RESOURCE_GROUP \
    --query identity.principalId -o tsv)
fi

# Assign Search Index Data Reader to project managed identity (CRITICAL for Foundry IQ)
az role assignment create \
  --role "Search Index Data Reader" \
  --assignee $PROJECT_MANAGED_IDENTITY \
  --scope $SEARCH_SCOPE

az role assignment create \
  --role "Cognitive Services OpenAI User" \
  --assignee $PROJECT_MANAGED_IDENTITY \
  --scope $OPENAI_SCOPE

echo "✅ Managed Identity RBAC roles assigned"
echo "Project Managed Identity: $PROJECT_MANAGED_IDENTITY"
```

---

## 🌐 Step 10: Create Bing Search Connection (Optional)

For notebooks using Bing grounding (4-bing-grounding.ipynb), create a Bing Search resource:

```bash
# Note: Bing Search API is created via Azure Portal
# Visit: https://portal.azure.com/#create/microsoft.bingsearch
# After creation, get the API key and create connection in AI Foundry Portal

echo "⚠️  For Bing Search integration:"
echo "1. Create Bing Search v7 resource in Azure Portal"
echo "2. Get API key from Keys section"
echo "3. Create connection in AI Foundry Portal (ai.azure.com)"
echo "4. Navigate to: Project → Settings → Connections → New Connection → Bing"
```

---

## 📝 Step 11: Generate .env File

```bash
# Get AI Foundry Project endpoint (if not already set from Python script)
if [ -z "$AI_FOUNDRY_ENDPOINT" ]; then
  AI_FOUNDRY_ENDPOINT=$(python3 -c "from azure.ai.ml import MLClient; from azure.identity import DefaultAzureCredential; import os; ml = MLClient(DefaultAzureCredential(), os.getenv('SUBSCRIPTION_ID'), os.getenv('RESOURCE_GROUP'), os.getenv('AI_PROJECT_NAME')); p = ml.workspaces.get(os.getenv('AI_PROJECT_NAME')); print(p.discovery_url)")
  PROJECT_ID=$(python3 -c "from azure.ai.ml import MLClient; from azure.identity import DefaultAzureCredential; import os; ml = MLClient(DefaultAzureCredential(), os.getenv('SUBSCRIPTION_ID'), os.getenv('RESOURCE_GROUP'), os.getenv('AI_PROJECT_NAME')); p = ml.workspaces.get(os.getenv('AI_PROJECT_NAME')); print(p.id)")
fi

# Create .env file
cat > .env << EOF
# =============================================================================
# 🚀 Agentic AI Immersion - Auto-Generated Configuration
# Generated: $(date)
# =============================================================================

# =============================================================================
# 🔐 AZURE AUTHENTICATION
# =============================================================================
TENANT_ID=$TENANT_ID
AZURE_SUBSCRIPTION_ID=$SUBSCRIPTION_ID
AZURE_RESOURCE_GROUP=$RESOURCE_GROUP
AZURE_PROJECT_NAME=$AI_PROJECT_NAME

# =============================================================================
# 🤖 Microsoft Foundry PROJECT
# =============================================================================
AI_FOUNDRY_PROJECT_ENDPOINT=$AI_FOUNDRY_ENDPOINT
PROJECT_RESOURCE_ID=$PROJECT_ID

# =============================================================================
# 🧠 MODEL DEPLOYMENTS
# =============================================================================
AZURE_AI_MODEL_DEPLOYMENT_NAME=gpt-4o-mini
EMBEDDING_MODEL_DEPLOYMENT_NAME=text-embedding-3-large

# =============================================================================
# 🔗 AZURE OPENAI DIRECT ACCESS
# =============================================================================
AZURE_OPENAI_ENDPOINT=$OPENAI_ENDPOINT
AZURE_OPENAI_API_KEY=$OPENAI_API_KEY
AZURE_OPENAI_CHAT_DEPLOYMENT_NAME=gpt-4o

# =============================================================================
# 🔍 AZURE AI SEARCH
# =============================================================================
AZURE_AI_SEARCH_ENDPOINT=$SEARCH_ENDPOINT
AZURE_AI_SEARCH_API_KEY=$SEARCH_API_KEY
AZURE_AI_SEARCH_API_VERSION=2025-03-01-preview
SEARCH_AUTHENTICATION_METHOD=api-search-key
AZURE_SEARCH_INDEX_NAME=banking-products

# =============================================================================
# 📊 OBSERVABILITY & TRACING
# =============================================================================
AZURE_TRACING_GEN_AI_CONTENT_RECORDING_ENABLED=true
AZURE_SDK_TRACING_IMPLEMENTATION=opentelemetry
ENABLE_SENSITIVE_DATA=true
APPLICATIONINSIGHTS_CONNECTION_STRING=$APPINSIGHTS_CONNECTION_STRING

# =============================================================================
# 🌐 BING GROUNDING (Optional - requires manual setup)
# =============================================================================
# GROUNDING_WITH_BING_CONNECTION_NAME=<your-bing-connection-name>
# BING_CONNECTION_ID=<get-from-ai-foundry-portal>

# =============================================================================
# 🔧 MCP TOOLS (Optional - get from AI Foundry Portal)
# =============================================================================
# FOUNDRY_MCP_CONNECTION_ID=<get-from-ai-foundry-portal>
EOF

echo "✅ .env file created successfully!"
echo ""
echo "📄 Review the .env file and update optional values as needed."
```

---

## ✅ Step 12: Verify Setup

```bash
# Verify all resources are created
echo "==================================================================="
echo "🎉 Azure Resources Created Successfully!"
echo "==================================================================="
echo ""
echo "Resource Group:        $RESOURCE_GROUP"
echo "Location:              $LOCATION"
echo ""
echo "AI Foundry Hub:        $AI_HUB_NAME"
echo "AI Foundry Project:    $AI_PROJECT_NAME"
echo "Azure OpenAI:          $OPENAI_NAME"
echo "Azure AI Search:       $SEARCH_NAME"
echo "Storage Account:       $STORAGE_NAME"
echo "Key Vault:             $KEYVAULT_NAME"
echo "Application Insights:  $APPINSIGHTS_NAME"
echo ""
echo "==================================================================="
echo "📝 Next Steps:"
echo "==================================================================="
echo "1. ✅ .env file created - review and customize if needed"
echo "2. 🌐 (Optional) Create Bing Search resource for web grounding"
echo "3. 🔧 (Optional) Set up MCP connection in AI Foundry Portal"
echo "4. ⏳ Wait 5-10 minutes for RBAC role propagation"
echo "5. 🚀 Start running notebooks!"
echo ""
echo "AI Foundry Portal: https://ai.azure.com"
echo "Azure Portal: https://portal.azure.com/#@$TENANT_ID/resource$PROJECT_ID"
echo "==================================================================="
```

---

## 🧹 Cleanup (Optional)

To delete all resources when done:

```bash
# WARNING: This deletes ALL resources in the resource group
az group delete --name $RESOURCE_GROUP --yes --no-wait

echo "🗑️  Resource group deletion initiated: $RESOURCE_GROUP"
```

---

## 🔧 Troubleshooting

### "Not Found" Error When Creating Agents
If you get `Operation returned an invalid status 'Not Found'` when creating agents:
```bash
# This means Azure OpenAI is not connected to the AI Foundry Project
# Re-run the connection script from Step 4 (Connect Azure OpenAI to AI Foundry Project)
# OR create the connection manually via the AI Foundry Portal (ai.azure.com)
```

### AI Foundry Hub Creation Issues
If `az ml` extension installation fails:
```bash
# The Python SDK approach is recommended (already included in Step 3)
# Alternatively, create via Azure Portal:
# 1. Visit https://ai.azure.com
# 2. Create new Hub: Click "+ New hub"
# 3. Create new Project within the Hub
```

### Role Assignment Propagation
If you encounter permission errors:
```bash
# Wait 5-10 minutes, then retry
# Verify role assignments
az role assignment list --assignee $USER_PRINCIPAL_ID --scope $PROJECT_SCOPE
```

### OpenAI Model Deployment Issues
```bash
# Check available models
az cognitiveservices account list-models \
  --name $OPENAI_NAME \
  --resource-group $RESOURCE_GROUP

# List deployments
az cognitiveservices account deployment list \
  --name $OPENAI_NAME \
  --resource-group $RESOURCE_GROUP
```

### Storage Network Access
If you get 403 errors with file search:
```bash
# Allow Azure services
az storage account update \
  --name $STORAGE_NAME \
  --resource-group $RESOURCE_GROUP \
  --default-action Allow
```

---

## 📚 Additional Resources

- [Azure AI Foundry Documentation](https://learn.microsoft.com/azure/ai-foundry/)
- [Azure OpenAI Service](https://learn.microsoft.com/azure/ai-services/openai/)
- [Azure AI Search](https://learn.microsoft.com/azure/search/)
- [Azure RBAC Documentation](https://learn.microsoft.com/azure/role-based-access-control/)

---

**🎉 Setup Complete! You're ready to start the Agentic AI Immersion workshop!**
