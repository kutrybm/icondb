[CmdletBinding()]
param(
  [ValidateSet('Preview', 'Apply')]
  [string]$Mode = 'Preview',

  [string]$WorkbookUrl = 'https://pgone.sharepoint.com/sites/RTARELEASE/Shared Documents/General/IconDB Integration/Project alignment docs/Icon DB CPS new standard.xlsx',

  [datetime]$RecoveryAsOf = [datetime]'2026-08-11'
)

$ErrorActionPreference = 'Stop'

$dependencyMap = @{
  56 = @(); 57 = @(56); 58 = @(57)
  79 = @(); 80 = @(79); 81 = @(80); 82 = @(81)
  83 = @(79); 84 = @(83); 85 = @(84)
  86 = @(79); 87 = @(86); 88 = @(87)
  89 = @(); 90 = @(89); 91 = @(90)
  98 = @(79); 99 = @(98); 100 = @(99)
  101 = @(79); 102 = @(101); 103 = @(102)
  104 = @(100); 105 = @(104); 106 = @(105)
  115 = @(); 116 = @(); 117 = @(116); 118 = @(117)
  119 = @(); 120 = @(119); 121 = @(120)
  122 = @(121); 123 = @(122); 124 = @(123)
  134 = @()
  168 = @(134); 169 = @(134); 172 = @(168, 169); 177 = @(172)
  181 = @(); 184 = @(181); 185 = @(184); 189 = @()
  211 = @(); 212 = @(211)
  215 = @(); 216 = @(215); 217 = @(216); 218 = @(217)
  221 = @(218); 222 = @(221)
  231 = @(); 232 = @(231); 233 = @(232); 236 = @(233)
  245 = @(); 246 = @(245); 247 = @(246); 248 = @(247)
  249 = @(248); 252 = @(249); 253 = @(252); 254 = @(253)
  259 = @(); 304 = @(185, 222, 236, 254); 320 = @(185, 222, 236, 254)
}

$durationOverrides = @{
  177 = 5
  215 = 10
}

function Get-BusinessDayCount {
  param([datetime]$Start, [datetime]$End, [System.Collections.Generic.HashSet[string]]$Holidays)

  $count = 0
  for ($date = $Start.Date; $date -le $End.Date; $date = $date.AddDays(1)) {
    if ($date.DayOfWeek -in @([DayOfWeek]::Saturday, [DayOfWeek]::Sunday)) { continue }
    if ($Holidays.Contains($date.ToString('yyyy-MM-dd'))) { continue }
    $count++
  }
  return [Math]::Max(1, $count)
}

