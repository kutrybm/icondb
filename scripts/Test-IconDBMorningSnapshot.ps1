[CmdletBinding()]
param(
  [Parameter(Mandatory = $true, Position = 0)]
  [ValidateNotNullOrEmpty()]
  [string]$Path,

  [ValidateRange(0.01, 8760)]
  [double]$MaxAgeHours = 26,

  [string]$PromoteToLatest
)

$errors = New-Object System.Collections.Generic.List[string]

function Add-ValidationError {
  param([string]$Message)
  $script:errors.Add($Message)
}

function Test-RequiredProperties {
  param(
    [object]$Object,
    [string[]]$Names,
    [string]$Context
  )

  if ($null -eq $Object) {
    Add-ValidationError "$Context is missing."
    return $false
  }

  $present = @($Object.PSObject.Properties.Name)
  $valid = $true
  foreach ($name in $Names) {
    if ($present -notcontains $name) {
      Add-ValidationError "$Context.$name is required."
      $valid = $false
    }
  }
  return $valid
}

function Test-AllowedProperties {
  param(
    [object]$Object,
    [string[]]$Names,
    [string]$Context
  )

  foreach ($name in @($Object.PSObject.Properties.Name)) {
    if ($Names -notcontains $name) {
      Add-ValidationError "$Context contains prohibited or unknown field '$name'."
    }
  }
}

function ConvertTo-RequiredDateTimeOffset {
  param(
    [object]$Value,
    [string]$Context
  )

  if ([string]::IsNullOrWhiteSpace([string]$Value)) {
    Add-ValidationError "$Context must be a non-empty ISO 8601 date-time."
    return $null
  }

  if ([string]$Value -notmatch '^\d{4}-\d{2}-\d{2}T.+(Z|[+-][0-9]{2}:[0-9]{2})$') {
    Add-ValidationError "$Context must include a UTC Z suffix or numeric offset."
    return $null
  }

  try {
    return [DateTimeOffset]::Parse(
      [string]$Value,
      [Globalization.CultureInfo]::InvariantCulture,
      [Globalization.DateTimeStyles]::RoundtripKind
    )
  }
  catch {
    Add-ValidationError "$Context is not a valid ISO 8601 date-time: '$Value'."
    return $null
  }
}

function Test-NonEmptyString {
  param(
    [object]$Value,
    [string]$Context
  )

  if ($Value -isnot [string]) {
    Add-ValidationError "$Context must be a string."
  }
  elseif ([string]::IsNullOrWhiteSpace([string]$Value)) {
    Add-ValidationError "$Context must be a non-empty string."
  }
}

function Test-IntegerValue {
  param([object]$Value)
  return ($Value -is [byte] -or $Value -is [int16] -or $Value -is [int32] -or $Value -is [int64])
}

