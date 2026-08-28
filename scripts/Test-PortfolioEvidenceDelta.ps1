[CmdletBinding()]
param(
  [Parameter(Mandatory = $true, Position = 0)]
  [ValidateNotNullOrEmpty()]
  [string]$Path,

  [Parameter(Mandatory = $true)]
  [ValidateNotNullOrEmpty()]
  [string]$PreviousCheckpointPath,

  [ValidateRange(0.01, 24)]
  [double]$MaxAgeHours = 3,

  [string]$PromoteToCheckpoint,

  [string]$PromoteToState
)

$errors = New-Object System.Collections.Generic.List[string]

function Add-ValidationError([string]$Message) {
  $script:errors.Add($Message)
}

function ConvertTo-DateTimeOffset([object]$Value, [string]$Context) {
  if ([string]$Value -notmatch '^\d{4}-\d{2}-\d{2}T.+(Z|[+-][0-9]{2}:[0-9]{2})$') {
    Add-ValidationError "$Context must be an ISO 8601 date-time with an offset."
    return $null
  }
  try {
    return [DateTimeOffset]::Parse([string]$Value, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::RoundtripKind)
  }
  catch {
    Add-ValidationError "$Context is not a valid date-time."
    return $null
  }
}

function Get-CanonicalCalendarFingerprint([object]$Item, [DateTimeOffset]$Start, [DateTimeOffset]$End) {
  $subject = ''
  $bodyPreview = ''
  if ($Item.privacyMode -eq 'relevant') {
    $subject = [string]$Item.subject
    $bodyPreview = [string]$Item.bodyPreview
  }
  $canonical = [ordered]@{
    stableId    = [string]$Item.stableId
    privacyMode = [string]$Item.privacyMode
    start       = $Start.UtcDateTime.ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ', [Globalization.CultureInfo]::InvariantCulture)
    end         = $End.UtcDateTime.ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ', [Globalization.CultureInfo]::InvariantCulture)
    showAs      = ([string]$Item.showAs).ToLowerInvariant()
    isAllDay    = [bool]$Item.isAllDay
    subject     = $subject
    bodyPreview = $bodyPreview
  }
  $bytes = [Text.Encoding]::UTF8.GetBytes(($canonical | ConvertTo-Json -Compress))
  $sha256 = [Security.Cryptography.SHA256]::Create()
  try { return 'sha256:' + (($sha256.ComputeHash($bytes) | ForEach-Object { $_.ToString('x2') }) -join '') }
  finally { $sha256.Dispose() }
}

function Test-Required([object]$Object, [string[]]$Names, [string]$Context) {
  if ($null -eq $Object) {
    Add-ValidationError "$Context is missing."
    return
  }
  $present = @($Object.PSObject.Properties.Name)
  foreach ($name in $Names) {
    if ($present -notcontains $name) {
      Add-ValidationError "$Context.$name is required."
    }
  }
}

function Test-Allowed([object]$Object, [string[]]$Names, [string]$Context) {
  if ($null -eq $Object) { return }
  foreach ($name in @($Object.PSObject.Properties.Name)) {
    if ($Names -notcontains $name) {
      Add-ValidationError "$Context contains prohibited or unknown field '$name'."
    }
  }
}

function Test-Array([object]$Value, [string]$Context) {
  if ($Value -isnot [System.Array]) {
    Add-ValidationError "$Context must be a JSON array."
    return @()
  }
  if (@($Value | Where-Object { $null -eq $_ }).Count -gt 0) {
    Add-ValidationError "$Context cannot contain null entries."
  }
  return @($Value | Where-Object { $null -ne $_ })
}

