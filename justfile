# Justfile for BMAD v6 IDP Template

default:
    @just --list

# Check BMAD version
bmad-version:
    #!/usr/bin/env bash
    if [ ! -f "_bmad/_config/manifest.yaml" ]; then
        echo "❌ BMAD is not installed. Rebuild the Codespace to install."
        exit 1
    fi
    grep "^  version:" _bmad/_config/manifest.yaml 2>/dev/null | head -1 | awk '{print $2}' || echo "Not installed"
    echo "Latest: $(npm view bmad-method version 2>/dev/null || echo 'unknown')"

# Setup Jira MCP (Interactive)
jira:
    #!/usr/bin/env bash
    set -e
    echo "🔗 Jira MCP Setup"
    echo "=================="
    echo ""
    echo "This will connect GitHub Copilot to your Jira instance."
    echo ""
    read -p "Your Atlassian email: " email
    echo ""
    echo "📋 Get your API token:"
    _jira_token_url="https://id.atlassian.com/manage-profile/security/api-tokens"
    if [ -n "$BROWSER" ]; then
        "$BROWSER" "$_jira_token_url"
    elif grep -qi microsoft /proc/version 2>/dev/null; then
        cmd.exe /c start "" "$_jira_token_url"
    elif [[ "$(uname -s)" == "Darwin" ]]; then
        open "$_jira_token_url"
    else
        echo ""
        echo "   Open this URL in your browser:"
        echo "   $_jira_token_url"
        echo ""
        read -rp "   Press Enter once the page is open... "
    fi
    echo ""
    echo "   1. Click 'Create API token' in the browser"
    echo "   2. Give it a name (e.g., 'GitHub Copilot MCP')"
    echo "   3. Set expiry date: 90 days (recommended) or longer if needed"
    echo "   4. Copy the token (save it somewhere safe!)"
    echo ""
    read -p "Your API token: " token
    echo ""
    echo "🔧 Creating configuration..."
    echo "JIRA_URL=https://jira-pg.atlassian.net/" > .env
    echo "JIRA_USERNAME=$email" >> .env
    echo "JIRA_API_TOKEN=$token" >> .env
    echo "CONFLUENCE_URL=https://jira-pg.atlassian.net/wiki" >> .env
    echo "CONFLUENCE_USERNAME=$email" >> .env
    echo "CONFLUENCE_API_TOKEN=$token" >> .env
    echo "DEBUG=false" >> .env
    echo "✅ Configuration saved to .env"
    echo ""
    echo "📥 Pulling Docker image..."
    docker pull ghcr.io/procter-gamble/mcp-atlassian:main-manual
    echo "✅ Image ready"
    echo ""
    echo "🧪 Testing connections..."
    _conn_ok=true
    bash scripts/test-jira.sh || { echo "⚠️  Jira connection test failed - check your credentials"; _conn_ok=false; }
    bash scripts/test-confluence.sh || { echo "⚠️  Confluence connection test failed - check your credentials"; _conn_ok=false; }
    echo ""
    if [ "$_conn_ok" = true ]; then
        echo "✨ Setup complete!"
        echo ""
        echo "⚠️  IMPORTANT: Reload VS Code to activate MCP:"
        echo "   Press Ctrl+Shift+P → 'Developer: Reload Window'"
        echo ""
        echo "💡 Troubleshooting: If Copilot can't find your Jira projects after reload:"
        echo "   1. In Copilot Chat, click the configure tools icon (sliders) next to the model picker"
        echo "   2. Find and enable jira-mcp-server"
        echo "   3. Close the panel — Jira & Confluence tools are now active"
    else
        echo "❌ Setup failed — one or more connection tests did not pass."
        echo ""
        echo "   Fix your credentials and retry: just jira"
    fi
    echo ""

# Quick Jira setup with environment variables (for automation)
jira-auto EMAIL TOKEN:
    #!/usr/bin/env bash
    echo "JIRA_URL=https://jira-pg.atlassian.net/" > .env
    echo "JIRA_USERNAME={{EMAIL}}" >> .env
    echo "JIRA_API_TOKEN={{TOKEN}}" >> .env
    echo "CONFLUENCE_URL=https://jira-pg.atlassian.net/wiki" >> .env
    echo "CONFLUENCE_USERNAME={{EMAIL}}" >> .env
    echo "CONFLUENCE_API_TOKEN={{TOKEN}}" >> .env
    echo "DEBUG=false" >> .env
    docker pull ghcr.io/procter-gamble/mcp-atlassian:main-manual > /dev/null 2>&1 &
    echo "✅ Jira & Confluence MCP configured (reload VS Code to activate)"

# Test Jira
jira-test:
    @bash scripts/test-jira.sh

# Show current Jira config
jira-status:
    @bash -c 'if [ -f .env ]; then source .env && echo "URL: $$JIRA_URL" && echo "User: $$JIRA_USERNAME"; else echo "❌ Not configured. Run: just jira"; fi'

# Clear config
jira-clear:
    @rm -f .env && echo "✅ Cleared"
