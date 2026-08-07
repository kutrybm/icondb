#!/bin/bash
source .env 2>/dev/null || { echo "❌ No .env file. Run: just jira"; exit 1; }

# Check if Confluence variables are set
if [ -z "$CONFLUENCE_URL" ] || [ -z "$CONFLUENCE_USERNAME" ] || [ -z "$CONFLUENCE_API_TOKEN" ]; then
    echo "❌ Confluence not configured. Run: just jira"
    exit 1
fi

# Test connection to Confluence
code=$(curl -s -o /dev/null -w "%{http_code}" -u "$CONFLUENCE_USERNAME:$CONFLUENCE_API_TOKEN" "${CONFLUENCE_URL}/rest/api/content?limit=1")

if [ "$code" = "200" ]; then
    echo "✅ Connected to Confluence!"
else
    echo "❌ Connection failed (HTTP $code)"
    exit 1
fi
