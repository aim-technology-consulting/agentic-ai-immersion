#!/usr/bin/env bash
set -euo pipefail

# Runs as postAttachCommand — signals VS Code has attached.
touch /tmp/.vscode-attached

# Show the welcome banner in the attach logs/output.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "${SCRIPT_DIR}/welcome.sh" || true