function Test-PageSet {
  param(
    [object]$PageSet,
    [string]$Context,
    [int]$ExpectedItemCount,
    [int]$MaxPageSize
  )

  $required = @('complete', 'hasMore', 'sourceRetrievedCount', 'retrievedCount', 'pageCount', 'pageSize', 'pages')
  if (-not (Test-RequiredProperties $PageSet $required $Context)) {
    return
  }
  Test-AllowedProperties $PageSet $required $Context

  if ($PageSet.complete -ne $true) {
    Add-ValidationError "$Context.complete must be true."
  }
  if ($PageSet.complete -isnot [bool]) {
    Add-ValidationError "$Context.complete must be boolean."
  }
  if ($PageSet.hasMore -ne $false) {
    Add-ValidationError "$Context.hasMore must be false; partial exports fail closed."
  }
  if ($PageSet.hasMore -isnot [bool]) {
    Add-ValidationError "$Context.hasMore must be boolean."
  }

  $pageSize = 0
  $sourceRetrievedCount = 0
  $retrievedCount = 0
  $pageCount = 0
  foreach ($integerField in @('pageSize', 'sourceRetrievedCount', 'retrievedCount', 'pageCount')) {
    if (-not (Test-IntegerValue $PageSet.$integerField)) {
      Add-ValidationError "$Context.$integerField must be a JSON integer."
    }
  }
  try { $pageSize = [int]$PageSet.pageSize } catch { Add-ValidationError "$Context.pageSize must be an integer." }
  try { $sourceRetrievedCount = [int]$PageSet.sourceRetrievedCount } catch { Add-ValidationError "$Context.sourceRetrievedCount must be an integer." }
  try { $retrievedCount = [int]$PageSet.retrievedCount } catch { Add-ValidationError "$Context.retrievedCount must be an integer." }
  try { $pageCount = [int]$PageSet.pageCount } catch { Add-ValidationError "$Context.pageCount must be an integer." }

  if ($pageSize -lt 1 -or $pageSize -gt $MaxPageSize) {
    Add-ValidationError "$Context.pageSize must be between 1 and $MaxPageSize."
  }
  if ($sourceRetrievedCount -lt 0 -or $retrievedCount -lt 0) {
    Add-ValidationError "$Context.retrievedCount cannot be negative."
  }

  if ($PageSet.pages -isnot [System.Array]) {
    Add-ValidationError "$Context.pages must be a JSON array."
    return
  }
  if (@($PageSet.pages | Where-Object { $null -eq $_ }).Count -gt 0) {
    Add-ValidationError "$Context.pages cannot contain null entries."
    return
  }
  $pages = @($PageSet.pages)
  if ($pages.Count -lt 1) {
    Add-ValidationError "$Context.pages must contain at least one page, including for a zero-item result."
    return
  }
  if ($pageCount -ne $pages.Count) {
    Add-ValidationError "$Context.pageCount ($pageCount) does not match pages.Count ($($pages.Count))."
  }

  $runningSourceCount = 0
  $runningRetainedCount = 0
  for ($index = 0; $index -lt $pages.Count; $index++) {
    $page = $pages[$index]
    $pageContext = "$Context.pages[$index]"
    $pageRequired = @('pageNumber', 'skipCount', 'sourceItemCount', 'itemCount')
    if (-not (Test-RequiredProperties $page $pageRequired $pageContext)) {
      continue
    }
    Test-AllowedProperties $page $pageRequired $pageContext

    $pageNumber = 0
    $skipCount = -1
    $sourceItemCount = -1
    $itemCount = -1
    foreach ($integerField in $pageRequired) {
      if (-not (Test-IntegerValue $page.$integerField)) {
        Add-ValidationError "$pageContext.$integerField must be a JSON integer."
      }
    }
    try { $pageNumber = [int]$page.pageNumber } catch { Add-ValidationError "$pageContext.pageNumber must be an integer." }
    try { $skipCount = [int]$page.skipCount } catch { Add-ValidationError "$pageContext.skipCount must be an integer." }
    try { $sourceItemCount = [int]$page.sourceItemCount } catch { Add-ValidationError "$pageContext.sourceItemCount must be an integer." }
    try { $itemCount = [int]$page.itemCount } catch { Add-ValidationError "$pageContext.itemCount must be an integer." }

    if ($pageNumber -ne ($index + 1)) {
      Add-ValidationError "$pageContext.pageNumber must be $($index + 1)."
    }
    if ($skipCount -ne $runningSourceCount) {
      Add-ValidationError "$pageContext.skipCount must be $runningSourceCount for contiguous paging."
    }
    if ($sourceItemCount -lt 0 -or $sourceItemCount -gt $pageSize -or $sourceItemCount -gt $MaxPageSize) {
      Add-ValidationError "$pageContext.sourceItemCount must be between 0 and the configured page size (maximum $MaxPageSize)."
    }
    if ($itemCount -lt 0 -or $itemCount -gt $sourceItemCount) {
      Add-ValidationError "$pageContext.itemCount must be between 0 and sourceItemCount."
    }
    if ($index -lt ($pages.Count - 1) -and $sourceItemCount -ne $pageSize) {
      Add-ValidationError "$pageContext is not full even though another page follows; paging may be incomplete."
    }
    if ($sourceItemCount -ge 0) {
      $runningSourceCount += $sourceItemCount
    }
    if ($itemCount -ge 0) {
      $runningRetainedCount += $itemCount
    }
  }

  if ($sourceRetrievedCount -ne $runningSourceCount) {
    Add-ValidationError "$Context.sourceRetrievedCount ($sourceRetrievedCount) does not match the source page item total ($runningSourceCount)."
  }
  if ($retrievedCount -ne $runningRetainedCount) {
    Add-ValidationError "$Context.retrievedCount ($retrievedCount) does not match the retained page item total ($runningRetainedCount)."
  }
  if ($retrievedCount -ne $ExpectedItemCount) {
    Add-ValidationError "$Context.retrievedCount ($retrievedCount) does not match the exported array count ($ExpectedItemCount)."
  }
  if ($pages[-1].sourceItemCount -ge $pageSize) {
    Add-ValidationError "$Context final page does not prove exhaustion below the connector limit."
  }
  if ($Context -eq 'snapshot.paging.mail' -and $pages.Count -ne 1) {
    Add-ValidationError 'snapshot.paging.mail must contain exactly one page.'
  }
  if ($Context -eq 'snapshot.paging.mail' -and $pageSize -ne 1000) {
    Add-ValidationError 'snapshot.paging.mail.pageSize must be 1000.'
  }
  if ($Context -eq 'snapshot.paging.calendar') {
    if ($pageSize -ne 256) {
      Add-ValidationError 'snapshot.paging.calendar.pageSize must be 256.'
    }
    if ($pages.Count -gt 100) {
      Add-ValidationError 'snapshot.paging.calendar exceeds the flow loop limit of 100 pages.'
    }
  }
}

