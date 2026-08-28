[CmdletBinding()]
param(
  [ValidateSet('Preview', 'Apply')]
  [string]$Mode = 'Preview',

  [string]$WorkbookUrl = 'https://pgone.sharepoint.com/sites/RTARELEASE/Shared Documents/General/IconDB Integration/Project alignment docs/Icon DB CPS new standard.xlsx'
)

$ErrorActionPreference = 'Stop'

$validationTask = '[Recovery R215] Michal validates corrected FC EU template and confirms upload-ready pack'
$productionTask = '[Recovery R216] Execute controlled FC EU production upload after restart gate'
$qaSwitchTask = 'Confirm Enovia QA deployment, refresh/baseline, reconciliation, and sole endpoint switch'
$actions = @(
  [pscustomobject]@{
    Task     = 'FC EU obtains Enovia QA access and waits for the confirmed QA endpoint switch before testing'
    Owner    = 'Ewa / FC EU'
    Start    = '=WORKDAY(DATE(2026,8,25),0,Holidays!$C:$C)'
    Duration = 5
  },
  [pscustomobject]@{
    Task     = 'Mubarak confirms whether three additional FC EU GS1/subcopy integration types are approved'
    Owner    = 'Mubarak / Ewa / FC EU'
    Start    = '=WORKDAY(DATE(2026,8,25),0,Holidays!$C:$C)'
    Duration = 5
  },
  [pscustomobject]@{
    Task     = 'Mass upload and test approved FC EU icons in Canvas QA and Enovia QA'
    Owner    = 'Michal / Ewa / FC EU / IDB Team'
    Start    = $null
    Duration = 4
  }
)

