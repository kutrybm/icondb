[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [ValidateNotNullOrEmpty()]
  [string]$ProjectionPath,

  [Parameter(Mandatory = $true)]
  [ValidateNotNullOrEmpty()]
  [string]$PreviousStatePath,

  [Parameter(Mandatory = $true)]
  [ValidateNotNullOrEmpty()]
  [string]$OutputPath,

  [ValidateRange(0.01, 24)]
  [double]$MaxAgeHours = 3,

  [string]$PromoteToState
)

$ErrorActionPreference = 'Stop'
$deltaValidator = Join-Path $PSScriptRoot 'Test-PortfolioEvidenceDelta.ps1'

function Assert-Required([object]$Object, [string[]]$Names, [string]$Context) {
  if ($null -eq $Object) { throw "$Context is missing." }
  $present = @($Object.PSObject.Properties.Name)
  foreach ($name in $Names) {
    if ($present -notcontains $name) { throw "$Context.$name is required." }
  }
}

function Assert-Allowed([object]$Object, [string[]]$Names, [string]$Context) {
  foreach ($name in @($Object.PSObject.Properties.Name)) {
    if ($Names -notcontains $name) { throw "$Context contains prohibited or unknown field '$name'." }
  }
}

function ConvertTo-Offset([object]$Value, [string]$Context) {
  try { return [DateTimeOffset]::Parse([string]$Value, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::RoundtripKind) }
  catch { throw "$Context is not a valid ISO 8601 date-time." }
}

function Get-CalendarFingerprint([object]$Item) {
  $start = ConvertTo-Offset $Item.start 'calendar event start'
  $end = ConvertTo-Offset $Item.end 'calendar event end'
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
  try {
    $bytes = [Text.Encoding]::UTF8.GetBytes(($canonical | ConvertTo-Json -Compress))
    return 'sha256:' + (($sha256.ComputeHash($bytes) | ForEach-Object { $_.ToString('x2') }) -join '')
  }
  finally { $sha256.Dispose() }
}

function Copy-CalendarChange([object]$Item, [string]$Fingerprint, [string]$ChangeType) {
  $change = [ordered]@{
    stableId    = [string]$Item.stableId
    fingerprint = $Fingerprint
    changeType  = $ChangeType
    privacyMode = [string]$Item.privacyMode
    start       = [string]$Item.start
    end         = [string]$Item.end
    showAs      = ([string]$Item.showAs).ToLowerInvariant()
    isAllDay    = [bool]$Item.isAllDay
  }
  if ($Item.privacyMode -eq 'relevant') {
    $change.subject = [string]$Item.subject
    $change.bodyPreview = [string]$Item.bodyPreview
  }
  return $change
}

foreach ($requiredPath in @($ProjectionPath, $PreviousStatePath, $deltaValidator)) {
  if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) { Write-Error "Required file not found: $requiredPath"; exit 1 }
}

