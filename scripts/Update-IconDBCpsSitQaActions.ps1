[CmdletBinding()]
param(
  [ValidateSet('Preview', 'Apply')]
  [string]$Mode = 'Preview',

  [string]$WorkbookUrl = 'https://pgone.sharepoint.com/sites/RTARELEASE/Shared Documents/General/IconDB Integration/Project alignment docs/Icon DB CPS new standard.xlsx',

  [datetime]$AsOf = [datetime]'2026-08-12'
)

$ErrorActionPreference = 'Stop'

$actions = @(
  [pscustomobject]@{
    Task            = 'Send one correct FemCare SIT JSON payload to Jyoti for immediate analysis'
    Owner           = 'Michal'
    Duration        = 1
    PredecessorTask = $null
  },
  [pscustomobject]@{
    Task            = 'Analyze FemCare SIT payload and identify Enovia fixes for the September change window'
    Owner           = 'Jyoti'
    Duration        = 2
    PredecessorTask = 'Send one correct FemCare SIT JSON payload to Jyoti for immediate analysis'
  },
  [pscustomobject]@{
    Task            = 'Complete FemCare SIT validation before current Enovia SIT decommission'
    Owner           = 'Michal / Tommy / Jyoti / FemCare'
    Duration        = 5
    PredecessorTask = 'Analyze FemCare SIT payload and identify Enovia fixes for the September change window'
  },
  [pscustomobject]@{
    Task            = 'Switch IconDB endpoint from Enovia SIT to Enovia QA after SIT validation'
    Owner           = 'Tommy / Steve'
    Duration        = 1
    PredecessorTask = 'Complete FemCare SIT validation before current Enovia SIT decommission'
  },
  [pscustomobject]@{
    Task            = 'Start FemCare testing in Enovia QA after the IconDB endpoint switch'
    Owner           = 'Michal / Jyoti / FemCare'
    Duration        = 1
    PredecessorTask = 'Switch IconDB endpoint from Enovia SIT to Enovia QA after SIT validation'
  },
  [pscustomobject]@{
    Task            = 'Prepare Enovia SIT decommission, new-SIT migration, and IconDB QA resynchronization process'
    Owner           = 'Tommy / Steve / Jyoti / Michal'
    Duration        = 7
    PredecessorTask = $null
  },
  [pscustomobject]@{
    Task            = 'Confirm exact new Enovia SIT availability and production-copy migration schedule'
    Owner           = 'Jyoti / Enovia team'
    Duration        = 1
    PredecessorTask = 'Prepare Enovia SIT decommission, new-SIT migration, and IconDB QA resynchronization process'
  }
)

