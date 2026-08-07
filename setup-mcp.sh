#!/bin/bash
set -e

echo ""
echo "🔧 Setting up Jira MCP (Model Context Protocol)..."
echo "=================================================="

# Wait for Docker daemon to be ready
echo "⏳ Waiting for Docker daemon..."
MAX_WAIT=60
WAITED=0
while ! docker info > /dev/null 2>&1; do
    if [ $WAITED -ge $MAX_WAIT ]; then
        echo "❌ Docker daemon not ready after ${MAX_WAIT}s"
        echo "   MCP setup skipped. Run 'just jira' manually later if needed."
        exit 0
    fi
    sleep 2
    WAITED=$((WAITED + 2))
done
echo "✅ Docker is ready"

# Pull MCP Docker image in background (non-blocking)
echo "📥 Pulling MCP Docker image (background)..."
docker pull ghcr.io/procter-gamble/mcp-atlassian:main-manual > /tmp/mcp-pull.log 2>&1 &

# Determine workspace root dynamically
WORKSPACE_ROOT="$(pwd)"
if [ -n "$CODESPACE_VSCODE_FOLDER" ]; then
    WORKSPACE_ROOT="$CODESPACE_VSCODE_FOLDER"
fi

# Check for .env file
if [ ! -f "${WORKSPACE_ROOT}/.env" ]; then
    echo ""
    echo "📋 Jira MCP Integration Available"
    echo "=================================="
    echo ""
    echo "What is Jira MCP?"
    echo "   • Connects GitHub Copilot to your Jira instance"
    echo "   • Ask Copilot about Jira issues, projects, and tasks"
    echo "   • Create and update Jira issues directly from chat"
    echo ""
    echo "Example: Ask Copilot 'Show me my Jira issues' or 'Create a bug report'"
    echo ""
    echo "ℹ️  Jira setup is handled during BMAD installation."
    echo "   To set up manually later, run: just jira"
else
    echo "✅ .env file found - Jira MCP configured"
fi

echo ""
echo "✨ MCP Setup Complete!"
echo ""