function Remove-ComReference {
  param($Value)
  if ($null -ne $Value -and [Runtime.InteropServices.Marshal]::IsComObject($Value)) {
    [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($Value)
  }
}

function Find-TaskRow {
  param($Sheet, [string]$Task, [int]$LastRow)
  $matches = @(10..$LastRow | Where-Object { ([string]$Sheet.Cells.Item($_, 5).Text).Trim() -ceq $Task })
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
  $validationRow = Find-TaskRow -Sheet $schedule -Task $validationTask -LastRow $lastRow
  $productionRow = Find-TaskRow -Sheet $schedule -Task $productionTask -LastRow $lastRow
  $qaSwitchRow = Find-TaskRow -Sheet $schedule -Task $qaSwitchTask -LastRow $lastRow

  $existingRows = @{}
  foreach ($action in $actions) {
    $matches = @(10..$lastRow | Where-Object { ([string]$schedule.Cells.Item($_, 5).Text).Trim() -ceq $action.Task })
    if ($matches.Count -gt 1) { throw "Task identity is not unique: $($action.Task)" }
    $existingRows[$action.Task] = if ($matches.Count -eq 1) { [int]$matches[0] } else { $null }
  }

  $preview = [pscustomobject]@{
    Mode               = $Mode
    ValidationRow      = $validationRow
    ValidationStatus   = [string]$schedule.Cells.Item($validationRow, 6).Text
    ValidationEvidence = 'Validation completed; Region corrected from Europe Focus to Europe in Canvas and Enovia'
    InsertBeforeRow    = $productionRow
    QaSwitchRow        = $qaSwitchRow
    ExistingActions    = @($actions | Where-Object { $null -ne $existingRows[$_.Task] } | ForEach-Object { $_.Task })
    ActionsToAdd       = @($actions | Where-Object { $null -eq $existingRows[$_.Task] } | Select-Object Task, Owner, Duration)
  }
  if ($Mode -eq 'Preview') { $preview; return }

  $actionsToAdd = @($actions | Where-Object { $null -eq $existingRows[$_.Task] })
  if ($actionsToAdd.Count -gt 0 -and $actionsToAdd.Count -ne $actions.Count) {
    throw 'Only part of the FC EU SIT-to-QA action block exists; inspect the master before applying.'
  }

  $schedule.Cells.Item($validationRow, 6).Value2 = [string]'Done'
  $schedule.Cells.Item($validationRow, 9).Value2 = [double]1
  $schedule.Cells.Item($validationRow, 11).Value2 = [double]([datetime]'2026-08-25').ToOADate()
  $schedule.Cells.Item($validationRow, 13).Formula = [string]"=K$validationRow-J$validationRow+1"

  if ($actionsToAdd.Count -eq $actions.Count) {
    foreach ($nullValue in $actions) { [void]$schedule.Rows.Item($productionRow).Insert() }
    $lastRow = [int]($schedule.UsedRange.Row + $schedule.UsedRange.Rows.Count - 1)
    $validationRow = Find-TaskRow -Sheet $schedule -Task $validationTask -LastRow $lastRow
    $qaSwitchRow = Find-TaskRow -Sheet $schedule -Task $qaSwitchTask -LastRow $lastRow

    for ($index = 0; $index -lt $actions.Count; $index++) {
      $row = $productionRow + $index
      $action = $actions[$index]
      [void]$schedule.Range("A$validationRow").Copy($schedule.Range("A$row"))
      [void]$schedule.Range("C${validationRow}:FA$validationRow").Copy($schedule.Range("C${row}:FA$row"))
      $schedule.Cells.Item($row, 5).Value2 = [string]$action.Task
      $schedule.Cells.Item($row, 6).Value2 = [string]'Not Started'
      $schedule.Cells.Item($row, 8).Value2 = [string]$action.Owner
      $schedule.Cells.Item($row, 9).Formula = [string]"=IF(F$row=`"Done`",100%,`"`")"
      $schedule.Cells.Item($row, 12).Value2 = [double]$action.Duration
      $schedule.Cells.Item($row, 13).Formula = [string]"=K$row-J$row+1"
      if ($index -lt 2) {
        $schedule.Cells.Item($row, 10).Formula = [string]$action.Start
      }
      else {
        $sitAccessRow = $productionRow
        $typeDecisionRow = $productionRow + 1
        $schedule.Cells.Item($row, 10).Formula = [string]"=WORKDAY(MAX(K$qaSwitchRow,K$sitAccessRow,K$typeDecisionRow),1,Holidays!`$C:`$C)"
      }
      $schedule.Cells.Item($row, 11).Formula = [string]"=WORKDAY(J$row,L$row-1,Holidays!`$C:`$C)"
    }
  }

  $productionRow = Find-TaskRow -Sheet $schedule -Task $productionTask -LastRow ([int]($schedule.UsedRange.Row + $schedule.UsedRange.Rows.Count - 1))
  $qaTestRow = Find-TaskRow -Sheet $schedule -Task $actions[2].Task -LastRow ([int]($schedule.UsedRange.Row + $schedule.UsedRange.Rows.Count - 1))
  $restartRow = Find-TaskRow -Sheet $schedule -Task 'Confirm production restart authority and AAC Rule Manager handoff criteria' -LastRow ([int]($schedule.UsedRange.Row + $schedule.UsedRange.Rows.Count - 1))
  $schedule.Cells.Item($productionRow, 10).Formula = [string]"=WORKDAY(MAX(K$restartRow,K$qaTestRow),1,Holidays!`$C:`$C)"

  $excel.CalculateFull()
  $workbook.Save()
  [pscustomobject]@{ Mode = 'Apply'; ValidationRow = $validationRow; AddedActions = @($actionsToAdd.Task); ProductionRow = $productionRow; Saved = $workbook.Saved }
}
finally {
  Remove-ComReference $schedule
  if ($null -ne $workbook) { $workbook.Close($false); Remove-ComReference $workbook }
  if ($null -ne $excel) { $excel.Quit(); Remove-ComReference $excel }
  [GC]::Collect()
  [GC]::WaitForPendingFinalizers()
}