if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
  Write-Error "Snapshot file not found: $Path"
  exit 1
}

try {
  $snapshot = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
}
catch {
  Write-Error "Snapshot is not valid JSON: $($_.Exception.Message)"
  exit 1
}

$rootRequired = @('schemaVersion', 'run', 'calendarWindow', 'paging', 'messages', 'events')
Test-RequiredProperties $snapshot $rootRequired 'snapshot' | Out-Null
Test-AllowedProperties $snapshot $rootRequired 'snapshot'

if ($snapshot.schemaVersion -ne '1.0') {
  Add-ValidationError "snapshot.schemaVersion must be '1.0'."
}

$runRequired = @('runId', 'exportedAt', 'status', 'timeZone', 'collector', 'mailboxScope', 'outputPath')
if (Test-RequiredProperties $snapshot.run $runRequired 'snapshot.run') {
  Test-AllowedProperties $snapshot.run $runRequired 'snapshot.run'
  Test-NonEmptyString $snapshot.run.runId 'snapshot.run.runId'
  $parsedRunId = [Guid]::Empty
  if (-not [Guid]::TryParse([string]$snapshot.run.runId, [ref]$parsedRunId)) {
    Add-ValidationError 'snapshot.run.runId must be a GUID.'
  }
  Test-NonEmptyString $snapshot.run.timeZone 'snapshot.run.timeZone'
  if ($snapshot.run.status -ne 'complete') { Add-ValidationError "snapshot.run.status must be 'complete'." }
  if ($snapshot.run.collector -ne 'Power Automate') { Add-ValidationError "snapshot.run.collector must be 'Power Automate'." }
  if ($snapshot.run.mailboxScope -ne 'delegated-user') { Add-ValidationError "snapshot.run.mailboxScope must be 'delegated-user'." }
  if ([string]$snapshot.run.outputPath -notmatch '^/GBS IT docs/icondb/\.local/power-automate/[^/\\]+\.json$') {
    Add-ValidationError "snapshot.run.outputPath must name one JSON file directly beneath /GBS IT docs/icondb/.local/power-automate/."
  }
  $claimedFileName = [IO.Path]::GetFileName([string]$snapshot.run.outputPath)
  if ($claimedFileName -notmatch '^icondb-morning-\d{8}-\d{6}Z-[0-9a-fA-F-]{36}\.json$') {
    Add-ValidationError 'snapshot.run.outputPath must use the dated IconDB candidate filename format.'
  }
  elseif ($claimedFileName -notlike "*-$($snapshot.run.runId).json") {
    Add-ValidationError 'snapshot.run.outputPath filename must end with the runId.'
  }
  $actualFileName = [IO.Path]::GetFileName($Path)
  if ($actualFileName -ne 'latest.json' -and $actualFileName -ne $claimedFileName) {
    Add-ValidationError 'the validated candidate filename does not match snapshot.run.outputPath.'
  }
}