function Release-ComObject {
  param($Value)
  if ($null -ne $Value -and [Runtime.InteropServices.Marshal]::IsComObject($Value)) {
    [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($Value)
  }
}

$excel = New-Object -ComObject Excel.Application
$excel.Visible = $false
$excel.DisplayAlerts = $false
$workbook = $null
$schedule = $null
$holidaySheet = $null

try {
  $workbook = $excel.Workbooks.Open($WorkbookUrl, 0, ($Mode -eq 'Preview'))
  if ($Mode -eq 'Apply' -and $workbook.ReadOnly) {
    throw 'The authoritative workbook opened read-only; no changes were made.'
  }

  $schedule = $workbook.Worksheets.Item('Project schedule')
  $holidaySheet = $workbook.Worksheets.Item('Holidays')
  $lastRow = $schedule.UsedRange.Row + $schedule.UsedRange.Rows.Count - 1
  $existingRecoveries = @(
    10..$lastRow | Where-Object { [string]$schedule.Cells.Item($_, 5).Text -match '^\[Recovery R\d{3}\] ' }
  )
  if ($existingRecoveries.Count -gt 0) {
    throw "Recovery rows already exist at rows $($existingRecoveries -join ', '); refusing to insert duplicates."
  }

  $lateRows = @(
    10..$lastRow | Where-Object {
      ([string]$schedule.Cells.Item($_, 6).Text).Trim() -ieq 'Late' -and
      [string]$schedule.Cells.Item($_, 5).Text -notmatch '^\[Recovery '
    }
  )
  $mappedRows = @($dependencyMap.Keys | ForEach-Object { [int]$_ } | Sort-Object)
  $unmapped = @($lateRows | Where-Object { $_ -notin $mappedRows })
  $notLate = @($mappedRows | Where-Object { $_ -notin $lateRows })
  if ($unmapped.Count -gt 0 -or $notLate.Count -gt 0) {
    throw "Late-task map mismatch. Unmapped late rows: $($unmapped -join ', '); mapped rows no longer late: $($notLate -join ', ')."
  }

  $holidayDates = [System.Collections.Generic.HashSet[string]]::new()
  $holidayLastRow = $holidaySheet.UsedRange.Row + $holidaySheet.UsedRange.Rows.Count - 1
  for ($row = 1; $row -le $holidayLastRow; $row++) {
    $value = $holidaySheet.Cells.Item($row, 3).Value2
    if ($value -is [double]) {
      [void]$holidayDates.Add([datetime]::FromOADate($value).ToString('yyyy-MM-dd'))
    }
  }
  if ($holidayDates.Count -eq 0) { throw 'No holiday dates were found in Holidays column C.' }

  $finalRecoveryRows = @{}
  for ($index = 0; $index -lt $mappedRows.Count; $index++) {
    $sourceRow = $mappedRows[$index]
    $finalRecoveryRows[$sourceRow] = $sourceRow + $index + 1
  }

  $plan = foreach ($sourceRow in $mappedRows) {
    $task = ([string]$schedule.Cells.Item($sourceRow, 5).Text).Trim()
    $startValue = $schedule.Cells.Item($sourceRow, 10).Value2
    $endValue = $schedule.Cells.Item($sourceRow, 11).Value2
    if ($startValue -isnot [double] -or $endValue -isnot [double]) {
      throw "Late source row $sourceRow has invalid start or end dates."
    }
    $duration = Get-BusinessDayCount -Start ([datetime]::FromOADate($startValue)) `
      -End ([datetime]::FromOADate($endValue)) -Holidays $holidayDates
    if ($durationOverrides.ContainsKey($sourceRow)) {
      $duration = $durationOverrides[$sourceRow]
    }
    $predecessors = @($dependencyMap[$sourceRow])
    $targetRow = $finalRecoveryRows[$sourceRow]
    $startFormula = if ($predecessors.Count -eq 0) {
      "=WORKDAY(DATE($($RecoveryAsOf.Year),$($RecoveryAsOf.Month),$($RecoveryAsOf.Day)),1,Holidays!`$C:`$C)"
    }
    else {
      $endCells = @($predecessors | ForEach-Object { "K$($finalRecoveryRows[[int]$_])" })
      "=WORKDAY(MAX($($endCells -join ',')),1,Holidays!`$C:`$C)"
    }
    [pscustomobject]@{
      SourceRow    = $sourceRow
      TargetRow    = $targetRow
      RecoveryId   = ('R{0:D3}' -f $sourceRow)
      Task         = $task
      Duration     = $duration
      Predecessors = ($predecessors | ForEach-Object { 'R{0:D3}' -f $_ }) -join ';'
      StartFormula = $startFormula
      EndFormula   = "=WORKDAY(J$targetRow,L$targetRow-1,Holidays!`$C:`$C)"
    }
  }

  if ($Mode -eq 'Preview') {
    $plan | Select-Object RecoveryId, SourceRow, TargetRow, Duration, Predecessors, Task,
    StartFormula, EndFormula
    return
  }

  foreach ($item in @($plan | Sort-Object SourceRow -Descending)) {
    $insertRow = $item.SourceRow + 1
    [void]$schedule.Rows.Item($insertRow).Insert()
    [void]$schedule.Range("A$($item.SourceRow)").Copy($schedule.Range("A$insertRow"))
    [void]$schedule.Range("C$($item.SourceRow):FA$($item.SourceRow)").Copy(
      $schedule.Range("C$insertRow:FA$insertRow")
    )
  }

  foreach ($item in $plan) {
    $row = $item.TargetRow
    $schedule.Cells.Item($row, 5).Value2 = "[Recovery $($item.RecoveryId)] $($item.Task)"
    $schedule.Cells.Item($row, 6).Value2 = 'Not Started'
    $schedule.Cells.Item($row, 9).Formula = "=IF(F$row=`"Done`",100%,`"`")"
    $schedule.Cells.Item($row, 10).Formula = $item.StartFormula
    $schedule.Cells.Item($row, 11).Formula = $item.EndFormula
    $schedule.Cells.Item($row, 12).Value2 = $item.Duration
    $schedule.Cells.Item($row, 13).Formula = "=K$row-J$row+1"
  }

  $excel.CalculateFull()
  $workbook.Save()
  $plan | Select-Object RecoveryId, SourceRow, TargetRow, Duration, Predecessors, Task,
  StartFormula, EndFormula
}
finally {
  if ($null -ne $workbook) { $workbook.Close($false) }
  Release-ComObject $holidaySheet
  Release-ComObject $schedule
  Release-ComObject $workbook
  $excel.Quit()
  Release-ComObject $excel
  [GC]::Collect()
  [GC]::WaitForPendingFinalizers()
}
