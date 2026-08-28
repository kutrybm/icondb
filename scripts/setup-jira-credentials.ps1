[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$jiraUrl = "https://jira-pg.atlassian.net"
$confluenceUrl = "$jiraUrl/wiki"
$defaultEmail = "kutryb.m@pg.com"

$email = Read-Host "Atlassian email [$defaultEmail]"
if ([string]::IsNullOrWhiteSpace($email)) {
    $email = $defaultEmail
}

Write-Host "Copy only the Atlassian API token to the clipboard."
Read-Host "Press Enter when it is copied"
$token = (Get-Clipboard -Raw).Trim()
Set-Clipboard -Value " "

if ([string]::IsNullOrWhiteSpace($token)) {
    throw "Token cannot be empty."
}

if ($token.Length -lt 20) {
    throw "Token is too short. Copy the complete API token and retry."
}

if ($token -match "\s") {
    throw "Token contains whitespace. Copy only the API token value and retry."
}

$lines = @(
    "JIRA_URL=$jiraUrl/"
    "JIRA_USERNAME=$email"
    "JIRA_API_TOKEN=$token"
    "CONFLUENCE_URL=$confluenceUrl"
    "CONFLUENCE_USERNAME=$email"
    "CONFLUENCE_API_TOKEN=$token"
    "DEBUG=false"
)

$environmentPath = Join-Path (Split-Path $PSScriptRoot -Parent) ".env"
[System.IO.File]::WriteAllLines($environmentPath, $lines, [System.Text.UTF8Encoding]::new($false))

$token = $null

Write-Host "Credentials saved to the Git-ignored .env file."
Write-Host "Ask Copilot to test Jira and Confluence connectivity next."
