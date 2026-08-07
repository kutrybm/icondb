#!/bin/bash
source .env 2>/dev/null || { echo "❌ No .env file. Run: just jira"; exit 1; }

code=$(curl -s -o /dev/null -w "%{http_code}" -u "$JIRA_USERNAME:$JIRA_API_TOKEN" "${JIRA_URL}rest/api/2/myself")

if [ "$code" = "200" ]; then
    echo "✅ Connected to Jira!"
else
    echo "❌ Connection failed (HTTP $code)"
    exit 1
fi
