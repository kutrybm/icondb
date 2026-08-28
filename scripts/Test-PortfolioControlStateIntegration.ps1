[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$deltaValidator = Join-Path $PSScriptRoot 'Test-PortfolioEvidenceDelta.ps1'
$stateValidator = Join-Path $PSScriptRoot 'Test-PortfolioControlState.ps1'
$promoter = Join-Path $PSScriptRoot 'Promote-PortfolioControlState.ps1'
$testDirectory = Join-Path $env:TEMP ('portfolio-state-integration-' + [Guid]::NewGuid())
New-Item -ItemType Directory -Path $testDirectory | Out-Null

function Write-Json([object]$Value, [string]$Path) {
  $Value | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Get-SyntheticCalendarFingerprint([object]$Item) {
  $start = [DateTimeOffset]::Parse([string]$Item.start)
  $end = [DateTimeOffset]::Parse([string]$Item.end)
  $canonical = [ordered]@{
    stableId    = [string]$Item.stableId
    privacyMode = [string]$Item.privacyMode
    start       = $start.UtcDateTime.ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ', [Globalization.CultureInfo]::InvariantCulture)
    end         = $end.UtcDateTime.ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ', [Globalization.CultureInfo]::InvariantCulture)
    showAs      = ([string]$Item.showAs).ToLowerInvariant()
    isAllDay    = [bool]$Item.isAllDay
    subject     = if ($Item.privacyMode -eq 'relevant') { [string]$Item.subject } else { '' }
    bodyPreview = if ($Item.privacyMode -eq 'relevant') { [string]$Item.bodyPreview } else { '' }
  }
  $sha256 = [Security.Cryptography.SHA256]::Create()
  try { return 'sha256:' + (($sha256.ComputeHash([Text.Encoding]::UTF8.GetBytes(($canonical | ConvertTo-Json -Compress))) | ForEach-Object { $_.ToString('x2') }) -join '') }
  finally { $sha256.Dispose() }
}

function Invoke-CheckedScript([string]$ScriptPath, [string[]]$Arguments, [bool]$ShouldPass, [string]$Context) {
  $logPath = Join-Path $testDirectory (([Guid]::NewGuid().ToString()) + '.log')
  $previousPreference = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  & powershell -NoProfile -File $ScriptPath @Arguments *> $logPath
  $exitCode = $LASTEXITCODE
  $ErrorActionPreference = $previousPreference
  if ($ShouldPass -and $exitCode -ne 0) { throw "$Context failed unexpectedly: $(Get-Content -Raw $logPath)" }
  if (-not $ShouldPass -and $exitCode -eq 0) { throw "$Context passed unexpectedly." }
}

function New-Coverage([int]$Inbox, [int]$Sent, [int]$Calendar) {
  return [ordered]@{
    inbox     = [ordered]@{ complete = $true; sourceCount = $Inbox; retainedCount = $Inbox }
    sentItems = [ordered]@{ complete = $true; sourceCount = $Sent; retainedCount = $Sent }
    calendar  = [ordered]@{ complete = $true; sourceCount = $Calendar; retainedCount = $Calendar }
    drafts    = [ordered]@{ complete = $true; sourceCount = 0; retainedCount = 0 }
    tasks     = [ordered]@{ complete = $true; sourceCount = 0; retainedCount = 0 }
  }
}

function New-Delta(
  [string]$RunId,
  [string]$PreviousRunId,
  [DateTimeOffset]$PreviousWatermark,
  [DateTimeOffset]$WindowEnd,
  [object[]]$Messages,
  [object[]]$CalendarChanges,
  [object[]]$ThreadHeads
) {
  $routes = @()
  foreach ($item in @($Messages) + @($CalendarChanges)) {
    $routes += [ordered]@{ stableId = [string]$item.stableId; projects = @('icondb'); disposition = 'routed'; reasonCodes = @('synthetic') }
  }
  return [ordered]@{
    schemaVersion   = '2.0'
    run             = [ordered]@{
      runId = $RunId; previousRunId = $PreviousRunId; exportedAt = $WindowEnd.ToString('o'); status = 'complete'
      timeZone = 'Central European Standard Time'; collector = 'Power Automate'; mailboxScope = 'delegated-user'
      outputPath = "/GBS IT docs/.local/portfolio-control/candidates/portfolio-evidence-delta-$($WindowEnd.UtcDateTime.ToString('yyyyMMdd-HHmmss'))Z-$RunId.json"
    }
    window          = [ordered]@{ previousWatermark = $PreviousWatermark.ToString('o'); windowStart = $PreviousWatermark.AddMinutes(-15).ToString('o'); windowEnd = $WindowEnd.ToString('o'); overlapMinutes = 15 }
    coverage        = New-Coverage @($Messages | Where-Object { $_.folder -eq 'inbox' }).Count @($Messages | Where-Object { $_.folder -eq 'sentItems' }).Count @($CalendarChanges).Count
    messages        = @($Messages)
    calendarChanges = @($CalendarChanges)
    drafts          = @()
    tasks           = @()
    threadHeads     = @($ThreadHeads)
    routes          = @($routes)
  }
}

try {
  $goldenEvent = [ordered]@{ stableId = 'event:golden'; privacyMode = 'busyOnly'; start = '2026-08-26T10:00:00.0000000Z'; end = '2026-08-26T11:00:00.0000000Z'; showAs = 'busy'; isAllDay = $false }
  if ((Get-SyntheticCalendarFingerprint $goldenEvent) -ne 'sha256:9f78a4163037e0d3a6a702350fbdb9507cea75f8c0faaea4b348a3750b34b95f') { throw 'Canonical fingerprint golden vector changed.' }

  $bootstrapRunId = [Guid]::NewGuid().ToString()
  $firstRunId = [Guid]::NewGuid().ToString()
  $secondRunId = [Guid]::NewGuid().ToString()
  $bootstrapWatermark = [DateTimeOffset]::UtcNow.AddHours(-2)
  $firstEnd = [DateTimeOffset]::UtcNow.AddHours(-1)
  $secondEnd = [DateTimeOffset]::UtcNow
  $bootstrapPath = Join-Path $testDirectory 'bootstrap.json'
  $statePath = Join-Path $testDirectory 'latest-state.json'
  Write-Json ([ordered]@{ schemaVersion = '2.0'; run = [ordered]@{ runId = $bootstrapRunId; status = 'complete' }; checkpoint = [ordered]@{ watermark = $bootstrapWatermark.ToString('o'); promotedAt = $bootstrapWatermark.ToString('o') } }) $bootstrapPath

  $firstMessages = @(
    [ordered]@{ stableId = 'mail:one'; folder = 'inbox'; occurredAt = $firstEnd.AddMinutes(-5).ToString('o'); subject = 'Synthetic one'; counterparty = 'synthetic@example.invalid'; bodyPreview = ''; conversationId = 'conversation:one'; importance = 'normal' }
  )
  $firstCalendar = @(
    [ordered]@{ stableId = 'event:update'; fingerprint = ''; changeType = 'added'; privacyMode = 'busyOnly'; start = $firstEnd.AddHours(1).ToString('o'); end = $firstEnd.AddHours(2).ToString('o'); showAs = 'busy'; isAllDay = $false },
    [ordered]@{ stableId = 'event:cancel'; fingerprint = ''; changeType = 'added'; privacyMode = 'relevant'; start = $firstEnd.AddHours(3).ToString('o'); end = $firstEnd.AddHours(4).ToString('o'); showAs = 'tentative'; isAllDay = $false; subject = 'Synthetic relevant'; bodyPreview = '' }
  )
  foreach ($item in $firstCalendar) { $item.fingerprint = Get-SyntheticCalendarFingerprint $item }
  $firstHeads = @([ordered]@{ conversationId = 'conversation:one'; previousHeadId = $null; currentHeadId = 'mail:one'; changeType = 'new' })
  $firstDelta = New-Delta $firstRunId $bootstrapRunId $bootstrapWatermark $firstEnd $firstMessages $firstCalendar $firstHeads
  $firstDeltaPath = Join-Path $testDirectory 'first-delta.json'
  Write-Json $firstDelta $firstDeltaPath
  Invoke-CheckedScript $promoter @('-DeltaPath', $firstDeltaPath, '-PreviousStatePath', $bootstrapPath, '-PromoteToState', $statePath) $true 'bootstrap promotion'
  $promotedBytes = [IO.File]::ReadAllBytes($statePath)
  if ($promotedBytes.Length -eq 0 -or $promotedBytes[0] -ne 0x7B) { throw 'Promoted state must be BOM-less UTF-8 JSON.' }
  $firstStateCopyPath = Join-Path $testDirectory 'first-state-copy.json'
  Copy-Item -LiteralPath $statePath -Destination $firstStateCopyPath

  $secondMessages = @(
    [ordered]@{ stableId = 'mail:two'; folder = 'sentItems'; occurredAt = $secondEnd.AddMinutes(-5).ToString('o'); subject = 'Synthetic two'; counterparty = 'synthetic@example.invalid'; bodyPreview = ''; conversationId = 'conversation:one'; importance = 'normal' },
    [ordered]@{ stableId = 'mail:new'; folder = 'inbox'; occurredAt = $secondEnd.AddMinutes(-4).ToString('o'); subject = 'Synthetic new'; counterparty = 'synthetic@example.invalid'; bodyPreview = ''; conversationId = 'conversation:new'; importance = 'normal' }
  )
  $secondCalendar = @(
    [ordered]@{ stableId = 'event:update'; fingerprint = ''; changeType = 'updated'; privacyMode = 'busyOnly'; start = $secondEnd.AddHours(1).ToString('o'); end = $secondEnd.AddHours(2).ToString('o'); showAs = 'oof'; isAllDay = $false },
    [ordered]@{ stableId = 'event:cancel'; fingerprint = ''; changeType = 'cancelled'; privacyMode = 'relevant'; start = $secondEnd.AddHours(3).ToString('o'); end = $secondEnd.AddHours(4).ToString('o'); showAs = 'free'; isAllDay = $false; subject = 'Synthetic relevant'; bodyPreview = '' }
  )
  foreach ($item in $secondCalendar) { $item.fingerprint = Get-SyntheticCalendarFingerprint $item }
  $secondHeads = @(
    [ordered]@{ conversationId = 'conversation:one'; previousHeadId = 'mail:one'; currentHeadId = 'mail:two'; changeType = 'advanced' },
    [ordered]@{ conversationId = 'conversation:new'; previousHeadId = $null; currentHeadId = 'mail:new'; changeType = 'new' }
  )
  $secondDelta = New-Delta $secondRunId $firstRunId $firstEnd $secondEnd $secondMessages $secondCalendar $secondHeads
  $secondDeltaPath = Join-Path $testDirectory 'second-delta.json'
  Write-Json $secondDelta $secondDeltaPath

  $sameHead = $secondDelta | ConvertTo-Json -Depth 12 | ConvertFrom-Json
  $sameHead.run.runId = [Guid]::NewGuid().ToString()
  $sameHead.threadHeads[0].previousHeadId = 'mail:two'
  $sameHeadPath = Join-Path $testDirectory 'same-head.json'; Write-Json $sameHead $sameHeadPath
  Invoke-CheckedScript $deltaValidator @('-Path', $sameHeadPath, '-PreviousCheckpointPath', $firstStateCopyPath, '-MaxAgeHours', '1') $false 'same-head advancement rejection'

  $stringBoolean = $secondDelta | ConvertTo-Json -Depth 12 | ConvertFrom-Json
  $stringBoolean.run.runId = [Guid]::NewGuid().ToString()
  $stringBoolean.calendarChanges[0].isAllDay = 'false'
  $stringBoolean.calendarChanges[0].fingerprint = Get-SyntheticCalendarFingerprint $stringBoolean.calendarChanges[0]
  $stringBooleanPath = Join-Path $testDirectory 'string-boolean.json'; Write-Json $stringBoolean $stringBooleanPath
  Invoke-CheckedScript $deltaValidator @('-Path', $stringBooleanPath, '-PreviousCheckpointPath', $firstStateCopyPath, '-MaxAgeHours', '1') $false 'string boolean rejection'

  $wrongConversation = $secondDelta | ConvertTo-Json -Depth 12 | ConvertFrom-Json
  $wrongConversation.run.runId = [Guid]::NewGuid().ToString()
  $wrongConversation.messages[0].conversationId = 'conversation:other'
  $wrongConversationPath = Join-Path $testDirectory 'wrong-conversation.json'; Write-Json $wrongConversation $wrongConversationPath
  Invoke-CheckedScript $deltaValidator @('-Path', $wrongConversationPath, '-PreviousCheckpointPath', $firstStateCopyPath, '-MaxAgeHours', '1') $false 'head conversation mismatch rejection'

  $noOpUpdate = $secondDelta | ConvertTo-Json -Depth 12 | ConvertFrom-Json
  $noOpUpdate.run.runId = [Guid]::NewGuid().ToString()
  $priorEvent = (Get-Content -Raw $firstStateCopyPath | ConvertFrom-Json).calendarFingerprints | Where-Object stableId -eq 'event:update'
  $noOpUpdate.calendarChanges[0].start = $priorEvent.start
  $noOpUpdate.calendarChanges[0].end = $priorEvent.end
  $noOpUpdate.calendarChanges[0].showAs = $priorEvent.showAs
  $noOpUpdate.calendarChanges[0].fingerprint = $priorEvent.fingerprint
  $noOpPath = Join-Path $testDirectory 'no-op-update.json'; Write-Json $noOpUpdate $noOpPath
  Invoke-CheckedScript $promoter @('-DeltaPath', $noOpPath, '-PreviousStatePath', $firstStateCopyPath, '-PromoteToState', $statePath) $false 'no-op calendar update rejection'

  $stateBeforeLockTest = [IO.File]::ReadAllBytes($statePath)
  $heldLock = [IO.File]::Open("$statePath.lock", [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
  try { Invoke-CheckedScript $promoter @('-DeltaPath', $secondDeltaPath, '-PreviousStatePath', $firstStateCopyPath, '-PromoteToState', $statePath) $false 'concurrent promotion rejection' }
  finally { $heldLock.Dispose(); Remove-Item -LiteralPath "$statePath.lock" -Force -ErrorAction SilentlyContinue }
  if ([Convert]::ToBase64String($stateBeforeLockTest) -ne [Convert]::ToBase64String([IO.File]::ReadAllBytes($statePath))) { throw 'Concurrent promotion rejection changed authoritative state.' }

  Set-Content -LiteralPath "$statePath.promoting" -Value 'stale temporary state' -Encoding UTF8
  Invoke-CheckedScript $promoter @('-DeltaPath', $secondDeltaPath, '-PreviousStatePath', $statePath, '-PromoteToState', $statePath) $true 'second promotion'
  if (Test-Path "$statePath.promoting") { throw 'Successful promotion left a temporary file.' }

  $state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
  if ($state.run.runId -ne $secondRunId -or $state.threadHeads.Count -ne 2 -or $state.calendarFingerprints.Count -ne 2) { throw 'Second-generation state counts or run ID are wrong.' }
  if (($state.threadHeads | Where-Object conversationId -eq 'conversation:one').currentHeadId -ne 'mail:two') { throw 'Advanced thread head was not promoted.' }
  if (($state.calendarFingerprints | Where-Object stableId -eq 'event:cancel').changeType -ne 'cancelled') { throw 'Cancelled event was not retained.' }
  Invoke-CheckedScript $stateValidator @('-Path', $statePath) $true 'promoted state validation'

  $repeatCancellationEnd = $secondEnd.AddMilliseconds(1)
  $repeatCancellation = [ordered]@{ stableId = 'event:cancel'; fingerprint = ''; changeType = 'cancelled'; privacyMode = 'relevant'; start = $secondCalendar[1].start; end = $secondCalendar[1].end; showAs = 'free'; isAllDay = $false; subject = 'Synthetic relevant'; bodyPreview = '' }
  $repeatCancellation.fingerprint = Get-SyntheticCalendarFingerprint $repeatCancellation
  $repeatCancellationDelta = New-Delta ([Guid]::NewGuid().ToString()) $secondRunId $secondEnd $repeatCancellationEnd @() @($repeatCancellation) @()
  $repeatCancellationPath = Join-Path $testDirectory 'repeat-cancellation.json'; Write-Json $repeatCancellationDelta $repeatCancellationPath
  Invoke-CheckedScript $promoter @('-DeltaPath', $repeatCancellationPath, '-PreviousStatePath', $statePath, '-PromoteToState', $statePath) $false 'repeated cancellation rejection'

  $reappeared = $repeatCancellation | ConvertTo-Json -Depth 12 | ConvertFrom-Json
  $reappeared.changeType = 'updated'
  $reappearedDelta = New-Delta ([Guid]::NewGuid().ToString()) $secondRunId $secondEnd $repeatCancellationEnd @() @($reappeared) @()
  $reappearedPath = Join-Path $testDirectory 'reappeared.json'; Write-Json $reappearedDelta $reappearedPath
  $reappearedDirectory = Join-Path $testDirectory 'reappeared-state'; New-Item -ItemType Directory -Path $reappearedDirectory | Out-Null
  $reappearedStatePath = Join-Path $reappearedDirectory 'latest-state.json'
  Invoke-CheckedScript $promoter @('-DeltaPath', $reappearedPath, '-PreviousStatePath', $statePath, '-PromoteToState', $reappearedStatePath) $true 'same-fingerprint reappearance promotion'
  if (((Get-Content -LiteralPath $reappearedStatePath -Raw | ConvertFrom-Json).calendarFingerprints | Where-Object stableId -eq 'event:cancel').changeType -ne 'updated') { throw 'Reappeared event was not restored.' }

  $stateBytes = [IO.File]::ReadAllBytes($statePath)
  Invoke-CheckedScript $promoter @('-DeltaPath', $firstDeltaPath, '-PreviousStatePath', $statePath, '-PromoteToState', $statePath) $false 'replay rejection'
  if ([Convert]::ToBase64String($stateBytes) -ne [Convert]::ToBase64String([IO.File]::ReadAllBytes($statePath))) { throw 'Replay rejection changed authoritative state.' }

  $badAdvance = $secondDelta | ConvertTo-Json -Depth 12 | ConvertFrom-Json
  $badAdvance.run.runId = [Guid]::NewGuid().ToString()
  $badAdvance.threadHeads[0].previousHeadId = 'mail:wrong'
  $badAdvancePath = Join-Path $testDirectory 'bad-advance.json'; Write-Json $badAdvance $badAdvancePath
  Invoke-CheckedScript $promoter @('-DeltaPath', $badAdvancePath, '-PreviousStatePath', $firstStateCopyPath, '-PromoteToState', $statePath) $false 'mismatched head rejection'

  $duplicateState = $state | ConvertTo-Json -Depth 12 | ConvertFrom-Json
  $duplicateState.threadHeads = @($duplicateState.threadHeads + $duplicateState.threadHeads[0])
  $duplicatePath = Join-Path $testDirectory 'duplicate-state.json'; Write-Json $duplicateState $duplicatePath
  Invoke-CheckedScript $stateValidator @('-Path', $duplicatePath) $false 'duplicate state rejection'

  $badHash = $secondDelta | ConvertTo-Json -Depth 12 | ConvertFrom-Json
  $badHash.calendarChanges[0].fingerprint = 'sha256:BAD'
  $badHashPath = Join-Path $testDirectory 'bad-hash.json'; Write-Json $badHash $badHashPath
  Invoke-CheckedScript $deltaValidator @('-Path', $badHashPath, '-PreviousCheckpointPath', $statePath, '-MaxAgeHours', '1') $false 'malformed hash rejection'

  $privacyLeak = $secondDelta | ConvertTo-Json -Depth 12 | ConvertFrom-Json
  $privacyLeak.calendarChanges[0] | Add-Member -NotePropertyName subject -NotePropertyValue 'Must not leak'
  $privacyPath = Join-Path $testDirectory 'privacy-leak.json'; Write-Json $privacyLeak $privacyPath
  Invoke-CheckedScript $deltaValidator @('-Path', $privacyPath, '-PreviousCheckpointPath', $statePath, '-MaxAgeHours', '1') $false 'privacy rejection'

  $thirdRunId = [Guid]::NewGuid().ToString(); $thirdEnd = $secondEnd.AddMinutes(1)
  $thirdDelta = New-Delta $thirdRunId $secondRunId $secondEnd $thirdEnd @() @() @()
  $thirdPath = Join-Path $testDirectory 'third-delta.json'; Write-Json $thirdDelta $thirdPath
  Invoke-CheckedScript $deltaValidator @('-Path', $thirdPath, '-PreviousCheckpointPath', $statePath, '-MaxAgeHours', '1') $true 'next-run predecessor reuse'

  Write-Host 'PASS: portfolio control state integration suite completed.' -ForegroundColor Green
}
finally {
  Remove-Item -LiteralPath $testDirectory -Recurse -Force -ErrorAction SilentlyContinue
}