$exportedAt = ConvertTo-RequiredDateTimeOffset $snapshot.run.exportedAt 'snapshot.run.exportedAt'
if ($null -ne $exportedAt) {
  $expectedTimestamp = $exportedAt.UtcDateTime.ToString('yyyyMMdd-HHmmss') + 'Z'
  if ($claimedFileName -notlike "icondb-morning-$expectedTimestamp-*.json") {
    Add-ValidationError 'snapshot.run.outputPath filename timestamp must match run.exportedAt in UTC.'
  }
  $now = [DateTimeOffset]::Now
  if ($exportedAt -gt $now.AddMinutes(5)) {
    Add-ValidationError 'snapshot.run.exportedAt is more than five minutes in the future.'
  }
  elseif (($now - $exportedAt).TotalHours -gt $MaxAgeHours) {
    Add-ValidationError ("snapshot is stale: age {0:N2} hours exceeds MaxAgeHours {1:N2}." -f (($now - $exportedAt).TotalHours), $MaxAgeHours)
  }
  if ([TimeZoneInfo]::ConvertTime($exportedAt, [TimeZoneInfo]::Local).Date -ne $now.Date) {
    Add-ValidationError 'snapshot.run.exportedAt must be today in the local time zone.'
  }
}

$windowRequired = @('start', 'end', 'maxDays')
if (Test-RequiredProperties $snapshot.calendarWindow $windowRequired 'snapshot.calendarWindow') {
  Test-AllowedProperties $snapshot.calendarWindow $windowRequired 'snapshot.calendarWindow'
  if (-not (Test-IntegerValue $snapshot.calendarWindow.maxDays)) {
    Add-ValidationError 'snapshot.calendarWindow.maxDays must be a JSON integer.'
  }
  elseif ([int]$snapshot.calendarWindow.maxDays -ne 42) {
    Add-ValidationError 'snapshot.calendarWindow.maxDays must be 42.'
  }
}
$windowStart = ConvertTo-RequiredDateTimeOffset $snapshot.calendarWindow.start 'snapshot.calendarWindow.start'
$windowEnd = ConvertTo-RequiredDateTimeOffset $snapshot.calendarWindow.end 'snapshot.calendarWindow.end'
if ($null -ne $windowStart -and $null -ne $windowEnd) {
  if ($null -ne $exportedAt -and $windowStart.UtcDateTime -ne $exportedAt.UtcDateTime) {
    Add-ValidationError 'snapshot.calendarWindow.start must equal snapshot.run.exportedAt.'
  }
  if ($windowEnd -le $windowStart) {
    Add-ValidationError 'snapshot.calendarWindow.end must be after start.'
  }
  elseif (($windowEnd - $windowStart).TotalDays -gt 42) {
    Add-ValidationError ("calendar horizon is {0:N2} days; maximum is 42." -f (($windowEnd - $windowStart).TotalDays))
  }
}

if ($snapshot.messages -isnot [System.Array]) {
  Add-ValidationError 'snapshot.messages must be a JSON array.'
  $messages = @()
}
elseif (@($snapshot.messages | Where-Object { $null -eq $_ }).Count -gt 0) {
  Add-ValidationError 'snapshot.messages cannot contain null entries.'
  $messages = @($snapshot.messages | Where-Object { $null -ne $_ })
}
else {
  $messages = @($snapshot.messages)
}
$messageAllowed = @('stableId', 'receivedAt', 'subject', 'from', 'bodyPreview', 'importance', 'isRead', 'conversationId', 'webLink')
$messageRequired = @('stableId', 'receivedAt', 'subject', 'from', 'bodyPreview', 'importance', 'isRead')
for ($index = 0; $index -lt $messages.Count; $index++) {
  $message = $messages[$index]
  $context = "snapshot.messages[$index]"
  Test-RequiredProperties $message $messageRequired $context | Out-Null
  Test-AllowedProperties $message $messageAllowed $context
  Test-NonEmptyString $message.stableId "$context.stableId"
  if ([string]$message.stableId -notmatch '^mail:.+') {
    Add-ValidationError "$context.stableId must contain a value after 'mail:'."
  }
  Test-NonEmptyString $message.subject "$context.subject"
  Test-NonEmptyString $message.from "$context.from"
  ConvertTo-RequiredDateTimeOffset $message.receivedAt "$context.receivedAt" | Out-Null
  if ($message.bodyPreview -isnot [string]) {
    Add-ValidationError "$context.bodyPreview must be a string."
  }
  elseif ([string]$message.bodyPreview -and ([string]$message.bodyPreview).Length -gt 2000) {
    Add-ValidationError "$context.bodyPreview exceeds 2000 characters."
  }
  if (@('low', 'normal', 'high') -notcontains [string]$message.importance) {
    Add-ValidationError "$context.importance must be low, normal, or high."
  }
  if ($message.isRead -isnot [bool]) {
    Add-ValidationError "$context.isRead must be boolean."
  }
  if ($message.PSObject.Properties.Name -contains 'conversationId') {
    Test-NonEmptyString $message.conversationId "$context.conversationId"
  }
  if ($message.PSObject.Properties.Name -contains 'webLink' -and
    -not [Uri]::IsWellFormedUriString([string]$message.webLink, [UriKind]::Absolute)) {
    Add-ValidationError "$context.webLink must be an absolute URI."
  }
}