try {
  $projection = Get-Content -LiteralPath $ProjectionPath -Raw | ConvertFrom-Json -ErrorAction Stop
  $previous = Get-Content -LiteralPath $PreviousStatePath -Raw | ConvertFrom-Json -ErrorAction Stop

  $rootFields = @('schemaVersion', 'run', 'window', 'coverage', 'messages', 'calendarEvents', 'drafts', 'tasks', 'routes')
  Assert-Required $projection $rootFields 'projection'
  Assert-Allowed $projection $rootFields 'projection'
  if ($projection.schemaVersion -ne '1.0') { throw "projection.schemaVersion must be '1.0'." }

  Assert-Required $projection.run @('runId', 'exportedAt', 'timeZone', 'candidatePath') 'projection.run'
  Assert-Allowed $projection.run @('runId', 'exportedAt', 'timeZone', 'candidatePath') 'projection.run'
  $runId = [Guid]::Empty
  if (-not [Guid]::TryParse([string]$projection.run.runId, [ref]$runId)) { throw 'projection.run.runId must be a GUID.' }
  if ([string]$projection.run.runId -eq [string]$previous.run.runId) { throw 'projection runId must differ from the predecessor runId.' }

  $windowFields = @('previousWatermark', 'windowStart', 'windowEnd', 'overlapMinutes', 'calendarStart', 'calendarEnd')
  Assert-Required $projection.window $windowFields 'projection.window'
  Assert-Allowed $projection.window $windowFields 'projection.window'
  $previousWatermark = ConvertTo-Offset $projection.window.previousWatermark 'projection.window.previousWatermark'
  $predecessorWatermark = ConvertTo-Offset $previous.checkpoint.watermark 'previous.checkpoint.watermark'
  if ($previousWatermark.UtcDateTime -ne $predecessorWatermark.UtcDateTime) { throw 'Projection watermark does not match predecessor state.' }
  $calendarStart = ConvertTo-Offset $projection.window.calendarStart 'projection.window.calendarStart'
  $calendarEnd = ConvertTo-Offset $projection.window.calendarEnd 'projection.window.calendarEnd'
  if ($calendarEnd -le $calendarStart) { throw 'Projection calendarEnd must be after calendarStart.' }

  foreach ($name in @('inbox', 'sentItems', 'calendar', 'drafts', 'tasks')) {
    $coverage = $projection.coverage.$name
    Assert-Required $coverage @('complete', 'sourceCount', 'retainedCount') "projection.coverage.$name"
    Assert-Allowed $coverage @('complete', 'sourceCount', 'retainedCount') "projection.coverage.$name"
    if ($coverage.complete -ne $true) { throw "projection.coverage.$name.complete must be true." }
  }

  $messages = @($projection.messages)
  $calendarEvents = @($projection.calendarEvents)
  $drafts = @($projection.drafts)
  $tasks = @($projection.tasks)
  $inputRoutes = @($projection.routes)

  foreach ($duplicate in @($messages | Group-Object stableId | Where-Object Count -gt 1)) { throw "Duplicate message stableId '$($duplicate.Name)'." }
  foreach ($duplicate in @($calendarEvents | Group-Object stableId | Where-Object Count -gt 1)) { throw "Duplicate calendar stableId '$($duplicate.Name)'." }
  foreach ($duplicate in @($inputRoutes | Group-Object stableId | Where-Object Count -gt 1)) { throw "Duplicate route stableId '$($duplicate.Name)'." }

  $threadMap = @{}
  foreach ($item in @($previous.threadHeads)) { if ($null -ne $item) { $threadMap[[string]$item.conversationId] = $item } }
  $threadHeads = @()
  foreach ($group in @($messages | Group-Object conversationId)) {
    if ([string]::IsNullOrWhiteSpace([string]$group.Name)) { throw 'Every message requires a conversationId.' }
    $selected = @($group.Group | Sort-Object @{ Expression = { ConvertTo-Offset $_.occurredAt 'message occurredAt' }; Descending = $true }, @{ Expression = { [string]$_.stableId }; Descending = $true })[0]
    $existing = $threadMap[[string]$group.Name]
    if ($null -eq $existing) {
      $threadHeads += [ordered]@{ conversationId = [string]$group.Name; previousHeadId = $null; currentHeadId = [string]$selected.stableId; changeType = 'new' }
    }
    elseif ([string]$existing.currentHeadId -ne [string]$selected.stableId -and (ConvertTo-Offset $selected.occurredAt 'message occurredAt') -gt $previousWatermark) {
      $threadHeads += [ordered]@{ conversationId = [string]$group.Name; previousHeadId = [string]$existing.currentHeadId; currentHeadId = [string]$selected.stableId; changeType = 'advanced' }
    }
  }

  $previousCalendar = @{}
  foreach ($item in @($previous.calendarFingerprints)) { if ($null -ne $item) { $previousCalendar[[string]$item.stableId] = $item } }
  $currentCalendarIds = @{}
  $calendarChanges = @()
  foreach ($item in $calendarEvents) {
    $fields = @('stableId', 'privacyMode', 'start', 'end', 'showAs', 'isAllDay')
    Assert-Required $item $fields 'projection calendar event'
    Assert-Allowed $item ($fields + @('subject', 'bodyPreview')) 'projection calendar event'
    if ([string]$item.stableId -notmatch '^event:.+') { throw "Calendar stableId '$($item.stableId)' must start with event:." }
    if ($item.isAllDay -isnot [bool]) { throw "Calendar event '$($item.stableId)' isAllDay must be boolean." }
    if ($item.privacyMode -eq 'busyOnly' -and @($item.PSObject.Properties.Name | Where-Object { @('subject', 'bodyPreview') -contains $_ }).Count -gt 0) { throw "Busy-only event '$($item.stableId)' contains private detail fields." }
    if ($item.privacyMode -eq 'relevant' -and [string]::IsNullOrWhiteSpace([string]$item.subject)) { throw "Relevant event '$($item.stableId)' requires subject." }
    $fingerprint = Get-CalendarFingerprint $item
    $currentCalendarIds[[string]$item.stableId] = $true
    $existing = $previousCalendar[[string]$item.stableId]
    if ($null -eq $existing) { $calendarChanges += Copy-CalendarChange $item $fingerprint 'added' }
    elseif ([string]$existing.fingerprint -cne $fingerprint -or [string]$existing.changeType -eq 'cancelled') { $calendarChanges += Copy-CalendarChange $item $fingerprint 'updated' }
  }

  foreach ($existing in @($previous.calendarFingerprints)) {
    if ($null -eq $existing -or [string]$existing.changeType -eq 'cancelled' -or $currentCalendarIds.ContainsKey([string]$existing.stableId)) { continue }
    $start = ConvertTo-Offset $existing.start 'previous calendar start'
    if ($start -ge $calendarStart -and $start -lt $calendarEnd) {
      $calendarChanges += Copy-CalendarChange $existing ([string]$existing.fingerprint) 'cancelled'
    }
  }

  $emittedIds = @(@($messages) + @($calendarChanges) + @($drafts) + @($tasks) | ForEach-Object { [string]$_.stableId })
  $routeMap = @{}
  foreach ($route in $inputRoutes) { $routeMap[[string]$route.stableId] = $route }
  $routes = @()
  foreach ($stableId in $emittedIds) {
    if ($routeMap.ContainsKey([string]$stableId)) { $routes += $routeMap[[string]$stableId] }
    elseif ([string]$stableId -like 'event:*' -and @($calendarChanges | Where-Object { $_.stableId -eq $stableId -and $_.changeType -eq 'cancelled' }).Count -eq 1) {
      $routes += [ordered]@{ stableId = [string]$stableId; projects = @(); disposition = 'unmatched'; reasonCodes = @('cancelled-from-predecessor-state') }
    }
    else { throw "No route was supplied for emitted evidence '$stableId'." }
  }

  $coverage = $projection.coverage | ConvertTo-Json -Depth 5 | ConvertFrom-Json
  $coverage.calendar.retainedCount = [int]$calendarChanges.Count
  $delta = [ordered]@{
    schemaVersion = '2.0'
    run = [ordered]@{
      runId = [string]$projection.run.runId; previousRunId = [string]$previous.run.runId; exportedAt = [string]$projection.run.exportedAt
      status = 'complete'; timeZone = [string]$projection.run.timeZone; collector = 'Power Automate'; mailboxScope = 'delegated-user'; outputPath = [string]$projection.run.candidatePath
    }
    window = [ordered]@{
      previousWatermark = [string]$projection.window.previousWatermark; windowStart = [string]$projection.window.windowStart
      windowEnd = [string]$projection.window.windowEnd; overlapMinutes = [int]$projection.window.overlapMinutes
    }
    coverage = $coverage
    messages = $messages
    calendarChanges = @($calendarChanges | Sort-Object stableId)
    drafts = $drafts
    tasks = $tasks
    threadHeads = @($threadHeads | Sort-Object conversationId)
    routes = @($routes | Sort-Object stableId)
  }

  $targetPath = [IO.Path]::GetFullPath($OutputPath)
  $targetDirectory = [IO.Path]::GetDirectoryName($targetPath)
  if (-not [IO.Directory]::Exists($targetDirectory)) { [IO.Directory]::CreateDirectory($targetDirectory) | Out-Null }
  $temporaryPath = "$targetPath.building"
  $delta | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $temporaryPath -Encoding UTF8
  & powershell -NoProfile -File $deltaValidator -Path $temporaryPath -PreviousCheckpointPath $PreviousStatePath -MaxAgeHours $MaxAgeHours
  if ($LASTEXITCODE -ne 0) { throw 'Generated evidence delta failed validation.' }
  if ([IO.File]::Exists($targetPath)) { throw "Output already exists: $targetPath" }
  [IO.File]::Move($temporaryPath, $targetPath)

  if (-not [string]::IsNullOrWhiteSpace($PromoteToState)) {
    & powershell -NoProfile -File $deltaValidator -Path $targetPath -PreviousCheckpointPath $PreviousStatePath -MaxAgeHours $MaxAgeHours -PromoteToState $PromoteToState
    if ($LASTEXITCODE -ne 0) { throw 'Generated evidence delta was not promoted.' }
  }
  Write-Host "Built validated portfolio evidence delta: $targetPath" -ForegroundColor Green
}
catch {
  if ($null -ne $temporaryPath) { Remove-Item -LiteralPath $temporaryPath -Force -ErrorAction SilentlyContinue }
  Write-Error "Portfolio evidence delta build failed: $($_.Exception.Message)"
  exit 1
}

exit 0
