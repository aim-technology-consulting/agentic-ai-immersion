#!/bin/bash
# Wait for VS Code to finish attaching before printing (avoids output being dropped on Windows)
for i in $(seq 1 20); do
    [ -f /tmp/.vscode-attached ] && break
    sleep 0.25
done

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║          Agentic AI Immersion Day                            ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "  User    : $(whoami)"
echo "  Python  : $(python --version 2>&1)"
AZ_CLI_VERSION="$(az version --query '"azure-cli"' -o tsv 2>/dev/null || true)"
if [ -z "$AZ_CLI_VERSION" ]; then
    AZ_CLI_VERSION="not available"
fi
echo "  Az CLI  : ${AZ_CLI_VERSION}"
echo ""

ENV_FILE="$(cd "$(dirname "$0")/.." && pwd)/.env"
if [ -f "$ENV_FILE" ]; then
    set -a; source "$ENV_FILE"; set +a
fi

if [ -z "$AZURE_CLIENT_ID" ] || [ -z "$AZURE_CLIENT_SECRET" ] || [ -z "$AZURE_TENANT_ID" ]; then
    echo "  Auth    : ✗ AZURE_CLIENT_ID / AZURE_CLIENT_SECRET / AZURE_TENANT_ID not set in .env"
else
    RESULT=$(curl -s --connect-timeout 2 --max-time 8 -X POST \
      "https://login.microsoftonline.com/$AZURE_TENANT_ID/oauth2/v2.0/token" \
      -d "grant_type=client_credentials&client_id=$AZURE_CLIENT_ID&client_secret=$AZURE_CLIENT_SECRET&scope=https://cognitiveservices.azure.com/.default")

    if echo "$RESULT" | python3 -c "import sys,json; sys.exit(0 if 'access_token' in json.load(sys.stdin) else 1)" 2>/dev/null; then
        echo "  Auth    : ✓ Service Principal authenticated"
    else
        echo "  Auth    : ✗ Service Principal auth failed — check credentials in .env"
    fi
fi
echo ""
echo "  Ready. Try: python --version | jupyter notebook"
echo ""
