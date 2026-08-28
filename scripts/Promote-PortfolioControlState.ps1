[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [ValidateNotNullOrEmpty()]
  [string]$DeltaPath,

  [Parameter(Mandatory = $true)]
  [ValidateNotNullOrEmpty()]
  [string]$PreviousStatePath,

  [Parameter(Mandatory = $true)]
  [ValidateNotNullOrEmpty()]
  [string]$PromoteToState,

  [ValidateRange(0.01, 24)]
  [double]$MaxAgeHours = 3
)

$deltaValidator = Join-Path $PSScriptRoot 'Test-PortfolioEvidenceDelta.ps1'
$stateValidator = Join-Path $PSScriptRoot 'Test-PortfolioControlState.ps1'
foreach ($requiredPath in @($DeltaPath, $PreviousStatePath, $deltaValidator, $stateValidator)) {
  if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) { Write-Error "Required file not found: $requiredPath"; exit 1 }
}

$targetPath = [IO.Path]::GetFullPath($PromoteToState)
if ([IO.Path]::GetFileName($targetPath) -ne 'latest-state.json') { Write-Error 'PromoteToState must target latest-state.json.'; exit 1 }
$targetDirectory = [IO.Path]::GetDirectoryName($targetPath)
if (-not [IO.Directory]::Exists($targetDirectory)) { [IO.Directory]::CreateDirectory($targetDirectory) | Out-Null }
$lockPath = "$targetPath.lock"
try { $lockStream = [IO.File]::Open($lockPath, [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None) }
catch { Write-Error "State promotion is already running or the lock cannot be acquired: $($_.Exception.Message)"; exit 1 }

try {

  try {
    $deltaBytes = [IO.File]::ReadAllBytes([IO.Path]::GetFullPath($DeltaPath))
    $previousBytes = [IO.File]::ReadAllBytes([IO.Path]::GetFullPath($PreviousStatePath))
  }
  catch { Write-Error "Delta or predecessor could not be read: $($_.Exception.Message)"; exit 1 }

  & powershell -NoProfile -File $deltaValidator -Path $DeltaPath -PreviousCheckpointPath $PreviousStatePath -MaxAgeHours $MaxAgeHours
  if ($LASTEXITCODE -ne 0) { Write-Error 'Delta validation failed; state was not promoted.'; exit 1 }

  try {
    $currentDeltaBytes = [IO.File]::ReadAllBytes([IO.Path]::GetFullPath($DeltaPath))
    $currentPreviousBytes = [IO.File]::ReadAllBytes([IO.Path]::GetFullPath($PreviousStatePath))
    if ([Convert]::ToBase64String($deltaBytes) -cne [Convert]::ToBase64String($currentDeltaBytes)) { throw 'Delta changed during validation.' }
    if ([Convert]::ToBase64String($previousBytes) -cne [Convert]::ToBase64String($currentPreviousBytes)) { throw 'Predecessor changed during validation.' }
    $delta = ([Text.Encoding]::UTF8.GetString($deltaBytes)).TrimStart([char]0xFEFF) | ConvertFrom-Json -ErrorAction Stop
    $previous = ([Text.Encoding]::UTF8.GetString($previousBytes)).TrimStart([char]0xFEFF) | ConvertFrom-Json -ErrorAction Stop
  }
  catch { Write-Error "Delta or predecessor is not valid JSON: $($_.Exception.Message)"; exit 1 }

  $threadMap = @{}
  foreach ($item in @($previous.threadHeads)) {
    if ($null -ne $item) { $threadMap[[string]$item.conversationId] = $item }
  }
  foreach ($head in @($delta.threadHeads)) {
    $conversationId = [string]$head.conversationId
    $existing = $threadMap[$conversationId]
    if ($head.changeType -eq 'new') {
      if ($null -ne $existing) { Write-Error "New thread '$conversationId' already exists in predecessor state."; exit 1 }
      if ($null -ne $head.previousHeadId -and -not [string]::IsNullOrWhiteSpace([string]$head.previousHeadId)) { Write-Error "New thread '$conversationId' cannot have previousHeadId."; exit 1 }
    }
    elseif ($head.changeType -eq 'advanced') {
      if ($null -eq $existing) { Write-Error "Advanced thread '$conversationId' is absent from predecessor state."; exit 1 }
      if ([string]$existing.currentHeadId -ne [string]$head.previousHeadId) { Write-Error "Advanced thread '$conversationId' does not continue from its predecessor head."; exit 1 }
      if ([string]$head.currentHeadId -eq [string]$head.previousHeadId) { Write-Error "Advanced thread '$conversationId' must advance to a different head."; exit 1 }
    }
    else { Write-Error "Thread '$conversationId' has unsupported changeType '$($head.changeType)'."; exit 1 }
    $threadMap[$conversationId] = [pscustomobject][ordered]@{
      conversationId = $conversationId
      currentHeadId  = [string]$head.currentHeadId
      lastObservedAt = [string]$delta.window.windowEnd
    }
  }

  $calendarMap = @{}
  foreach ($item in @($previous.calendarFingerprints)) {
    if ($null -ne $item) { $calendarMap[[string]$item.stableId] = $item }
  }
  foreach ($change in @($delta.calendarChanges)) {
    $stableId = [string]$change.stableId
    $existing = $calendarMap[$stableId]
    if ($change.changeType -eq 'added' -and $null -ne $existing) { Write-Error "Added calendar event '$stableId' already exists in predecessor state."; exit 1 }
    if (@('updated', 'cancelled') -contains [string]$change.changeType -and $null -eq $existing) { Write-Error "$($change.changeType) calendar event '$stableId' is absent from predecessor state."; exit 1 }
    if ($change.changeType -eq 'updated' -and [string]$existing.changeType -ne 'cancelled' -and [string]$existing.fingerprint -eq [string]$change.fingerprint) { Write-Error "Updated calendar event '$stableId' must have a new fingerprint unless it reappears after cancellation."; exit 1 }
    if ($change.changeType -eq 'cancelled' -and [string]$existing.changeType -eq 'cancelled') { Write-Error "Calendar event '$stableId' is already cancelled."; exit 1 }
    $calendarMap[$stableId] = [pscustomobject][ordered]@{
      stableId       = $stableId
      fingerprint    = [string]$change.fingerprint
      privacyMode    = [string]$change.privacyMode
      start          = [string]$change.start
      end            = [string]$change.end
      showAs         = [string]$change.showAs
      isAllDay       = [bool]$change.isAllDay
      changeType     = [string]$change.changeType
      lastObservedAt = [string]$delta.window.windowEnd
    }
  }

  $nextState = [ordered]@{
    schemaVersion        = '1.0'
    run                  = [ordered]@{
      runId      = [string]$delta.run.runId
      status     = 'complete'
      exportedAt = [string]$delta.run.exportedAt
    }
    checkpoint           = [ordered]@{
      watermark  = [string]$delta.window.windowEnd
      promotedAt = [DateTimeOffset]::UtcNow.ToString('o')
    }
    sourceDeltaPath      = [string]$delta.run.outputPath
    threadHeads          = @($threadMap.Values | Sort-Object conversationId)
    calendarFingerprints = @($calendarMap.Values | Sort-Object stableId)
  }

  $temporaryPath = "$targetPath.promoting"
  try {
    $stateJson = $nextState | ConvertTo-Json -Depth 10
    [IO.File]::WriteAllText($temporaryPath, $stateJson, [Text.UTF8Encoding]::new($false))
    & powershell -NoProfile -File $stateValidator -Path $temporaryPath
    if ($LASTEXITCODE -ne 0) { throw 'Candidate state validation failed.' }
    if ([IO.File]::Exists($targetPath)) {
      [IO.File]::Replace($temporaryPath, $targetPath, "$targetPath.previous", $true)
      Remove-Item -LiteralPath "$targetPath.previous" -Force -ErrorAction SilentlyContinue
    }
    else { [IO.File]::Move($temporaryPath, $targetPath) }
    Write-Host "Promoted portfolio control state to $targetPath." -ForegroundColor Green
  }
  catch {
    Remove-Item -LiteralPath $temporaryPath -Force -ErrorAction SilentlyContinue
    Write-Error "State promotion failed: $($_.Exception.Message)"
    exit 1
  }

  exit 0
}
finally {
  if ($null -ne $lockStream) { $lockStream.Dispose() }
  Remove-Item -LiteralPath $lockPath -Force -ErrorAction SilentlyContinue
}