function Test-Coverage([object]$Coverage, [string]$Context, [int]$ExpectedCount, [int]$AllowedReconciledCount = 0) {
  $fields = @('complete', 'sourceCount', 'retainedCount')
  Test-Required $Coverage $fields $Context
  Test-Allowed $Coverage $fields $Context
  if ($Coverage.complete -ne $true) { Add-ValidationError "$Context.complete must be true." }
  foreach ($field in @('sourceCount', 'retainedCount')) {
    if ($Coverage.$field -isnot [int] -and $Coverage.$field -isnot [long]) {
      Add-ValidationError "$Context.$field must be a JSON integer."
    }
    elseif ([long]$Coverage.$field -lt 0) {
      Add-ValidationError "$Context.$field cannot be negative."
    }
  }
  if ([long]$Coverage.retainedCount -gt ([long]$Coverage.sourceCount + $AllowedReconciledCount)) {
    Add-ValidationError "$Context.retainedCount cannot exceed sourceCount plus reconciled predecessor removals."
  }
  if ([long]$Coverage.retainedCount -ne $ExpectedCount) {
    Add-ValidationError "$Context.retainedCount does not match the exported item count ($ExpectedCount)."
  }
}

foreach ($requiredPath in @($Path, $PreviousCheckpointPath)) {
  if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
    Write-Error "Required JSON file not found: $requiredPath"
    exit 1
  }
}

try {
  $delta = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
  $previous = Get-Content -LiteralPath $PreviousCheckpointPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
}
catch {
  Write-Error "Evidence delta or predecessor is not valid JSON: $($_.Exception.Message)"
  exit 1
}

$rootFields = @('schemaVersion', 'run', 'window', 'coverage', 'messages', 'calendarChanges', 'drafts', 'tasks', 'threadHeads', 'routes')
Test-Required $delta $rootFields 'delta'
Test-Allowed $delta $rootFields 'delta'
if ($delta.schemaVersion -ne '2.0') { Add-ValidationError "delta.schemaVersion must be '2.0'." }

$runFields = @('runId', 'previousRunId', 'exportedAt', 'status', 'timeZone', 'collector', 'mailboxScope', 'outputPath')
Test-Required $delta.run $runFields 'delta.run'
Test-Allowed $delta.run $runFields 'delta.run'
$runId = [Guid]::Empty
$previousRunId = [Guid]::Empty
if (-not [Guid]::TryParse([string]$delta.run.runId, [ref]$runId)) { Add-ValidationError 'delta.run.runId must be a GUID.' }
if (-not [Guid]::TryParse([string]$delta.run.previousRunId, [ref]$previousRunId)) { Add-ValidationError 'delta.run.previousRunId must be a GUID.' }
if ($runId -eq $previousRunId) { Add-ValidationError 'delta.run.runId must differ from previousRunId.' }
if ([string]$delta.run.previousRunId -ne [string]$previous.run.runId) { Add-ValidationError 'delta.run.previousRunId does not match the predecessor runId.' }
if ($previous.run.status -ne 'complete') { Add-ValidationError 'the predecessor checkpoint is not complete.' }
if ($delta.run.status -ne 'complete') { Add-ValidationError "delta.run.status must be 'complete'." }
if ($delta.run.collector -ne 'Power Automate') { Add-ValidationError "delta.run.collector must be 'Power Automate'." }
if ($delta.run.mailboxScope -ne 'delegated-user') { Add-ValidationError "delta.run.mailboxScope must be 'delegated-user'." }
if ([string]$delta.run.outputPath -notmatch '^/GBS IT docs/\.local/portfolio-control/candidates/portfolio-evidence-delta-\d{8}-\d{6}Z-[0-9a-fA-F-]{36}\.json$') {
  Add-ValidationError 'delta.run.outputPath must use the portfolio candidate path and filename format.'
}
elseif ([IO.Path]::GetFileNameWithoutExtension([string]$delta.run.outputPath) -notlike "*-$($delta.run.runId)") {
  Add-ValidationError 'delta.run.outputPath must end with delta.run.runId.'
}

$exportedAt = ConvertTo-DateTimeOffset $delta.run.exportedAt 'delta.run.exportedAt'
$windowFields = @('previousWatermark', 'windowStart', 'windowEnd', 'overlapMinutes')
Test-Required $delta.window $windowFields 'delta.window'
Test-Allowed $delta.window $windowFields 'delta.window'
$previousWatermark = ConvertTo-DateTimeOffset $delta.window.previousWatermark 'delta.window.previousWatermark'
$windowStart = ConvertTo-DateTimeOffset $delta.window.windowStart 'delta.window.windowStart'
$windowEnd = ConvertTo-DateTimeOffset $delta.window.windowEnd 'delta.window.windowEnd'
$predecessorWatermark = ConvertTo-DateTimeOffset $previous.checkpoint.watermark 'previous.checkpoint.watermark'

