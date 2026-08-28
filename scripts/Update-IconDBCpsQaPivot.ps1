[CmdletBinding()]
param(
  [ValidateSet('Preview', 'Apply')]
  [string]$Mode = 'Preview',

  [string]$WorkbookUrl = 'https://pgone.sharepoint.com/sites/RTARELEASE/Shared Documents/General/IconDB Integration/Project alignment docs/Icon DB CPS new standard.xlsx'
)

$ErrorActionPreference = 'Stop'

$expectedTasks = @(
  'Send one correct FemCare SIT JSON payload to Jyoti for immediate analysis',
  'Analyze FemCare SIT payload and identify Enovia fixes for the September change window',
  'Complete FemCare SIT validation before current Enovia SIT decommission',
  'Switch IconDB endpoint from Enovia SIT to Enovia QA after SIT validation',
  'Start FemCare testing in Enovia QA after the IconDB endpoint switch',
  'Prepare Enovia SIT decommission, new-SIT migration, and IconDB QA resynchronization process',
  'Confirm exact new Enovia SIT availability and production-copy migration schedule'
)

$updates = @(
  [pscustomobject]@{
    Row          = 220
    Task         = 'Send representative IconDB payload to Jyoti and receive Enovia response'
    Status       = 'Done'
    Owner        = 'Michal / Steve / Jyoti'
    Duration     = 1
    StartFormula = '=WORKDAY(DATE(2026,8,12),0,Holidays!$C:$C)'
  },
  [pscustomobject]@{
    Row          = 221
    Task         = 'Record Enovia deployment, refresh, cleanup, and mapping constraints from Jyoti response'
    Status       = 'Done'
    Owner        = 'Michal / Jyoti'
    Duration     = 1
    StartFormula = '=WORKDAY(DATE(2026,8,13),0,Holidays!$C:$C)'
  },
  [pscustomobject]@{
    Row          = 222
    Task         = 'Confirm QA-first FemCare scope, sample, sign-off owner, and EECAR handling'
    Status       = 'Not Started'
    Owner        = 'Tommy / Steve / Jyoti / FemCare'
    Duration     = 5
    StartFormula = '=WORKDAY(DATE(2026,8,18),0,Holidays!$C:$C)'
  },
  [pscustomobject]@{
    Row          = 223
    Task         = 'Confirm Enovia QA deployment, refresh/baseline, reconciliation, and sole endpoint switch'
    Status       = 'Not Started'
    Owner        = 'Jyoti / Tommy / Steve'
    Duration     = 1
    StartFormula = '=WORKDAY(MAX(K222,K225,DATE(2026,8,31)),1,Holidays!$C:$C)'
  },
  [pscustomobject]@{
    Row          = 224
    Task         = 'Execute controlled FemCare validation in Enovia QA and obtain business sign-off'
    Status       = 'Not Started'
    Owner        = 'Michal / FemCare / Jyoti / Steve / Tommy'
    Duration     = 4
    StartFormula = '=WORKDAY(K223,1,Holidays!$C:$C)'
  },
  [pscustomobject]@{
    Row          = 225
    Task         = 'Prepare QA clean-state inventory, rollback, and post-refresh resynchronization process'
    Status       = 'Not Started'
    Owner        = 'Tommy / Steve / Jyoti / Michal'
    Duration     = 8
    StartFormula = '=WORKDAY(DATE(2026,8,18),0,Holidays!$C:$C)'
  },
  [pscustomobject]@{
    Row          = 226
    Task         = 'Record confirmed SIT refresh 31 Aug, production cutoff 28 Aug, and SIT return 14 Sep'
    Status       = 'Done'
    Owner        = 'Jyoti / Enovia team'
    Duration     = 1
    StartFormula = '=WORKDAY(DATE(2026,8,13),0,Holidays!$C:$C)'
  }
)

function Clear-ComReference {
  param($Value)
  if ($null -ne $Value -and [Runtime.InteropServices.Marshal]::IsComObject($Value)) {
    [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($Value)
  }
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
  for ($index = 0; $index -lt $expectedTasks.Count; $index++) {
    $row = 220 + $index
    $actualTask = ([string]$schedule.Cells.Item($row, 5).Text).Trim()
    if ($actualTask -cne $expectedTasks[$index]) {
      throw "Master drift at row $row. Expected '$($expectedTasks[$index])'; found '$actualTask'."
    }
  }

  if ($Mode -eq 'Preview') {
    $updates | Select-Object Row, Task, Status, Owner, Duration, StartFormula
    return
  }

  foreach ($update in $updates) {
    $row = $update.Row
    $schedule.Cells.Item($row, 5).Value2 = [string]$update.Task
    $schedule.Cells.Item($row, 6).Value2 = [string]$update.Status
    $schedule.Cells.Item($row, 8).Value2 = [string]$update.Owner
    $schedule.Cells.Item($row, 9).Formula = [string]"=IF(F$row=`"Done`",100%,`"`" )"
    $schedule.Cells.Item($row, 10).Formula = [string]$update.StartFormula
    $schedule.Cells.Item($row, 11).Formula = [string]"=WORKDAY(J$row,L$row-1,Holidays!`$C:`$C)"
    $schedule.Cells.Item($row, 12).Value2 = [double]$update.Duration
    $schedule.Cells.Item($row, 13).Formula = [string]"=K$row-J$row+1"
  }

  $excel.CalculateFull()
  $workbook.Save()
  $updates | Select-Object Row, Task, Status, Owner
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
