#!/bin/bash
# Runs once at Codespace creation (postCreateCommand) — fresh BMAD install only
# Version is locked — updates are managed by the IDP template team
echo ""
echo "🚀 Setting up BMAD Method v6..."
echo "=================================================="
echo ""

# Get the workspace root directory dynamically
WORKSPACE_ROOT="$(pwd)"
if [ -n "$CODESPACE_VSCODE_FOLDER" ]; then
    WORKSPACE_ROOT="$CODESPACE_VSCODE_FOLDER"
fi

# Skip if already installed (e.g., prebuild or manual re-run)
if [ -d "${WORKSPACE_ROOT}/_bmad" ] && [ -f "${WORKSPACE_ROOT}/_bmad/_config/manifest.yaml" ]; then
    echo "✅ BMAD already installed — skipping"
    exit 0
fi

# Clean up partial install (directory exists but manifest is missing)
if [ -d "${WORKSPACE_ROOT}/_bmad" ] && [ ! -f "${WORKSPACE_ROOT}/_bmad/_config/manifest.yaml" ]; then
    echo "⚠️ Partial BMAD install detected — cleaning up before fresh install"
    rm -rf "${WORKSPACE_ROOT}/_bmad"
fi

echo "🎯 Installing BMAD Method v6..."
echo "📋 Config: Module=bmm | Tool=github-copilot"
echo ""

cd "$WORKSPACE_ROOT" || exit 1

# v6 non-interactive install — all flags explicit, no prompts
# Benchmarked: ~2s warm, ~7s cold
npx --yes bmad-method@6.5.0 install \
  --directory "${WORKSPACE_ROOT}" \
  --modules bmm \
  --tools github-copilot \
  --communication-language English \
  --document-output-language English \
  --output-folder _bmad-output \
  --yes \
  2>&1 | tee /tmp/bmad-install.log
INSTALL_EXIT_CODE=${PIPESTATUS[0]}

if [ $INSTALL_EXIT_CODE -ne 0 ]; then
    echo ""
    echo "⚠️ BMAD installation failed (exit code: $INSTALL_EXIT_CODE)"
    echo "   Log: /tmp/bmad-install.log"
    echo "   Retry: bash .devcontainer/setup-bmad.sh"
    echo "   Manual: npx bmad-method install"
    exit 0  # Don't block codespace creation
fi

# Verify
echo ""
echo "🔍 Verifying..."
INSTALL_OK=true

[ ! -f "_bmad/_config/manifest.yaml" ] && echo "   ⚠️ Missing _bmad/_config/manifest.yaml" && INSTALL_OK=false

SKILL_COUNT=$(find .agents/skills -maxdepth 1 -type d 2>/dev/null | wc -l)
[ "$SKILL_COUNT" -lt 40 ] && echo "   ⚠️ Expected 40+ skills, found ${SKILL_COUNT}" && INSTALL_OK=false

[ ! -d "_bmad-output" ] && mkdir -p "_bmad-output/planning-artifacts" "_bmad-output/implementation-artifacts"

[ "$INSTALL_OK" = true ] && echo "   ✅ All checks passed"

echo ""
echo "=================================================="
echo "✅ BMAD Method v6 ready!"
echo "=================================================="

# Merge .gitignore
echo "🔧 Merging .gitignore..."
if [ -f ".devcontainer/bmad.gitignore" ]; then
    if [ ! -f ".gitignore" ]; then
        cp ".devcontainer/bmad.gitignore" ".gitignore"
        echo "   Created .gitignore"
    elif ! grep -q "# BMAD Method Ignores" ".gitignore"; then
        echo "" >> ".gitignore"
        echo "# BMAD Method Ignores" >> ".gitignore"
        cat ".devcontainer/bmad.gitignore" >> ".gitignore"
        echo "   Appended BMAD ignores"
    fi
fi

# Verify MCP configuration
echo "🔧 Checking MCP configuration..."
if [ -f ".vscode/mcp.json" ]; then
    echo "   .vscode/mcp.json present."
else
    echo "   ⚠️  .vscode/mcp.json not found — Jira MCP server won't be available."
    echo "   Run 'just jira' to set up Jira integration manually."
fi

echo ""
echo "📖 Getting Started:"
echo "   Say 'what should I do next' in Copilot Chat"
echo "   Say 'talk to John' to work with the PM agent"
echo "   Say 'lets create a PRD' to start a new document"
echo ""
echo "🤖 Available Agents:"
echo "   John (PM) · Mary (Analyst) · Sally (UX) · Winston (Architect)"
echo "   Amelia (Dev) · Quinn (QA) · Barry (Quick Dev) · Bob (SM) · Paige (Writer)"
echo ""
echo "ℹ️  Jira: Set up anytime with 'just jira'"
echo ""
exit 0
