[CmdletBinding()]
param(
    [string]$Username = "kutrybm"
)

$ErrorActionPreference = "Stop"
$dockerExe = "C:\Program Files\Docker\Docker\resources\bin\docker.exe"
$mcpImage = "ghcr.io/procter-gamble/mcp-atlassian:main-manual"

if (-not (Test-Path $dockerExe)) {
    throw "Docker CLI was not found at $dockerExe."
}

Write-Host "Ensuring Docker Desktop is running..."
& $dockerExe desktop start
if ($LASTEXITCODE -ne 0) {
    throw "Docker Desktop could not be started. Open Docker Desktop and retry."
}

& $dockerExe --context desktop-linux version --format "Docker server: {{.Server.Version}} {{.Server.Os}}"
if ($LASTEXITCODE -ne 0) {
    throw "Docker Desktop started, but the Linux engine is not ready. Run 'docker desktop restart' and retry."
}

Write-Host "Copy the GitHub personal access token with read:packages to the clipboard."
Read-Host "Press Enter when it is copied"
$token = (Get-Clipboard -Raw).Trim()
Set-Clipboard -Value " "

if ([string]::IsNullOrWhiteSpace($token) -or $token.Length -lt 20) {
    throw "The GitHub token is missing or too short."
}

if ($token -match "\s") {
    throw "The GitHub token contains whitespace. Copy only the token value and retry."
}

$token | & $dockerExe login ghcr.io --username $Username --password-stdin
$token = $null

if ($LASTEXITCODE -ne 0) {
    throw "GHCR login failed. Confirm read:packages and procter-gamble SSO authorization."
}

& $dockerExe --context desktop-linux pull $mcpImage
if ($LASTEXITCODE -ne 0) {
        throw @"
GHCR accepted the token, but GitHub denied access to the private package:
    $mcpImage

For a classic GitHub PAT, confirm all three requirements:
    1. The token has the read:packages scope.
    2. Configure SSO -> Authorize is enabled for the procter-gamble organization.
    3. Your GitHub account has read access to the mcp-atlassian package or its linked repository.

If requirements 1 and 2 are already satisfied, ask a procter-gamble package owner to grant
your GitHub account read access. Then rerun this script with a newly copied token.
"@
}

Write-Host "GHCR login and Jira MCP image pull succeeded."
