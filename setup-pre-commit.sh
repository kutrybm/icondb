#!/bin/bash
set -e

echo ""
echo "🔧 Setting up pre-commit hooks..."
echo "================================="
echo ""

# Determine workspace root
WORKSPACE_ROOT="$(pwd)"
if [ -n "$CODESPACE_VSCODE_FOLDER" ]; then
    WORKSPACE_ROOT="$CODESPACE_VSCODE_FOLDER"
fi

cd "$WORKSPACE_ROOT" || exit 1

# Check if we're in a git repository
if [ ! -d ".git" ]; then
    echo "⚠️  Not a git repository - pre-commit hooks skipped"
    echo "   (This is normal for brand new workspaces)"
    exit 0
fi

# pre-commit is pre-installed in the Docker image — verify it's available
if ! command -v pre-commit &> /dev/null; then
    echo "⚠️  pre-commit not found (expected in Docker image)"
    echo "   Attempting runtime install..."
    pip3 install --quiet --break-system-packages pre-commit 2>/dev/null \
        || pip3 install --quiet --user pre-commit 2>/dev/null \
        || { echo "❌ Could not install pre-commit — skipping"; exit 0; }
fi

# Copy default config if none exists
if [ ! -f ".pre-commit-config.yaml" ]; then
    if [ -f ".devcontainer/bmad.pre-commit-config.yaml" ]; then
        echo "📝 Creating .pre-commit-config.yaml from BMAD defaults..."
        cp ".devcontainer/bmad.pre-commit-config.yaml" ".pre-commit-config.yaml"
    else
        echo "⚠️  No .pre-commit-config.yaml found and no default available."
        echo "   Skipping pre-commit setup."
        exit 0
    fi
fi

# Install hooks
echo "🔗 Installing pre-commit hooks..."
pre-commit install --hook-type pre-commit --hook-type commit-msg 2>/dev/null || echo "⚠️  Could not install hooks (may already exist)"

echo ""
echo "✅ Pre-commit hooks installed!"
echo "   • Trailing whitespace will be auto-removed"
echo "   • Files will get proper line endings"
echo "   • YAML files will be validated"
echo "   • Large files (>500KB) will be blocked"
echo ""
