[CmdletBinding()]
param(
  [Parameter(Mandatory = $true, Position = 0)]
  [ValidateNotNullOrEmpty()]
  [string]$Path
)

$errors = New-Object System.Collections.Generic.List[string]

function Add-ValidationError([string]$Message) { $script:errors.Add($Message) }

function Test-Required([object]$Object, [string[]]$Names, [string]$Context) {
  if ($null -eq $Object) { Add-ValidationError "$Context is missing."; return }
  $present = @($Object.PSObject.Properties.Name)
  foreach ($name in $Names) {
    if ($present -notcontains $name) { Add-ValidationError "$Context.$name is required." }
  }
}

function Test-Allowed([object]$Object, [string[]]$Names, [string]$Context) {
  if ($null -eq $Object) { return }
  foreach ($name in @($Object.PSObject.Properties.Name)) {
    if ($Names -notcontains $name) { Add-ValidationError "$Context contains prohibited or unknown field '$name'." }
  }
}

function ConvertTo-DateTimeOffset([object]$Value, [string]$Context) {
  if ([string]$Value -notmatch '^\d{4}-\d{2}-\d{2}T.+(Z|[+-][0-9]{2}:[0-9]{2})$') {
    Add-ValidationError "$Context must be an ISO 8601 date-time with an offset."
    return $null
  }
  try { return [DateTimeOffset]::Parse([string]$Value, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::RoundtripKind) }
  catch { Add-ValidationError "$Context is not a valid date-time."; return $null }
}

if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { Write-Error "State file not found: $Path"; exit 1 }
try { $state = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop }
catch { Write-Error "State is not valid JSON: $($_.Exception.Message)"; exit 1 }

$rootFields = @('schemaVersion', 'run', 'checkpoint', 'sourceDeltaPath', 'threadHeads', 'calendarFingerprints')
Test-Required $state $rootFields 'state'
Test-Allowed $state $rootFields 'state'
if ($state.schemaVersion -ne '1.0') { Add-ValidationError "state.schemaVersion must be '1.0'." }

Test-Required $state.run @('runId', 'status', 'exportedAt') 'state.run'
Test-Allowed $state.run @('runId', 'status', 'exportedAt') 'state.run'
$runId = [Guid]::Empty
if (-not [Guid]::TryParse([string]$state.run.runId, [ref]$runId)) { Add-ValidationError 'state.run.runId must be a GUID.' }
if ($state.run.status -ne 'complete') { Add-ValidationError "state.run.status must be 'complete'." }
$exportedAt = ConvertTo-DateTimeOffset $state.run.exportedAt 'state.run.exportedAt'

Test-Required $state.checkpoint @('watermark', 'promotedAt') 'state.checkpoint'
Test-Allowed $state.checkpoint @('watermark', 'promotedAt') 'state.checkpoint'
$watermark = ConvertTo-DateTimeOffset $state.checkpoint.watermark 'state.checkpoint.watermark'
$promotedAt = ConvertTo-DateTimeOffset $state.checkpoint.promotedAt 'state.checkpoint.promotedAt'
if ($null -ne $exportedAt -and $null -ne $watermark -and [Math]::Abs(($exportedAt - $watermark).TotalMinutes) -gt 5) {
  Add-ValidationError 'state.run.exportedAt must be within five minutes of the checkpoint watermark.'
}
if ($null -ne $watermark -and $null -ne $promotedAt -and $promotedAt -lt $watermark) { Add-ValidationError 'state.checkpoint.promotedAt cannot precede watermark.' }
if ([string]$state.sourceDeltaPath -notmatch '^/GBS IT docs/\.local/portfolio-control/candidates/portfolio-evidence-delta-\d{8}-\d{6}Z-[0-9a-fA-F-]{36}\.json$') {
  Add-ValidationError 'state.sourceDeltaPath must use the portfolio candidate path and filename format.'
}
elseif ([IO.Path]::GetFileNameWithoutExtension([string]$state.sourceDeltaPath) -notlike "*-$($state.run.runId)") {
  Add-ValidationError 'state.sourceDeltaPath must end with state.run.runId.'
}

$threadHeads = @($state.threadHeads)
$calendarFingerprints = @($state.calendarFingerprints)
for ($index = 0; $index -lt $threadHeads.Count; $index++) {
  $item = $threadHeads[$index]; $context = "state.threadHeads[$index]"
  Test-Required $item @('conversationId', 'currentHeadId', 'lastObservedAt') $context
  Test-Allowed $item @('conversationId', 'currentHeadId', 'lastObservedAt') $context
  if ([string]::IsNullOrWhiteSpace([string]$item.conversationId)) { Add-ValidationError "$context.conversationId cannot be empty." }
  if ([string]$item.currentHeadId -notmatch '^mail:.+') { Add-ValidationError "$context.currentHeadId must start with mail:." }
  ConvertTo-DateTimeOffset $item.lastObservedAt "$context.lastObservedAt" | Out-Null
}
foreach ($duplicate in @($threadHeads | Group-Object conversationId | Where-Object { $_.Count -gt 1 })) { Add-ValidationError "conversationId '$($duplicate.Name)' occurs $($duplicate.Count) times." }

$calendarFields = @('stableId', 'fingerprint', 'privacyMode', 'start', 'end', 'showAs', 'isAllDay', 'changeType', 'lastObservedAt')
for ($index = 0; $index -lt $calendarFingerprints.Count; $index++) {
  $item = $calendarFingerprints[$index]; $context = "state.calendarFingerprints[$index]"
  Test-Required $item $calendarFields $context
  Test-Allowed $item $calendarFields $context
  if ([string]$item.stableId -notmatch '^event:.+') { Add-ValidationError "$context.stableId must start with event:." }
  if ([string]$item.fingerprint -notmatch '^sha256:[0-9a-f]{64}$') { Add-ValidationError "$context.fingerprint is invalid." }
  if (@('relevant', 'busyOnly') -notcontains [string]$item.privacyMode) { Add-ValidationError "$context.privacyMode is invalid." }
  if (@('free', 'tentative', 'busy', 'oof', 'workingelsewhere', 'unknown') -notcontains [string]$item.showAs) { Add-ValidationError "$context.showAs is invalid." }
  if (@('added', 'updated', 'cancelled') -notcontains [string]$item.changeType) { Add-ValidationError "$context.changeType is invalid." }
  if ($item.isAllDay -isnot [bool]) { Add-ValidationError "$context.isAllDay must be boolean." }
  $start = ConvertTo-DateTimeOffset $item.start "$context.start"
  $end = ConvertTo-DateTimeOffset $item.end "$context.end"
  ConvertTo-DateTimeOffset $item.lastObservedAt "$context.lastObservedAt" | Out-Null
  if ($null -ne $start -and $null -ne $end -and $end -le $start) { Add-ValidationError "$context.end must be after start." }
}
foreach ($duplicate in @($calendarFingerprints | Group-Object stableId | Where-Object { $_.Count -gt 1 })) { Add-ValidationError "calendar stableId '$($duplicate.Name)' occurs $($duplicate.Count) times." }

if ($errors.Count -gt 0) {
  Write-Host "Portfolio control state validation FAILED ($($errors.Count) error(s)):" -ForegroundColor Red
  foreach ($validationError in $errors) { Write-Host " - $validationError" -ForegroundColor Red }
  exit 1
}

Write-Host ("Portfolio control state validation PASSED: {0} thread head(s), {1} calendar fingerprint(s)." -f $threadHeads.Count, $calendarFingerprints.Count) -ForegroundColor Green
exit 0