if ($delta.window.overlapMinutes -isnot [int] -and $delta.window.overlapMinutes -isnot [long]) {
  Add-ValidationError 'delta.window.overlapMinutes must be a JSON integer.'
}
elseif ([int]$delta.window.overlapMinutes -lt 5 -or [int]$delta.window.overlapMinutes -gt 120) {
  Add-ValidationError 'delta.window.overlapMinutes must be between 5 and 120.'
}
if ($null -ne $previousWatermark -and $null -ne $predecessorWatermark -and $previousWatermark.UtcDateTime -ne $predecessorWatermark.UtcDateTime) {
  Add-ValidationError 'delta.window.previousWatermark does not match the predecessor checkpoint watermark.'
}
if ($null -ne $windowStart -and $null -ne $previousWatermark) {
  $expectedStart = $previousWatermark.AddMinutes( - [int]$delta.window.overlapMinutes)
  if ([Math]::Abs(($windowStart - $expectedStart).TotalSeconds) -gt 1) {
    Add-ValidationError 'delta.window.windowStart must equal previousWatermark minus overlapMinutes.'
  }
}
if ($null -ne $windowEnd -and $null -ne $previousWatermark -and $windowEnd -le $previousWatermark) {
  Add-ValidationError 'delta.window.windowEnd must advance beyond previousWatermark.'
}
if ($null -ne $exportedAt -and $null -ne $windowEnd -and [Math]::Abs(($exportedAt - $windowEnd).TotalMinutes) -gt 5) {
  Add-ValidationError 'delta.run.exportedAt must be within five minutes of windowEnd.'
}
if ($null -ne $exportedAt -and ([DateTimeOffset]::Now - $exportedAt).TotalHours -gt $MaxAgeHours) {
  Add-ValidationError 'delta is stale.'
}

$messages = @(Test-Array $delta.messages 'delta.messages')
$calendarChanges = @(Test-Array $delta.calendarChanges 'delta.calendarChanges')
$drafts = @(Test-Array $delta.drafts 'delta.drafts')
$tasks = @(Test-Array $delta.tasks 'delta.tasks')
$threadHeads = @(Test-Array $delta.threadHeads 'delta.threadHeads')
$routes = @(Test-Array $delta.routes 'delta.routes')

$inboxCount = @($messages | Where-Object { $_.folder -eq 'inbox' }).Count
$sentCount = @($messages | Where-Object { $_.folder -eq 'sentItems' }).Count
Test-Required $delta.coverage @('inbox', 'sentItems', 'calendar', 'drafts', 'tasks') 'delta.coverage'
Test-Allowed $delta.coverage @('inbox', 'sentItems', 'calendar', 'drafts', 'tasks') 'delta.coverage'
Test-Coverage $delta.coverage.inbox 'delta.coverage.inbox' $inboxCount
Test-Coverage $delta.coverage.sentItems 'delta.coverage.sentItems' $sentCount
$cancelledCalendarCount = @($calendarChanges | Where-Object { $_.changeType -eq 'cancelled' }).Count
Test-Coverage $delta.coverage.calendar 'delta.coverage.calendar' $calendarChanges.Count $cancelledCalendarCount
Test-Coverage $delta.coverage.drafts 'delta.coverage.drafts' $drafts.Count
Test-Coverage $delta.coverage.tasks 'delta.coverage.tasks' $tasks.Count

$evidenceIds = New-Object System.Collections.Generic.List[string]
for ($index = 0; $index -lt $messages.Count; $index++) {
  $item = $messages[$index]
  $context = "delta.messages[$index]"
  $fields = @('stableId', 'folder', 'occurredAt', 'subject', 'counterparty', 'bodyPreview', 'conversationId', 'importance')
  Test-Required $item $fields $context
  Test-Allowed $item $fields $context
  if ([string]$item.stableId -notmatch '^mail:.+') { Add-ValidationError "$context.stableId must start with mail:." }
  if (@('inbox', 'sentItems') -notcontains [string]$item.folder) { Add-ValidationError "$context.folder is invalid." }
  if ([string]$item.bodyPreview -and ([string]$item.bodyPreview).Length -gt 2000) { Add-ValidationError "$context.bodyPreview exceeds 2000 characters." }
  ConvertTo-DateTimeOffset $item.occurredAt "$context.occurredAt" | Out-Null
  $evidenceIds.Add([string]$item.stableId)
}

