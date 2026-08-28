[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$builder = Join-Path $PSScriptRoot 'ConvertTo-PortfolioEvidenceDelta.ps1'
$root = Join-Path $env:TEMP ('portfolio-delta-builder-' + [Guid]::NewGuid())
New-Item -ItemType Directory -Path $root | Out-Null

function Write-Json([object]$Value, [string]$Path) { $Value | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $Path -Encoding UTF8 }
function Fingerprint([object]$Item) {
  $canonical = [ordered]@{
    stableId = [string]$Item.stableId; privacyMode = [string]$Item.privacyMode
    start = ([DateTimeOffset]::Parse([string]$Item.start)).UtcDateTime.ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ', [Globalization.CultureInfo]::InvariantCulture)
    end = ([DateTimeOffset]::Parse([string]$Item.end)).UtcDateTime.ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ', [Globalization.CultureInfo]::InvariantCulture)
    showAs = ([string]$Item.showAs).ToLowerInvariant(); isAllDay = [bool]$Item.isAllDay
    subject = if ($Item.privacyMode -eq 'relevant') { [string]$Item.subject } else { '' }
    bodyPreview = if ($Item.privacyMode -eq 'relevant') { [string]$Item.bodyPreview } else { '' }
  }
  $sha256 = [Security.Cryptography.SHA256]::Create()
  try { return 'sha256:' + (($sha256.ComputeHash([Text.Encoding]::UTF8.GetBytes(($canonical | ConvertTo-Json -Compress))) | ForEach-Object { $_.ToString('x2') }) -join '') }
  finally { $sha256.Dispose() }
}
function Invoke-Builder([string]$Projection, [string]$Previous, [string]$Output, [bool]$ShouldPass, [string]$PromoteToState = '') {
  $logPath = Join-Path $root ([Guid]::NewGuid().ToString() + '.log')
  $previousPreference = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  if ([string]::IsNullOrWhiteSpace($PromoteToState)) {
    & powershell -NoProfile -File $builder -ProjectionPath $Projection -PreviousStatePath $Previous -OutputPath $Output -MaxAgeHours 1 *> $logPath
  }
  else {
    & powershell -NoProfile -File $builder -ProjectionPath $Projection -PreviousStatePath $Previous -OutputPath $Output -MaxAgeHours 1 -PromoteToState $PromoteToState *> $logPath
  }
  $exitCode = $LASTEXITCODE
  $ErrorActionPreference = $previousPreference
  if ($ShouldPass -and $exitCode -ne 0) { throw "Builder failed unexpectedly: $(Get-Content -LiteralPath $logPath -Raw)" }
  if (-not $ShouldPass -and $exitCode -eq 0) { throw 'Builder passed unexpectedly.' }
}
function Coverage([int]$Count) { return [ordered]@{ complete = $true; sourceCount = $Count; retainedCount = $Count } }
function Copy-Projection([object]$Value) {
  $copy = $Value | ConvertTo-Json -Depth 12 | ConvertFrom-Json
  $copy.run.runId = [Guid]::NewGuid().ToString()
  $copy.run.candidatePath = "/GBS IT docs/.local/portfolio-control/candidates/portfolio-evidence-delta-$(([DateTimeOffset]::Parse([string]$copy.window.windowEnd)).UtcDateTime.ToString('yyyyMMdd-HHmmss'))Z-$($copy.run.runId).json"
  return $copy
}

try {
  $previousRun = [Guid]::NewGuid().ToString()
  $run = [Guid]::NewGuid().ToString()
  $watermark = [DateTimeOffset]::UtcNow.AddMinutes(-30)
  $windowEnd = [DateTimeOffset]::UtcNow
  $previousPath = Join-Path $root 'previous.json'
  $projectionPath = Join-Path $root 'projection.json'
  $outputPath = Join-Path $root 'portfolio-evidence-delta.json'
  $previousUpdate = [ordered]@{ stableId = 'event:update'; privacyMode = 'busyOnly'; start = $windowEnd.AddHours(1).ToString('o'); end = $windowEnd.AddHours(2).ToString('o'); showAs = 'busy'; isAllDay = $false; changeType = 'added'; lastObservedAt = $watermark.ToString('o') }
  $previousCancel = [ordered]@{ stableId = 'event:cancel'; privacyMode = 'busyOnly'; start = $windowEnd.AddHours(3).ToString('o'); end = $windowEnd.AddHours(4).ToString('o'); showAs = 'busy'; isAllDay = $false; changeType = 'added'; lastObservedAt = $watermark.ToString('o') }
  $previousUpdate.fingerprint = Fingerprint $previousUpdate
  $previousCancel.fingerprint = Fingerprint $previousCancel
  $previous = [ordered]@{
    schemaVersion = '1.0'; run = [ordered]@{ runId = $previousRun; status = 'complete'; exportedAt = $watermark.ToString('o') }
    checkpoint = [ordered]@{ watermark = $watermark.ToString('o'); promotedAt = $watermark.ToString('o') }
    sourceDeltaPath = '/GBS IT docs/.local/portfolio-control/candidates/portfolio-evidence-delta-20260827-120000Z-00000000-0000-0000-0000-000000000000.json'
    threadHeads = @([ordered]@{ conversationId = 'conversation:old'; currentHeadId = 'mail:old'; lastObservedAt = $watermark.ToString('o') })
    calendarFingerprints = @($previousUpdate, $previousCancel)
  }
  Write-Json $previous $previousPath

  $messages = @(
    [ordered]@{ stableId = 'mail:new'; folder = 'inbox'; occurredAt = $windowEnd.AddMinutes(-5).ToString('o'); subject = 'New'; counterparty = 'test@example.invalid'; bodyPreview = ''; conversationId = 'conversation:new'; importance = 'normal' },
    [ordered]@{ stableId = 'mail:advanced'; folder = 'sentItems'; occurredAt = $windowEnd.AddMinutes(-4).ToString('o'); subject = 'Advanced'; counterparty = 'test@example.invalid'; bodyPreview = ''; conversationId = 'conversation:old'; importance = 'normal' }
  )
  $events = @(
    [ordered]@{ stableId = 'event:update'; privacyMode = 'busyOnly'; start = $windowEnd.AddHours(1).ToString('o'); end = $windowEnd.AddHours(2).ToString('o'); showAs = 'oof'; isAllDay = $false },
    [ordered]@{ stableId = 'event:add'; privacyMode = 'relevant'; start = $windowEnd.AddHours(5).ToString('o'); end = $windowEnd.AddHours(6).ToString('o'); showAs = 'busy'; isAllDay = $false; subject = 'IconDB'; bodyPreview = '' }
  )
  $routes = @()
  foreach ($id in @($messages.stableId) + @($events.stableId)) { $routes += [ordered]@{ stableId = $id; projects = @('icondb'); disposition = 'routed'; reasonCodes = @('synthetic') } }
  $candidatePath = "/GBS IT docs/.local/portfolio-control/candidates/portfolio-evidence-delta-$($windowEnd.UtcDateTime.ToString('yyyyMMdd-HHmmss'))Z-$run.json"
  $projection = [ordered]@{
    schemaVersion = '1.0'; run = [ordered]@{ runId = $run; exportedAt = $windowEnd.ToString('o'); timeZone = 'Central European Standard Time'; candidatePath = $candidatePath }
    window = [ordered]@{ previousWatermark = $watermark.ToString('o'); windowStart = $watermark.AddMinutes(-15).ToString('o'); windowEnd = $windowEnd.ToString('o'); overlapMinutes = 15; calendarStart = $windowEnd.ToString('o'); calendarEnd = $windowEnd.AddDays(42).ToString('o') }
    coverage = [ordered]@{ inbox = Coverage 1; sentItems = Coverage 1; calendar = Coverage 2; drafts = Coverage 0; tasks = Coverage 0 }
    messages = $messages; calendarEvents = $events; drafts = @(); tasks = @(); routes = $routes
  }
  Write-Json $projection $projectionPath
  Invoke-Builder $projectionPath $previousPath $outputPath $true
  $delta = Get-Content -LiteralPath $outputPath -Raw | ConvertFrom-Json
  if ($delta.threadHeads.Count -ne 2) { throw 'Expected new and advanced thread transitions.' }
  if ($delta.calendarChanges.Count -ne 3) { throw 'Expected added, updated, and cancelled calendar changes.' }
  if (@($delta.calendarChanges | Where-Object { $_.changeType -eq 'cancelled' }).Count -ne 1) { throw 'Expected one bounded cancellation.' }
  if (@($delta.calendarChanges | Where-Object { $_.privacyMode -eq 'busyOnly' -and ($_.PSObject.Properties.Name -contains 'subject') }).Count -ne 0) { throw 'Busy-only detail leaked.' }

  $unchanged = Copy-Projection $projection
  $unchanged.messages = @()
  $unchanged.calendarEvents = @(
    [ordered]@{ stableId = $previousUpdate.stableId; privacyMode = $previousUpdate.privacyMode; start = $previousUpdate.start; end = $previousUpdate.end; showAs = $previousUpdate.showAs; isAllDay = $previousUpdate.isAllDay }
  )
  $unchanged.routes = @([ordered]@{ stableId = $previousUpdate.stableId; projects = @('icondb'); disposition = 'routed'; reasonCodes = @('synthetic') })
  $unchanged.coverage.inbox = Coverage 0; $unchanged.coverage.sentItems = Coverage 0; $unchanged.coverage.calendar = Coverage 1
  $alreadyCancelledPrevious = $previous | ConvertTo-Json -Depth 12 | ConvertFrom-Json
  $alreadyCancelledPrevious.calendarFingerprints[1].changeType = 'cancelled'
  $alreadyCancelledPreviousPath = Join-Path $root 'already-cancelled-previous.json'; Write-Json $alreadyCancelledPrevious $alreadyCancelledPreviousPath
  $unchangedPath = Join-Path $root 'unchanged.json'; Write-Json $unchanged $unchangedPath
  $unchangedOutput = Join-Path $root 'unchanged-output.json'
  Invoke-Builder $unchangedPath $alreadyCancelledPreviousPath $unchangedOutput $true
  $unchangedDelta = Get-Content -LiteralPath $unchangedOutput -Raw | ConvertFrom-Json
  if (@($unchangedDelta.calendarChanges).Count -ne 0 -or @($unchangedDelta.threadHeads).Count -ne 0) { throw 'Unchanged or already-cancelled records were re-emitted.' }

  $overlap = Copy-Projection $unchanged
  $overlap.messages = @([ordered]@{ stableId = 'mail:overlap'; folder = 'inbox'; occurredAt = $watermark.AddMinutes(-1).ToString('o'); subject = 'Overlap'; counterparty = 'test@example.invalid'; bodyPreview = ''; conversationId = 'conversation:old'; importance = 'normal' })
  $overlap.routes += [ordered]@{ stableId = 'mail:overlap'; projects = @('icondb'); disposition = 'routed'; reasonCodes = @('synthetic') }
  $overlap.coverage.inbox = Coverage 1
  $overlapPath = Join-Path $root 'overlap.json'; Write-Json $overlap $overlapPath
  $overlapOutput = Join-Path $root 'overlap-output.json'
  Invoke-Builder $overlapPath $alreadyCancelledPreviousPath $overlapOutput $true
  if (@((Get-Content -LiteralPath $overlapOutput -Raw | ConvertFrom-Json).threadHeads).Count -ne 0) { throw 'Overlap message incorrectly advanced the predecessor thread head.' }

  $invalidProjection = Copy-Projection $projection
  Add-Member -InputObject $invalidProjection.calendarEvents[0] -NotePropertyName subject -NotePropertyValue 'private'
  $invalidPath = Join-Path $root 'invalid.json'; Write-Json $invalidProjection $invalidPath
  Invoke-Builder $invalidPath $previousPath (Join-Path $root 'invalid-output.json') $false

  $missingRoute = Copy-Projection $projection
  $missingRoute.routes = @($missingRoute.routes | Where-Object stableId -ne 'mail:new')
  $missingRoutePath = Join-Path $root 'missing-route.json'; Write-Json $missingRoute $missingRoutePath
  Invoke-Builder $missingRoutePath $previousPath (Join-Path $root 'missing-route-output.json') $false

  $duplicateMessage = Copy-Projection $projection
  $duplicateMessage.messages = @($duplicateMessage.messages + $duplicateMessage.messages[0])
  $duplicateMessage.coverage.inbox.sourceCount++; $duplicateMessage.coverage.inbox.retainedCount++
  $duplicateMessagePath = Join-Path $root 'duplicate-message.json'; Write-Json $duplicateMessage $duplicateMessagePath
  Invoke-Builder $duplicateMessagePath $previousPath (Join-Path $root 'duplicate-message-output.json') $false

  $duplicateEvent = Copy-Projection $projection
  $duplicateEvent.calendarEvents = @($duplicateEvent.calendarEvents + $duplicateEvent.calendarEvents[0])
  $duplicateEvent.coverage.calendar.sourceCount++; $duplicateEvent.coverage.calendar.retainedCount++
  $duplicateEventPath = Join-Path $root 'duplicate-event.json'; Write-Json $duplicateEvent $duplicateEventPath
  Invoke-Builder $duplicateEventPath $previousPath (Join-Path $root 'duplicate-event-output.json') $false

  $duplicateRoute = Copy-Projection $projection
  $duplicateRoute.routes = @($duplicateRoute.routes + $duplicateRoute.routes[0])
  $duplicateRoutePath = Join-Path $root 'duplicate-route.json'; Write-Json $duplicateRoute $duplicateRoutePath
  Invoke-Builder $duplicateRoutePath $previousPath (Join-Path $root 'duplicate-route-output.json') $false

  $wrongWatermark = Copy-Projection $projection
  $wrongWatermark.window.previousWatermark = $watermark.AddSeconds(1).ToString('o')
  $wrongWatermarkPath = Join-Path $root 'wrong-watermark.json'; Write-Json $wrongWatermark $wrongWatermarkPath
  Invoke-Builder $wrongWatermarkPath $previousPath (Join-Path $root 'wrong-watermark-output.json') $false

  $originalOutputBytes = [IO.File]::ReadAllBytes($outputPath)
  Invoke-Builder $projectionPath $previousPath $outputPath $false
  if ([Convert]::ToBase64String($originalOutputBytes) -ne [Convert]::ToBase64String([IO.File]::ReadAllBytes($outputPath))) { throw 'Output collision changed the existing candidate.' }
  if (Test-Path "$outputPath.building") { throw 'Output collision left a temporary candidate.' }

  $promotedProjection = Copy-Projection $projection
  $promotedProjectionPath = Join-Path $root 'promoted-projection.json'; Write-Json $promotedProjection $promotedProjectionPath
  $promotedOutputPath = Join-Path $root 'promoted-output.json'
  $stateDirectory = Join-Path $root 'promoted-state'; New-Item -ItemType Directory -Path $stateDirectory | Out-Null
  $promotedStatePath = Join-Path $stateDirectory 'latest-state.json'
  Invoke-Builder $promotedProjectionPath $previousPath $promotedOutputPath $true $promotedStatePath
  $promotedState = Get-Content -LiteralPath $promotedStatePath -Raw | ConvertFrom-Json
  if ($promotedState.run.runId -ne $promotedProjection.run.runId -or $promotedState.checkpoint.watermark -ne $promotedProjection.window.windowEnd) { throw 'Builder promotion did not advance the authoritative state.' }

  Write-Host 'PASS: portfolio evidence delta builder suite completed.' -ForegroundColor Green
}
finally { Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue }
