[CmdletBinding()]
param(
  [ValidateSet('Preview', 'Apply')]
  [string]$Mode = 'Preview',

  [string]$WorkbookUrl = 'https://pgone.sharepoint.com/sites/RTARELEASE/Shared Documents/General/IconDB Integration/Project alignment docs/Icon DB CPS new standard.xlsx'
)

$ErrorActionPreference = 'Stop'

$updates = @(
  [pscustomobject]@{
    CurrentTask = 'Confirm QA-first FemCare scope, sample, sign-off owner, and EECAR handling'
    NewTask     = 'Complete and document current Enovia SIT validation before 31 August refresh'
    Status      = 'In Progress'
    Owner       = 'Michal / Tommy / Steve / Jyoti / FemCare'
    Start       = '=WORKDAY(DATE(2026,8,26),0,Holidays!$C:$C)'
    Duration    = 4
  },
  [pscustomobject]@{
    CurrentTask = '[Recovery R231] Prepare OC EU production pack including OCEU_534 and OCEU_318'
    NewTask     = $null
    Status      = 'In Progress'
    Owner       = $null
    Start       = $null
    Duration    = $null
  },
  [pscustomobject]@{
    CurrentTask = '[Recovery R233] Confirm OC EU acceptance scenarios, signer, variable-text BVE/AAC decision, and approved upload/release route (CPM-672)'
    NewTask     = $null
    Status      = 'In Progress'
    Owner       = $null
    Start       = $null
    Duration    = $null
  },
  [pscustomobject]@{
    CurrentTask = '[Recovery R246] IDB Service team upload FEM EU data in Canvas QA (sample data to execute E2E testing)'
    NewTask     = $null
    Status      = 'Done'
    Owner       = $null
    Start       = '=WORKDAY(DATE(2026,8,26),0,Holidays!$C:$C)'
    Duration    = 1
  },
  [pscustomobject]@{
    CurrentTask = '[Recovery R249] FEM EU testing scenarios for UAT'
    NewTask     = $null
    Status      = 'In Progress'
    Owner       = $null
    Start       = '=WORKDAY(DATE(2026,8,26),0,Holidays!$C:$C)'
    Duration    = 3
  },
  [pscustomobject]@{
    CurrentTask = '[Recovery R252] FEM EU UAT (Canvas QA + Enovia SIT)+ BVE'
    NewTask     = $null
    Status      = 'In Progress'
    Owner       = 'Michal / Fem EU / Jyoti / BVE'
    StartFrom   = @(
      '[Recovery R246] IDB Service team upload FEM EU data in Canvas QA (sample data to execute E2E testing)',
      '[Recovery R249] FEM EU testing scenarios for UAT'
    )
    Duration    = 1
  }
)

function Remove-ComReference {
  param($Value)
  if ($null -ne $Value -and [Runtime.InteropServices.Marshal]::IsComObject($Value)) {
    [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($Value)
  }
}

function Find-TaskRow {
  param($Sheet, [string[]]$Task, [int]$LastRow)
  $matches = @(10..$LastRow | Where-Object { $Task -ccontains ([string]$Sheet.Cells.Item($_, 5).Text).Trim() })
  if ($matches.Count -ne 1) { throw "Expected one row for '$($Task -join "' or '")' but found $($matches.Count)." }
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

  $preview = foreach ($update in $updates) {
    $taskNames = @($update.CurrentTask)
    if ($update.NewTask) { $taskNames += $update.NewTask }
    $row = Find-TaskRow -Sheet $schedule -Task $taskNames -LastRow $lastRow
    $startFormula = $update.Start
    if ($update.StartFrom) {
      $predecessorRows = @($update.StartFrom | ForEach-Object { Find-TaskRow -Sheet $schedule -Task $_ -LastRow $lastRow })
      $startFormula = "=WORKDAY(MAX($(@($predecessorRows | ForEach-Object { "K$_" }) -join ',')),1,Holidays!`$C:`$C)"
    }
    [pscustomobject]@{
      Row             = $row
      CurrentTask     = $update.CurrentTask
      NewTask         = $(if ($update.NewTask) { $update.NewTask } else { $update.CurrentTask })
      CurrentStatus   = [string]$schedule.Cells.Item($row, 6).Text
      NewStatus       = $update.Status
      CurrentOwner    = [string]$schedule.Cells.Item($row, 8).Text
      NewOwner        = $(if ($update.Owner) { $update.Owner } else { [string]$schedule.Cells.Item($row, 8).Text })
      CurrentStart    = [string]$schedule.Cells.Item($row, 10).Text
      NewStartFormula = $(if ($startFormula) { $startFormula } else { [string]$schedule.Cells.Item($row, 10).Formula })
      CurrentFinish   = [string]$schedule.Cells.Item($row, 11).Text
      NewDuration     = $(if ($null -ne $update.Duration) { [int]$update.Duration } else { [int]$schedule.Cells.Item($row, 12).Value2 })
    }
  }
  if ($Mode -eq 'Preview') { $preview; return }

  foreach ($item in $preview) {
    $row = [int]$item.Row
    $schedule.Cells.Item($row, 5).Value2 = [string]$item.NewTask
    $schedule.Cells.Item($row, 6).Value2 = [string]$item.NewStatus
    $schedule.Cells.Item($row, 8).Value2 = [string]$item.NewOwner
    $schedule.Cells.Item($row, 9).Formula = [string]('=IF(F{0}="Done",100%,"")' -f $row)
    $schedule.Cells.Item($row, 10).Formula = [string]$item.NewStartFormula
    $schedule.Cells.Item($row, 12).Value2 = [double]$item.NewDuration
    $schedule.Cells.Item($row, 11).Formula = [string]"=WORKDAY(J$row,L$row-1,Holidays!`$C:`$C)"
    $schedule.Cells.Item($row, 13).Formula = [string]"=K$row-J$row+1"
  }

  $excel.CalculateFull()
  $workbook.Save()
  [pscustomobject]@{ Mode = 'Apply'; UpdatedRows = ($preview.Row -join ','); Saved = $workbook.Saved }
}
finally {
  Remove-ComReference $schedule
  if ($null -ne $workbook) { $workbook.Close($false); Remove-ComReference $workbook }
  if ($null -ne $excel) { $excel.Quit(); Remove-ComReference $excel }
  [GC]::Collect()
  [GC]::WaitForPendingFinalizers()
}
