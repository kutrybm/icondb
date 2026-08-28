[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$Path,

  [Parameter(Mandatory = $true)]
  [string]$OutputPath
)

$ErrorActionPreference = 'Stop'

function ConvertTo-SafeLabel {
  param([AllowNull()][object]$Value)

  if ($null -eq $Value) { return $null }
  $text = [string]$Value
  $text = [regex]::Replace($text, '<[^>]*>', ' ')
  $text = [regex]::Replace($text, '[\x00-\x1f\x7f]', ' ')
  foreach ($character in @('\', '`', '~', '=', '*', '_', '{', '}', '[', ']', '(', ')', '#', '+', '-', '.', '!', '|', '<', '>')) {
    $text = $text.Replace($character, ' ')
  }
  $text = [regex]::Replace($text, '\s+', ' ').Trim()
  if ($text.Length -gt 120) { $text = $text.Substring(0, 120).TrimEnd() }
  return $text
}

function ConvertTo-StableIdHash {
  param([Parameter(Mandatory = $true)][string]$Value)

  $bytes = [Text.Encoding]::UTF8.GetBytes($Value)
  $hash = [Security.Cryptography.SHA256]::Create()
  try {
    return 'sha256:' + (($hash.ComputeHash($bytes) | ForEach-Object { $_.ToString('x2') }) -join '')
  }
  finally {
    $hash.Dispose()
  }
}

$validator = Join-Path $PSScriptRoot 'Test-IconDBMorningSnapshot.ps1'
& powershell -NoProfile -File $validator -Path $Path
if ($LASTEXITCODE -ne 0) {
  Write-Error 'Refusing to sanitize a snapshot that failed canonical validation.'
  exit 1
}

$sourcePath = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $Path).Path)
$targetPath = [IO.Path]::GetFullPath($OutputPath)
if ($sourcePath -eq $targetPath) {
  Write-Error 'OutputPath must differ from the validated source snapshot.'
  exit 1
}

$snapshot = Get-Content -LiteralPath $sourcePath -Raw | ConvertFrom-Json

foreach ($message in @($snapshot.messages)) {
  $message.stableId = ConvertTo-StableIdHash ([string]$message.stableId)
  $message.from = ConvertTo-SafeLabel $message.from
  $message.subject = ConvertTo-SafeLabel $message.subject
  $message.bodyPreview = ConvertTo-SafeLabel $message.bodyPreview
  if ($message.PSObject.Properties.Name -contains 'conversationId') {
    $message.conversationId = ConvertTo-StableIdHash ([string]$message.conversationId)
  }
  $message.PSObject.Properties.Remove('webLink')
}

foreach ($calendarEvent in @($snapshot.events)) {
  $calendarEvent.stableId = ConvertTo-StableIdHash ([string]$calendarEvent.stableId)
  if ($calendarEvent.privacyMode -eq 'relevant') {
    $calendarEvent.subject = ConvertTo-SafeLabel $calendarEvent.subject
    $calendarEvent.bodyPreview = ConvertTo-SafeLabel $calendarEvent.bodyPreview
    $calendarEvent.organizer = ConvertTo-SafeLabel $calendarEvent.organizer
    $calendarEvent.location = ConvertTo-SafeLabel $calendarEvent.location
    for ($index = 0; $index -lt $calendarEvent.attendees.Count; $index++) {
      $calendarEvent.attendees[$index] = ConvertTo-SafeLabel $calendarEvent.attendees[$index]
    }
    $calendarEvent.PSObject.Properties.Remove('webLink')
  }
}

$temporaryPath = "$targetPath.tmp"
try {
  $snapshot | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $temporaryPath -Encoding UTF8
  if ([IO.File]::Exists($targetPath)) {
    [IO.File]::Delete($targetPath)
  }
  [IO.File]::Move($temporaryPath, $targetPath)
}
catch {
  Remove-Item -LiteralPath $temporaryPath -Force -ErrorAction SilentlyContinue
  throw
}

Write-Host "Created Markdown-safe snapshot: $targetPath" -ForegroundColor Green
