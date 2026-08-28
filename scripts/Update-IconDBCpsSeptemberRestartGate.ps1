[CmdletBinding()]
param(
  [ValidateSet('Preview', 'Apply')]
  [string]$Mode = 'Preview',

  [string]$WorkbookUrl = 'https://pgone.sharepoint.com/sites/RTARELEASE/Shared Documents/General/IconDB Integration/Project alignment docs/Icon DB CPS new standard.xlsx'
)

$ErrorActionPreference = 'Stop'

$restartTask = 'Confirm production restart authority and AAC Rule Manager handoff criteria'
$updates = @(
  [pscustomobject]@{
    Business = 'Fem EU'
    Task = '[Recovery R247] IDB Service team upload FEM EU data in Canvas PROD'
    PredecessorTask = '[Recovery R246] IDB Service team upload FEM EU data in Canvas QA (sample data to execute E2E testing)'
  },
  [pscustomobject]@{
    Business = 'LA Hair'
    Task = 'IDB Service team upload LA HAIR data in Canvas PROD'
    PredecessorTask = 'LA HAIR  shares OC business case for E2E tetsing and sign-off'
    AdditionalPredecessorTask = '[Recovery R304] Realign the LA IconDB plan with the Transformation Team and schedule the leadership session'
  },
  [pscustomobject]@{
    Business = 'LA SPC'
    Task = 'IDB Service team upload  LA SPC data in Canvas PROD'
    PredecessorTask = 'LA SPC shares OC business case for E2E tetsing and sign-off'
    AdditionalPredecessorTask = '[Recovery R304] Realign the LA IconDB plan with the Transformation Team and schedule the leadership session'
  },
  [pscustomobject]@{
    Business = 'LA Oral'
    Task = 'IDB Service team upload LA Oral data in Canvas PROD'
    PredecessorTask = 'LA Oral shares OC business case for E2E tetsing and sign-off'
    AdditionalPredecessorTask = '[Recovery R304] Realign the LA IconDB plan with the Transformation Team and schedule the leadership session'
  },
  [pscustomobject]@{
    Business = 'LA Baby'
    Task = 'IDB Service team upload LA Baby Fem data in Canvas PROD'
    PredecessorTask = 'LA Baby Fem shares OC business case for E2E tetsing and sign-off'
    AdditionalPredecessorTask = '[Recovery R304] Realign the LA IconDB plan with the Transformation Team and schedule the leadership session'
    MatchIndex = 1
  },
  [pscustomobject]@{
    Business = 'LA Fem'
    Task = 'IDB Service team upload LA Baby Fem data in Canvas PROD'
    PredecessorTask = 'LA Baby Fem shares OC business case for E2E tetsing and sign-off'
    AdditionalPredecessorTask = '[Recovery R304] Realign the LA IconDB plan with the Transformation Team and schedule the leadership session'
    MatchIndex = 2
  }
)

$validationUpdates = @(
  [pscustomobject]@{ Business = 'Fem EU validation'; Task = '[Recovery R252] FEM EU UAT (Canvas QA + Enovia SIT)+ BVE'; PredecessorTask = '[Recovery R247] IDB Service team upload FEM EU data in Canvas PROD'; AdditionalPredecessorTask = '[Recovery R249] FEM EU testing scenarios for UAT' },
  [pscustomobject]@{ Business = 'LA Hair validation'; Task = 'LA HAIR  UAT (Canvas QA + Enovia SIT)+ BVE'; PredecessorTask = 'IDB Service team upload LA HAIR data in Canvas PROD'; AdditionalPredecessorTask = 'Train LA HAIR teams' },
  [pscustomobject]@{ Business = 'LA SPC validation'; Task = 'LA SPC UAT (Canvas QA + Enovia SIT)+ BVE'; PredecessorTask = 'IDB Service team upload  LA SPC data in Canvas PROD'; AdditionalPredecessorTask = 'Train  LA SPC teams' },
  [pscustomobject]@{ Business = 'LA Oral validation'; Task = 'LA Oral UAT (Canvas QA + Enovia SIT)+ BVE'; PredecessorTask = 'IDB Service team upload LA Oral data in Canvas PROD'; AdditionalPredecessorTask = 'Train LA Oral teams' },
  [pscustomobject]@{ Business = 'LA Baby validation'; Task = 'LA Baby Fem UAT (Canvas QA + Enovia SIT)+ BVE'; PredecessorTask = 'IDB Service team upload LA Baby Fem data in Canvas PROD'; AdditionalPredecessorTask = 'Train LA Baby Fem teams'; MatchIndex = 1 },
  [pscustomobject]@{ Business = 'LA Fem validation'; Task = 'LA Baby Fem UAT (Canvas QA + Enovia SIT)+ BVE'; PredecessorTask = 'IDB Service team upload LA Baby Fem data in Canvas PROD'; AdditionalPredecessorTask = 'Train LA Baby Fem teams'; MatchIndex = 2 }
)