if ($snapshot.events -isnot [System.Array]) {
  Add-ValidationError 'snapshot.events must be a JSON array.'
  $events = @()
}
elseif (@($snapshot.events | Where-Object { $null -eq $_ }).Count -gt 0) {
  Add-ValidationError 'snapshot.events cannot contain null entries.'
  $events = @($snapshot.events | Where-Object { $null -ne $_ })
}
else {
  $events = @($snapshot.events)
}
$eventRequired = @('stableId', 'privacyMode', 'start', 'end', 'showAs', 'isAllDay')
$busyAllowed = $eventRequired
$relevantRequired = $eventRequired + @('subject', 'bodyPreview', 'organizer', 'attendees', 'location')
$relevantAllowed = $relevantRequired + @('webLink')
for ($index = 0; $index -lt $events.Count; $index++) {
  $calendarEvent = $events[$index]
  $context = "snapshot.events[$index]"
  Test-RequiredProperties $calendarEvent $eventRequired $context | Out-Null
  Test-NonEmptyString $calendarEvent.stableId "$context.stableId"
  if ([string]$calendarEvent.stableId -notmatch '^event:.+') {
    Add-ValidationError "$context.stableId must contain a value after 'event:'."
  }

  if ($calendarEvent.privacyMode -eq 'busyOnly') {
    Test-AllowedProperties $calendarEvent $busyAllowed $context
  }
  elseif ($calendarEvent.privacyMode -eq 'relevant') {
    Test-RequiredProperties $calendarEvent $relevantRequired $context | Out-Null
    Test-AllowedProperties $calendarEvent $relevantAllowed $context
    Test-NonEmptyString $calendarEvent.subject "$context.subject"
    Test-NonEmptyString $calendarEvent.organizer "$context.organizer"
    if ($calendarEvent.bodyPreview -isnot [string]) {
      Add-ValidationError "$context.bodyPreview must be a string."
    }
    elseif ([string]$calendarEvent.bodyPreview -and ([string]$calendarEvent.bodyPreview).Length -gt 2000) {
      Add-ValidationError "$context.bodyPreview exceeds 2000 characters."
    }
    if ($calendarEvent.location -isnot [string]) {
      Add-ValidationError "$context.location must be a string."
    }
    if ($calendarEvent.attendees -isnot [System.Array]) {
      Add-ValidationError "$context.attendees must be a JSON array."
    }
    else {
      $attendees = @($calendarEvent.attendees)
      for ($attendeeIndex = 0; $attendeeIndex -lt $attendees.Count; $attendeeIndex++) {
        Test-NonEmptyString $attendees[$attendeeIndex] "$context.attendees[$attendeeIndex]"
      }
      foreach ($duplicateAttendee in @($attendees | Group-Object | Where-Object { $_.Count -gt 1 })) {
        Add-ValidationError "$context.attendees contains duplicate '$($duplicateAttendee.Name)'."
      }
    }
    if ($calendarEvent.PSObject.Properties.Name -contains 'webLink' -and
      -not [Uri]::IsWellFormedUriString([string]$calendarEvent.webLink, [UriKind]::Absolute)) {
      Add-ValidationError "$context.webLink must be an absolute URI."
    }
  }
  else {
    Add-ValidationError "$context.privacyMode must be relevant or busyOnly."
  }

  if (@('free', 'tentative', 'busy', 'oof', 'workingelsewhere', 'unknown') -notcontains [string]$calendarEvent.showAs) {
    Add-ValidationError "$context.showAs has an unsupported value."
  }
  if ($calendarEvent.isAllDay -isnot [bool]) {
    Add-ValidationError "$context.isAllDay must be boolean."
  }

  $eventStart = ConvertTo-RequiredDateTimeOffset $calendarEvent.start "$context.start"
  $eventEnd = ConvertTo-RequiredDateTimeOffset $calendarEvent.end "$context.end"
  if ($null -ne $eventStart -and $null -ne $eventEnd) {
    if ($eventEnd -le $eventStart) {
      Add-ValidationError "$context.end must be after start."
    }
    if ($null -ne $windowStart -and $eventStart -lt $windowStart) {
      Add-ValidationError "$context starts before the calendar window."
    }
    if ($null -ne $windowEnd -and $eventEnd -gt $windowEnd) {
      Add-ValidationError "$context ends after the calendar window."
    }
  }
}