for ($index = 0; $index -lt $calendarChanges.Count; $index++) {
  $item = $calendarChanges[$index]
  $context = "delta.calendarChanges[$index]"
  $baseFields = @('stableId', 'fingerprint', 'changeType', 'privacyMode', 'start', 'end', 'showAs', 'isAllDay')
  $allowed = $baseFields + @('subject', 'bodyPreview')
  Test-Required $item $baseFields $context
  Test-Allowed $item $allowed $context
  if ([string]$item.stableId -notmatch '^event:.+') { Add-ValidationError "$context.stableId must start with event:." }
  if ([string]$item.fingerprint -notmatch '^sha256:[0-9a-f]{64}$') { Add-ValidationError "$context.fingerprint must be lowercase sha256 followed by 64 hexadecimal characters." }
  if ($item.isAllDay -isnot [bool]) { Add-ValidationError "$context.isAllDay must be boolean." }
  if ($item.privacyMode -eq 'busyOnly' -and @($item.PSObject.Properties.Name | Where-Object { @('subject', 'bodyPreview') -contains $_ }).Count -gt 0) {
    Add-ValidationError "$context busyOnly events cannot expose subject or bodyPreview."
  }
  if ($item.privacyMode -eq 'relevant' -and [string]::IsNullOrWhiteSpace([string]$item.subject)) {
    Add-ValidationError "$context relevant events require subject."
  }
  $start = ConvertTo-DateTimeOffset $item.start "$context.start"
  $end = ConvertTo-DateTimeOffset $item.end "$context.end"
  if ($null -ne $start -and $null -ne $end -and $end -le $start) { Add-ValidationError "$context.end must be after start." }
  if ($null -ne $start -and $null -ne $end) {
    $expectedFingerprint = Get-CanonicalCalendarFingerprint $item $start $end
    if ([string]$item.fingerprint -cne $expectedFingerprint) { Add-ValidationError "$context.fingerprint does not match the canonical privacy-minimized event representation." }
  }
  $evidenceIds.Add([string]$item.stableId)
}

foreach ($collection in @(@{ Items = $drafts; Prefix = 'draft:'; Name = 'drafts' }, @{ Items = $tasks; Prefix = 'task:'; Name = 'tasks' })) {
  for ($index = 0; $index -lt $collection.Items.Count; $index++) {
    $item = $collection.Items[$index]
    $context = "delta.$($collection.Name)[$index]"
    if ([string]$item.stableId -notlike "$($collection.Prefix)*") { Add-ValidationError "$context.stableId must start with $($collection.Prefix)." }
    if ($item.PSObject.Properties.Name -contains 'body' -or $item.PSObject.Properties.Name -contains 'recipients' -or $item.PSObject.Properties.Name -contains 'attachmentNames') {
      Add-ValidationError "$context contains prohibited content-bearing metadata."
    }
    $evidenceIds.Add([string]$item.stableId)
  }
}

$evidenceIdArray = @($evidenceIds.ToArray())
foreach ($duplicate in @($evidenceIdArray | Group-Object | Where-Object { -not [string]::IsNullOrWhiteSpace($_.Name) -and $_.Count -gt 1 })) {
  Add-ValidationError "stableId '$($duplicate.Name)' occurs $($duplicate.Count) times."
}