function Clear-ComReference {
  param($Value)
  if ($null -ne $Value -and [Runtime.InteropServices.Marshal]::IsComObject($Value)) {
    [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($Value)
  }
}

function Find-TaskRow {
  param($Sheet, [string]$Task, [int]$LastRow)

  $matches = @(10..$LastRow | Where-Object { ([string]$Sheet.Cells.Item($_, 5).Text).Trim() -ceq $Task })
  if ($matches.Count -gt 1) { throw "Task identity is not unique: $Task" }
  if ($matches.Count -eq 1) { return [int]$matches[0] }
  return $null
}

$excel = $null
$workbook = $null
$schedule = $null

try {
  $excel = New-Object -ComObject Excel.Application
  $excel.Visible = $false
  $excel.DisplayAlerts = $false
  $workbook = $excel.Workbooks.Open($WorkbookUrl, 0, ($Mode -eq 'Preview'))
  if ($Mode -eq 'Apply' -and $workbook.ReadOnly) {
    throw 'The authoritative workbook opened read-only; no changes were made.'
  }

  $schedule = $workbook.Worksheets.Item('Project schedule')
  $lastRow = $schedule.UsedRange.Row + $schedule.UsedRange.Rows.Count - 1
  $anchorTask = 'Validate corrected production integration after deployment and retain rollback evidence'
  $templateTask = 'FC NA testing scenarios for UAT'
  $anchorRow = Find-TaskRow -Sheet $schedule -Task $anchorTask -LastRow $lastRow
  $templateRow = Find-TaskRow -Sheet $schedule -Task $templateTask -LastRow $lastRow
  if ($null -eq $anchorRow) { throw "Missing insertion anchor: $anchorTask" }
  if ($null -eq $templateRow) { throw "Missing formatting template: $templateTask" }

  $existingRows = @{}
  foreach ($action in $actions) {
    $existingRows[$action.Task] = Find-TaskRow -Sheet $schedule -Task $action.Task -LastRow $lastRow
  }
  $actionsToAdd = @($actions | Where-Object { $null -eq $existingRows[$_.Task] })

  if ($Mode -eq 'Preview') {
    [pscustomobject]@{
      Mode         = $Mode
      AnchorRow    = $anchorRow
      TemplateRow  = $templateRow
      Existing     = @($actions | Where-Object { $null -ne $existingRows[$_.Task] } | ForEach-Object { $_.Task })
      ActionsToAdd = @($actionsToAdd | Select-Object Task, Owner, Duration, PredecessorTask)
    }
    return
  }

  if ($actionsToAdd.Count -gt 0 -and $actionsToAdd.Count -ne $actions.Count) {
    throw 'Only part of the SIT-to-QA action block exists; inspect the master before applying.'
  }

  if ($actionsToAdd.Count -eq $actions.Count) {
    for ($index = 0; $index -lt $actions.Count; $index++) {
      [void]$schedule.Rows.Item($anchorRow).Insert()
    }

    $lastRow = $schedule.UsedRange.Row + $schedule.UsedRange.Rows.Count - 1
    $templateRow = Find-TaskRow -Sheet $schedule -Task $templateTask -LastRow $lastRow
    for ($index = 0; $index -lt $actions.Count; $index++) {
      $action = $actions[$index]
      $row = $anchorRow + $index
      [void]$schedule.Range("A$templateRow").Copy($schedule.Range("A$row"))
      [void]$schedule.Range("C${templateRow}:FA$templateRow").Copy($schedule.Range("C${row}:FA$row"))
      $schedule.Cells.Item($row, 5).Value2 = [string]$action.Task
      $schedule.Cells.Item($row, 6).Value2 = [string]'Not Started'
      $schedule.Cells.Item($row, 8).Value2 = [string]$action.Owner
      $schedule.Cells.Item($row, 9).Formula = [string]"=IF(F$row=`"Done`",100%,`"`")"
      $schedule.Cells.Item($row, 12).Value2 = [double]$action.Duration
      $schedule.Cells.Item($row, 13).Formula = [string]"=K$row-J$row+1"
      if ($null -eq $action.PredecessorTask) {
        $schedule.Cells.Item($row, 10).Formula = [string]"=WORKDAY(DATE($($AsOf.Year),$($AsOf.Month),$($AsOf.Day)),0,Holidays!`$C:`$C)"
      }
      else {
        $predecessorRow = Find-TaskRow -Sheet $schedule -Task $action.PredecessorTask -LastRow $lastRow
        if ($null -eq $predecessorRow) { throw "Missing predecessor task: $($action.PredecessorTask)" }
        $schedule.Cells.Item($row, 10).Formula = [string]"=WORKDAY(K$predecessorRow,1,Holidays!`$C:`$C)"
      }
      $schedule.Cells.Item($row, 11).Formula = [string]"=WORKDAY(J$row,L$row-1,Holidays!`$C:`$C)"
    }
  }

  $excel.CalculateFull()
  $workbook.Save()
  [pscustomobject]@{
    Mode         = 'Apply'
    AddedActions = @($actionsToAdd.Task)
  }
}
finally {
  if ($null -ne $workbook) { $workbook.Close($false) }
  Clear-ComReference $schedule
  Clear-ComReference $workbook
  if ($null -ne $excel) { $excel.Quit() }
  Clear-ComReference $excel
  [GC]::Collect()
  [GC]::WaitForPendingFinalizers()
}