$allIds = @()
$allIds += @($messages | ForEach-Object { [string]$_.stableId })
$allIds += @($events | ForEach-Object { [string]$_.stableId })
$duplicateIds = @($allIds | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Group-Object | Where-Object { $_.Count -gt 1 })
foreach ($duplicate in $duplicateIds) {
  Add-ValidationError "stableId '$($duplicate.Name)' occurs $($duplicate.Count) times."
}

$pagingRequired = @('mail', 'calendar')
if (Test-RequiredProperties $snapshot.paging $pagingRequired 'snapshot.paging') {
  Test-AllowedProperties $snapshot.paging $pagingRequired 'snapshot.paging'
  Test-PageSet $snapshot.paging.mail 'snapshot.paging.mail' $messages.Count 1000
  Test-PageSet $snapshot.paging.calendar 'snapshot.paging.calendar' $events.Count 256
}

if ($errors.Count -gt 0) {
  Write-Host "IconDB morning snapshot validation FAILED ($($errors.Count) error(s)):" -ForegroundColor Red
  foreach ($validationError in $errors) {
    Write-Host " - $validationError" -ForegroundColor Red
  }
  exit 1
}

Write-Host ("IconDB morning snapshot validation PASSED: {0} message(s), {1} event(s), exported {2}." -f $messages.Count, $events.Count, $exportedAt.ToString('o')) -ForegroundColor Green

if (-not [string]::IsNullOrWhiteSpace($PromoteToLatest)) {
  $sourcePath = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $Path).Path)
  $targetPath = [IO.Path]::GetFullPath($PromoteToLatest)
  if ([IO.Path]::GetFileName($targetPath) -ne 'latest.json') {
    Write-Error 'PromoteToLatest must target a file named latest.json.'
    exit 1
  }
  if ([IO.Path]::GetDirectoryName($sourcePath) -ne [IO.Path]::GetDirectoryName($targetPath)) {
    Write-Error 'Candidate and latest.json must be in the same staging directory.'
    exit 1
  }
  if ($sourcePath -eq $targetPath) {
    Write-Error 'The dated candidate and latest.json must be different files.'
    exit 1
  }

  $temporaryPath = "$targetPath.promoting"
  $backupPath = "$targetPath.previous"
  try {
    [IO.File]::Copy($sourcePath, $temporaryPath, $true)
    if ([IO.File]::Exists($targetPath)) {
      [IO.File]::Replace($temporaryPath, $targetPath, $backupPath, $true)
      Remove-Item -LiteralPath $backupPath -Force -ErrorAction SilentlyContinue
    }
    else {
      [IO.File]::Move($temporaryPath, $targetPath)
    }
    Write-Host "Promoted validated candidate to $targetPath." -ForegroundColor Green
  }
  catch {
    Remove-Item -LiteralPath $temporaryPath -Force -ErrorAction SilentlyContinue
    Write-Error "Validated candidate could not be promoted: $($_.Exception.Message)"
    exit 1
  }
}
exit 0