function Remove-ComReference {
  param($Value)
  if ($null -ne $Value -and [Runtime.InteropServices.Marshal]::IsComObject($Value)) {
    [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($Value)
  }
}

function Find-TaskRows {
  param($Sheet, [string]$Task, [int]$LastRow)
  return @(10..$LastRow | Where-Object { ([string]$Sheet.Cells.Item($_, 5).Text).Trim() -ceq $Task })
}

function Resolve-TaskRow {
  param($Sheet, $Update, [string]$PropertyName, [int]$LastRow)
  $task = [string]$Update.$PropertyName
  $matches = @(Find-TaskRows -Sheet $Sheet -Task $task -LastRow $LastRow)
  $matchIndex = if ($null -ne $Update.MatchIndex) { [int]$Update.MatchIndex } else { 1 }
  $expectedCount = if ($null -ne $Update.MatchIndex) { 2 } else { 1 }
  if ($matches.Count -ne $expectedCount) {
    throw "Expected $expectedCount row(s) for '$task' but found $($matches.Count)."
  }
  return [int]$matches[$matchIndex - 1]
}

function Resolve-UniqueTaskRow {
  param($Sheet, [string]$Task, [int]$LastRow)
  $matches = @(Find-TaskRows -Sheet $Sheet -Task $Task -LastRow $LastRow)
  if ($matches.Count -ne 1) { throw "Expected one row for '$Task' but found $($matches.Count)." }
  return [int]$matches[0]
}

$excel = $null
$workbook = $null
$schedule = $null

try {
  $excel = New-Object -ComObject Excel.Application
  $excel.Visible = $false
  $excel.DisplayAlerts = $false
  $workbook = $excel.Workbooks.Open($WorkbookUrl, 0, ($Mode -eq 'Preview'))
  if ($Mode -eq 'Apply' -and $workbook.ReadOnly) { throw 'The authoritative workbook opened read-only; no changes were made.' }
  $schedule = $workbook.Worksheets.Item('Project schedule')
  $lastRow = [int]($schedule.UsedRange.Row + $schedule.UsedRange.Rows.Count - 1)

  $restartRows = @(Find-TaskRows -Sheet $schedule -Task $restartTask -LastRow $lastRow)
  if ($restartRows.Count -ne 1) { throw "Expected one restart-gate task but found $($restartRows.Count)." }
  $restartRow = [int]$restartRows[0]
  $restartFinish = $schedule.Cells.Item($restartRow, 11).Value2
  if ($restartFinish -isnot [double] -or [datetime]::FromOADate($restartFinish).Date -ne [datetime]'2026-09-16') {
    throw "Restart gate must finish on 16-Sep-2026; found '$([string]$schedule.Cells.Item($restartRow, 11).Text)'."
  }

  $preview = foreach ($update in $updates) {
    $row = Resolve-TaskRow -Sheet $schedule -Update $update -PropertyName 'Task' -LastRow $lastRow
    $predecessorRow = Resolve-TaskRow -Sheet $schedule -Update $update -PropertyName 'PredecessorTask' -LastRow $lastRow
    $predecessorRows = @($restartRow, $predecessorRow)
    if ($null -ne $update.AdditionalPredecessorTask) {
      $predecessorRows += Resolve-UniqueTaskRow -Sheet $schedule -Task $update.AdditionalPredecessorTask -LastRow $lastRow
    }
    $formula = "=WORKDAY(MAX($(@($predecessorRows | ForEach-Object { "K$_" }) -join ',')),1,Holidays!`$C:`$C)"
    [pscustomobject]@{
      Business = $update.Business
      Row = $row
      PredecessorRow = $predecessorRow
      CurrentStart = [string]$schedule.Cells.Item($row, 10).Text
      CurrentFormula = [string]$schedule.Cells.Item($row, 10).Formula
      NewFormula = $formula
    }
  }
  $preview += foreach ($update in $validationUpdates) {
    $row = Resolve-TaskRow -Sheet $schedule -Update $update -PropertyName 'Task' -LastRow $lastRow
    $predecessorRow = Resolve-TaskRow -Sheet $schedule -Update $update -PropertyName 'PredecessorTask' -LastRow $lastRow
    $additionalRow = Resolve-TaskRow -Sheet $schedule -Update $update -PropertyName 'AdditionalPredecessorTask' -LastRow $lastRow
    $formula = "=WORKDAY(MAX(K$predecessorRow,K$additionalRow),1,Holidays!`$C:`$C)"
    [pscustomobject]@{
      Business = $update.Business
      Row = $row
      PredecessorRow = "$predecessorRow,$additionalRow"
      CurrentStart = [string]$schedule.Cells.Item($row, 10).Text
      CurrentFormula = [string]$schedule.Cells.Item($row, 10).Formula
      NewFormula = $formula
    }
  }
  if ($Mode -eq 'Preview') { $preview; return }

  foreach ($item in $preview) {
    $schedule.Cells.Item($item.Row, 10).Formula = [string]$item.NewFormula
  }
  $excel.CalculateFull()
  $workbook.Save()
  [pscustomobject]@{ Mode = 'Apply'; RestartRow = $restartRow; UpdatedRows = ($preview.Row -join ','); Saved = $workbook.Saved }
}
finally {
  Remove-ComReference $schedule
  if ($null -ne $workbook) { $workbook.Close($false); Remove-ComReference $workbook }
  if ($null -ne $excel) { $excel.Quit(); Remove-ComReference $excel }
  [GC]::Collect()
  [GC]::WaitForPendingFinalizers()
}