$messageById = @{}
foreach ($message in $messages) { $messageById[[string]$message.stableId] = $message }
for ($index = 0; $index -lt $threadHeads.Count; $index++) {
  $head = $threadHeads[$index]
  $context = "delta.threadHeads[$index]"
  Test-Required $head @('conversationId', 'previousHeadId', 'currentHeadId', 'changeType') $context
  Test-Allowed $head @('conversationId', 'previousHeadId', 'currentHeadId', 'changeType') $context
  if ([string]::IsNullOrWhiteSpace([string]$head.conversationId)) { Add-ValidationError "$context.conversationId cannot be empty." }
  if ([string]$head.currentHeadId -notmatch '^mail:.+') { Add-ValidationError "$context.currentHeadId must start with mail:." }
  $headMessage = $messageById[[string]$head.currentHeadId]
  if ($null -eq $headMessage) { Add-ValidationError "thread head '$($head.currentHeadId)' is not present in delta.messages." }
  elseif ([string]$headMessage.conversationId -ne [string]$head.conversationId) { Add-ValidationError "$context.conversationId does not match its current-head message." }
  if ($head.changeType -eq 'advanced' -and [string]::IsNullOrWhiteSpace([string]$head.previousHeadId)) { Add-ValidationError 'advanced thread heads require previousHeadId.' }
  if ($head.changeType -eq 'advanced' -and [string]$head.previousHeadId -eq [string]$head.currentHeadId) { Add-ValidationError 'advanced thread heads must advance to a different currentHeadId.' }
  if ($head.changeType -eq 'new' -and $null -ne $head.previousHeadId -and -not [string]::IsNullOrWhiteSpace([string]$head.previousHeadId)) { Add-ValidationError 'new thread heads cannot have previousHeadId.' }
  if (@('new', 'advanced') -notcontains [string]$head.changeType) { Add-ValidationError "$context.changeType is invalid." }
}
foreach ($duplicate in @($threadHeads | Group-Object conversationId | Where-Object { -not [string]::IsNullOrWhiteSpace($_.Name) -and $_.Count -gt 1 })) { Add-ValidationError "conversationId '$($duplicate.Name)' occurs $($duplicate.Count) times in threadHeads." }

$routeIds = @($routes | ForEach-Object { [string]$_.stableId })
Write-Verbose "Evidence IDs: $($evidenceIdArray -join ', ')"
Write-Verbose "Route IDs: $($routeIds -join ', ')"
foreach ($evidenceId in $evidenceIds) {
  if (@($routeIds | Where-Object { $_ -eq $evidenceId }).Count -ne 1) { Add-ValidationError "evidence '$evidenceId' must have exactly one route record." }
}
foreach ($route in $routes) {
  if ($evidenceIdArray -notcontains [string]$route.stableId) { Add-ValidationError "route '$($route.stableId)' does not reference collected evidence." }
  $projects = @($route.projects)
  if ($route.disposition -eq 'routed' -and $projects.Count -ne 1) { Add-ValidationError "routed evidence '$($route.stableId)' must have exactly one project." }
  if ($route.disposition -eq 'ambiguous' -and $projects.Count -lt 2) { Add-ValidationError "ambiguous evidence '$($route.stableId)' must have at least two projects." }
  if ($route.disposition -eq 'unmatched' -and $projects.Count -ne 0) { Add-ValidationError "unmatched evidence '$($route.stableId)' cannot name a project." }
  if (@($route.reasonCodes).Count -lt 1) { Add-ValidationError "route '$($route.stableId)' requires a reason code." }
}

if ($errors.Count -gt 0) {
  Write-Host "Portfolio evidence delta validation FAILED ($($errors.Count) error(s)):" -ForegroundColor Red
  foreach ($validationError in $errors) { Write-Host " - $validationError" -ForegroundColor Red }
  exit 1
}

Write-Host ("Portfolio evidence delta validation PASSED: {0} message(s), {1} calendar change(s), {2} draft(s), {3} task(s)." -f $messages.Count, $calendarChanges.Count, $drafts.Count, $tasks.Count) -ForegroundColor Green

if (-not [string]::IsNullOrWhiteSpace($PromoteToCheckpoint)) {
  Write-Error 'Independent checkpoint promotion is disabled. Use -PromoteToState so checkpoint and comparison state advance together.'
  exit 1
}

if (-not [string]::IsNullOrWhiteSpace($PromoteToState)) {
  $promoter = Join-Path $PSScriptRoot 'Promote-PortfolioControlState.ps1'
  & powershell -NoProfile -File $promoter -DeltaPath $Path -PreviousStatePath $PreviousCheckpointPath -PromoteToState $PromoteToState
  if ($LASTEXITCODE -ne 0) { exit 1 }
}

exit 0
