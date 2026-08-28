[CmdletBinding()]
param(
  [ValidateSet('Preview', 'Apply')]
  [string]$Mode = 'Preview',

  [string]$WorkbookUrl = 'https://pgone.sharepoint.com/sites/RTARELEASE/Shared Documents/General/IconDB Integration/Project alignment docs/Icon DB CPS new standard.xlsx'
)

$ErrorActionPreference = 'Stop'

$ruleManagerTasks = [ordered]@{
  'FC NA'  = 'Update Rule Manager icon rules for FC NA using approved production IconDB names/IDs'
  'FC EU'  = 'Update Rule Manager icon rules for FC EU using approved production IconDB names/IDs'
  'OC EU'  = 'Update Rule Manager icon rules for OC EU using approved production IconDB names/IDs'
  'Fem EU' = 'Update Rule Manager icon rules for Fem EU using approved production IconDB names/IDs'
  'LA'     = 'Update Rule Manager icon rules for LA using approved production IconDB names/IDs'
}
$aacTask = '[Recovery R169] Execute AAC E2E using updated Rule Manager references and applicable Trident/SGX path'
$views = @(
  [pscustomobject]@{ Name = 'View - FC NA'; Label = 'Fabric Care North America'; Short = 'FC NA'; Pattern = '(?i)\bFC NA\b'; RuleManagerBusiness = 'FC NA' },
  [pscustomobject]@{ Name = 'View - FC EU'; Label = 'Fabric Care Europe'; Short = 'FC EU'; Pattern = '(?i)\bFC EU\b'; RuleManagerBusiness = 'FC EU' },
  [pscustomobject]@{ Name = 'View - OC EU'; Label = 'Oral Care Europe'; Short = 'OC EU'; Pattern = '(?i)\bOC EU\b'; RuleManagerBusiness = 'OC EU' },
  [pscustomobject]@{ Name = 'View - Fem EU'; Label = 'FemCare Europe'; Short = 'Fem EU'; Pattern = '(?i)\bFEM EU\b|FemCare|Fem Care EU|Rule Manager.*Fem EU'; RuleManagerBusiness = 'Fem EU' },
  [pscustomobject]@{ Name = 'View - LA'; Label = 'Latin America'; Short = 'LA'; Pattern = '(?i)\bLA (HAIR|SPC|Oral|Baby|Fem|IconDB)\b|Latin America|Rule Manager.*\bLA\b'; RuleManagerBusiness = 'LA' },
  [pscustomobject]@{ Name = 'View - AAC'; Label = 'AAC readiness'; Short = 'AAC'; Pattern = '(?i)\bAAC\b|Trident|SGX|Smart PDF|Rule Manager'; RuleManagerBusiness = $null },
  [pscustomobject]@{ Name = 'View - IconDB'; Label = 'IconDB delivery'; Short = 'IconDB'; Pattern = '(?i)IconDB|Icon DB|\bIDB\b|Canvas|Family|Duplicate|Approval|Logging|API readiness|Rule Manager'; RuleManagerBusiness = $null },
  [pscustomobject]@{ Name = 'View - Enovia'; Label = 'Enovia integration'; Short = 'Enovia'; Pattern = '(?i)Enovia|MAE|Integration Type|mapping|routing|Jyoti'; RuleManagerBusiness = $null }
)

function Remove-ComReference {
  param($Value)
  if ($null -ne $Value -and [Runtime.InteropServices.Marshal]::IsComObject($Value)) {
    [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($Value)
  }
}

function Set-Text {
  param($Sheet, [int]$Row, [int]$Column, [AllowEmptyString()][string]$Value)
  $cell = $null
  try {
    $cell = $Sheet.Cells.Item($Row, $Column)
    $cell.NumberFormat = '@'
    $cell.Value2 = [string]$Value
  }
  finally { Remove-ComReference $cell }
}

function Set-Number {
  param($Sheet, [int]$Row, [int]$Column, [double]$Value)
  $cell = $null
  try {
    $cell = $Sheet.Cells.Item($Row, $Column)
    $cell.NumberFormat = '0'
    $cell.Value2 = [double]$Value
  }
  finally { Remove-ComReference $cell }
}

function Set-Formula {
  param($Sheet, [int]$Row, [int]$Column, [string]$Formula)
  $cell = $null
  try {
    $cell = $Sheet.Cells.Item($Row, $Column)
    $cell.Formula = [string]$Formula
  }
  finally { Remove-ComReference $cell }
}

function Get-LastTaskRow {
  param($Sheet)
  $lastRow = [int]($Sheet.UsedRange.Row + $Sheet.UsedRange.Rows.Count - 1)
  while ($lastRow -ge 10 -and -not ([string]$Sheet.Cells.Item($lastRow, 5).Text).Trim()) { $lastRow-- }
  return $lastRow
}

function Find-TaskRow {
  param($Sheet, [string]$Task, [int]$LastRow)
  $matches = @(10..$LastRow | Where-Object { ([string]$Sheet.Cells.Item($_, 5).Text).Trim() -ceq $Task })
  if ($matches.Count -ne 1) { throw "Expected one master task '$Task' but found $($matches.Count)." }
  return [int]$matches[0]
}

function Get-CleanTask {
  param([string]$Task)
  return ($Task -replace '^\[Recovery R\d{3}\]\s*', '').Trim()
}

function Get-Workstream {
  param([string]$Task, [string]$Default)
  if ($Task -match '(?i)LA HAIR') { return 'LA Hair' }
  if ($Task -match '(?i)LA SPC') { return 'LA SPC' }
  if ($Task -match '(?i)LA Oral') { return 'LA Oral' }
  if ($Task -match '(?i)LA Baby') { return 'LA Baby' }
  if ($Task -match '(?i)LA Fem') { return 'LA Fem' }
  if ($Task -match '(?i)Rule Manager') { return 'Rule Manager' }
  return $Default
}

function Get-DependencyText {
  param($Schedule, [int]$Row)
  $formula = [string]$Schedule.Cells.Item($Row, 10).Formula
  $references = @([regex]::Matches($formula, '(?i)K(\d+)') | ForEach-Object { [int]$_.Groups[1].Value } | Select-Object -Unique)
  $labels = foreach ($reference in $references) {
    $task = Get-CleanTask ([string]$Schedule.Cells.Item($reference, 5).Text)
    if ($task) { $task }
  }
  return ($labels -join '; ')
}

function Get-AggregateStatus {
  param([string[]]$Statuses)
  if ($Statuses.Count -gt 0 -and @($Statuses | Where-Object { $_ -cne 'Done' }).Count -eq 0) { return 'Delivered' }
  if (@($Statuses | Where-Object { $_ -ceq 'In Progress' }).Count -gt 0) { return 'In progress' }
  return 'Planned'
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
  $lastRow = Get-LastTaskRow $schedule

  $ruleManagerRows = [ordered]@{}
  foreach ($business in $ruleManagerTasks.Keys) {
    $ruleManagerRows[$business] = Find-TaskRow -Sheet $schedule -Task $ruleManagerTasks[$business] -LastRow $lastRow
  }
  $aacRow = Find-TaskRow -Sheet $schedule -Task $aacTask -LastRow $lastRow

  $timelineSourceStart = 15
  $timelineSourceEnd = 144
  $timelineTargetStart = 11
  $timelineValues = $schedule.Range($schedule.Cells.Item(8, $timelineSourceStart), $schedule.Cells.Item(8, $timelineSourceEnd)).Value2

  $viewRows = @{}
  foreach ($definition in $views) {
    $selected = @()
    for ($row = 10; $row -le $lastRow; $row++) {
      $task = ([string]$schedule.Cells.Item($row, 5).Text).Trim()
      $owner = ([string]$schedule.Cells.Item($row, 8).Text).Trim()
      $status = ([string]$schedule.Cells.Item($row, 6).Text).Trim()
      if (-not $task -or $status -notin @('Done', 'In Progress', 'Not Started')) { continue }
      if ("$task $owner" -match $definition.Pattern) { $selected += $row }
    }
    if ($selected.Count -eq 0) { throw "View selection is empty: $($definition.Name)" }
    $viewRows[$definition.Name] = @($selected | Select-Object -Unique)
  }

  $preview = foreach ($definition in $views) {
    $rows = @($viewRows[$definition.Name])
    $delivered = @($rows | Where-Object { ([string]$schedule.Cells.Item($_, 6).Text).Trim() -ceq 'Done' })
    $current = @($rows | Where-Object { ([string]$schedule.Cells.Item($_, 6).Text).Trim() -cne 'Done' })
    [pscustomobject]@{
      View           = $definition.Name
      DeliveredRows  = $delivered.Count
      CurrentRows    = $current.Count
      RuleManagerRow = $(if ($definition.RuleManagerBusiness) { $ruleManagerRows[$definition.RuleManagerBusiness] } else { '' })
    }
  }
  if ($Mode -eq 'Preview') { $preview; return }

  $legacyBuView = $null
  try { $legacyBuView = $workbook.Worksheets.Item('View - BU') } catch { $legacyBuView = $null }
  if ($null -ne $legacyBuView) { $legacyBuView.Delete(); Remove-ComReference $legacyBuView }

  foreach ($definition in $views) {
    $view = $null
    try { $view = $workbook.Worksheets.Item($definition.Name) } catch { $view = $workbook.Worksheets.Add(); $view.Name = $definition.Name }
    [void]$view.Cells.Clear()
    [void]$view.Range('A1:G1').Merge()
    Set-Text $view 1 1 "$($definition.Label) - delivered outcomes and current plan"
    [void]$view.Range('A2:G2').Merge()
    Set-Text $view 2 1 'This view is generated from Project schedule. Update owners, status, dates, and dependencies only in the master.'
    [void]$view.Range('A3:G3').Merge()
    Set-Text $view 3 1 'Historical late baselines remain in Project schedule and are intentionally excluded here.'
    $headers = @('Workstream', 'Outcome / action', 'Owner', 'Status', 'Start', 'Finish', 'Depends on / next gate')
    for ($column = 1; $column -le $headers.Count; $column++) { Set-Text $view 5 $column $headers[$column - 1] }
    Set-Text $view 5 8 'CPS row'
    Set-Text $view 5 9 'Plan type'
    Set-Text $view 5 10 'Business days'

    $viewRow = 6
    $ganttItems = @()
    foreach ($section in @('Delivered', 'Current plan')) {
      $sectionRows = if ($section -eq 'Delivered') {
        @($viewRows[$definition.Name] | Where-Object { ([string]$schedule.Cells.Item($_, 6).Text).Trim() -ceq 'Done' })
      }
      else {
        @($viewRows[$definition.Name] | Where-Object { ([string]$schedule.Cells.Item($_, 6).Text).Trim() -cne 'Done' })
      }
      [void]$view.Range("A${viewRow}:G${viewRow}").Merge()
      Set-Text $view $viewRow 1 $section
      $view.Range("A${viewRow}:G${viewRow}").Font.Bold = $true
      $view.Range("A${viewRow}:G${viewRow}").Interior.Color = $(if ($section -eq 'Delivered') { 13434828 } else { 14277081 })
      $viewRow++
      foreach ($masterRow in $sectionRows) {
        $task = Get-CleanTask ([string]$schedule.Cells.Item($masterRow, 5).Text)
        Set-Text $view $viewRow 1 (Get-Workstream -Task $task -Default $definition.Short)
        Set-Formula $view $viewRow 2 "=IF(LEFT('Project schedule'!E$masterRow,10)=`"[Recovery `",MID('Project schedule'!E$masterRow,FIND(`"] `",'Project schedule'!E$masterRow)+2,999),'Project schedule'!E$masterRow)"
        Set-Formula $view $viewRow 3 "='Project schedule'!H$masterRow"
        Set-Formula $view $viewRow 4 "='Project schedule'!F$masterRow"
        Set-Formula $view $viewRow 5 "='Project schedule'!J$masterRow"
        Set-Formula $view $viewRow 6 "='Project schedule'!K$masterRow"
        Set-Text $view $viewRow 7 (Get-DependencyText -Schedule $schedule -Row $masterRow)
        Set-Text $view $viewRow 8 ([string]$masterRow)
        Set-Text $view $viewRow 9 $section
        Set-Formula $view $viewRow 10 "='Project schedule'!L$masterRow"
        $ganttItems += [pscustomobject]@{ ViewRow = $viewRow; MasterRow = $masterRow }
        $viewRow++
      }
    }

    for ($offset = 0; $offset -le ($timelineSourceEnd - $timelineSourceStart); $offset++) {
      $sourceColumn = $timelineSourceStart + $offset
      $targetColumn = $timelineTargetStart + $offset
      $sourceAddress = [string]$schedule.Cells.Item(8, $sourceColumn).Address($false, $false)
      Set-Formula $view 4 $targetColumn "='Project schedule'!$sourceAddress"
      Set-Formula $view 5 $targetColumn "='Project schedule'!$sourceAddress"
    }
    $taskLastRow = $viewRow - 1
    $timelineLastColumn = $timelineTargetStart + ($timelineSourceEnd - $timelineSourceStart)
    $timelineLastLetter = ([string]$view.Cells.Item(1, $timelineLastColumn).Address($false, $false)) -replace '\d', ''
    foreach ($item in $ganttItems) {
      $startValue = $schedule.Cells.Item($item.MasterRow, 10).Value2
      $finishValue = $schedule.Cells.Item($item.MasterRow, 11).Value2
      $statusValue = [string]$schedule.Cells.Item($item.MasterRow, 6).Text
      if ($startValue -is [double] -and $finishValue -is [double]) {
        $firstOffset = $null
        $lastOffset = $null
        for ($offset = 1; $offset -le $timelineValues.GetLength(1); $offset++) {
          $timelineValue = $timelineValues[1, $offset]
          if ($timelineValue -is [double] -and $timelineValue -ge $startValue -and $timelineValue -le $finishValue) {
            if ($null -eq $firstOffset) { $firstOffset = $offset - 1 }
            $lastOffset = $offset - 1
          }
        }
        if ($null -ne $firstOffset) {
          $fillStart = $view.Cells.Item($item.ViewRow, $timelineTargetStart + $firstOffset)
          $fillEnd = $view.Cells.Item($item.ViewRow, $timelineTargetStart + $lastOffset)
          $view.Range($fillStart, $fillEnd).Interior.Color = $(if ($statusValue -eq 'Done') { 10079487 } else { 14277081 })
          Remove-ComReference $fillEnd
          Remove-ComReference $fillStart
        }
      }
    }

    $view.Range("A1:${timelineLastLetter}1").Interior.Color = 6569237
    $view.Range('A1').Font.Color = 16777215
    $view.Range('A1').Font.Bold = $true
    $view.Range('A1').Font.Size = 14
    $view.Range('A5:G5').Font.Bold = $true
    $view.Range('A5:G5').Interior.Color = 14277081
    $view.Range("E6:F$taskLastRow").NumberFormat = 'dd-mmm-yy'
    $view.Range("K4:${timelineLastLetter}5").NumberFormat = 'dd-mmm'
    $view.Range("A5:${timelineLastLetter}$taskLastRow").Borders.LineStyle = 1
    $view.Range("A1:G$taskLastRow").WrapText = $true
    $view.Range('A:A').ColumnWidth = 19
    $view.Range('B:B').ColumnWidth = 52
    $view.Range('C:C').ColumnWidth = 30
    $view.Range('D:D').ColumnWidth = 14
    $view.Range('E:F').ColumnWidth = 12
    $view.Range('G:G').ColumnWidth = 55
    $view.Range("K:${timelineLastLetter}").ColumnWidth = 4.2
    $view.Range('H:J').EntireColumn.Hidden = $true
    $view.Activate()
    $excel.ActiveWindow.FreezePanes = $false
    $excel.ActiveWindow.SplitRow = 5
    $excel.ActiveWindow.SplitColumn = 7
    $excel.ActiveWindow.FreezePanes = $true
    Remove-ComReference $view
  }

  $start = $null
  try { $start = $workbook.Worksheets.Item('Start') } catch { $start = $workbook.Worksheets.Add($workbook.Worksheets.Item(1)); $start.Name = 'Start' }
  [void]$start.Cells.Clear()
  $existingCharts = $start.ChartObjects()
  for ($chartIndex = $existingCharts.Count; $chartIndex -ge 1; $chartIndex--) { $existingCharts.Item($chartIndex).Delete() }
  Remove-ComReference $existingCharts
  [void]$start.Range('A1:F1').Merge()
  Set-Text $start 1 1 'IconDB activation overview'
  [void]$start.Range('A2:F2').Merge()
  Set-Text $start 2 1 'Open a consistent business view or review delivered and current actions by stream.'
  $dashboardHeaders = @('Business / stream', 'Delivered actions', 'Current actions', 'Rule Manager', 'AAC test', 'Open view')
  for ($column = 1; $column -le $dashboardHeaders.Count; $column++) { Set-Text $start 4 $column $dashboardHeaders[$column - 1] }

  $aacStatus = ([string]$schedule.Cells.Item($aacRow, 6).Text).Trim()
  $dashboardRow = 5
  foreach ($definition in $views) {
    $rows = @($viewRows[$definition.Name])
    $deliveredRows = @($rows | Where-Object { ([string]$schedule.Cells.Item($_, 6).Text).Trim() -ceq 'Done' })
    $currentRows = @($rows | Where-Object { ([string]$schedule.Cells.Item($_, 6).Text).Trim() -cne 'Done' })
    $ruleStatus = if ($definition.RuleManagerBusiness) {
      ([string]$schedule.Cells.Item($ruleManagerRows[$definition.RuleManagerBusiness], 6).Text).Trim()
    }
    elseif ($definition.Short -in @('AAC', 'IconDB')) {
      Get-AggregateStatus @($ruleManagerRows.Values | ForEach-Object { ([string]$schedule.Cells.Item($_, 6).Text).Trim() })
    }
    else { 'Not applicable' }
    Set-Text $start $dashboardRow 1 $definition.Label
    Set-Number $start $dashboardRow 2 $deliveredRows.Count
    Set-Number $start $dashboardRow 3 $currentRows.Count
    Set-Text $start $dashboardRow 4 $ruleStatus
    Set-Text $start $dashboardRow 5 $(if ($definition.Short -in @('AAC', 'IconDB') -or $definition.RuleManagerBusiness) { $aacStatus } else { 'Not applicable' })
    $anchor = $start.Cells.Item($dashboardRow, 6)
    $hyperlink = $start.Hyperlinks.Add($anchor, '', "'$($definition.Name)'!A1", "Open $($definition.Label)", "Open $($definition.Short) view")
    Remove-ComReference $hyperlink
    Remove-ComReference $anchor
    $dashboardRow++
  }

  $chartObjects = $start.ChartObjects()
  $chartObject = $chartObjects.Add(20, 260, 720, 300)
  $chart = $chartObject.Chart
  $chart.ChartType = 51
  $seriesCollection = $chart.SeriesCollection()
  $series = $seriesCollection.NewSeries()
  $series.Name = 'Delivered actions'
  $series.XValues = $start.Range("A5:A$($dashboardRow - 1)")
  $series.Values = $start.Range("B5:B$($dashboardRow - 1)")
  $chart.PlotVisibleOnly = $true
  $chart.HasTitle = $true
  $chart.ChartTitle.Text = 'Delivered actions by business view'
  $chart.HasLegend = $false
  Remove-ComReference $series
  Remove-ComReference $seriesCollection
  Remove-ComReference $chart
  Remove-ComReference $chartObject
  Remove-ComReference $chartObjects

  $start.Range('A1:F1').Interior.Color = 6569237
  $start.Range('A1').Font.Color = 16777215
  $start.Range('A1').Font.Bold = $true
  $start.Range('A1').Font.Size = 18
  $start.Range('A4:F4').Font.Bold = $true
  $start.Range('A4:F4').Interior.Color = 14277081
  $start.Range("A4:F$($dashboardRow - 1)").Borders.LineStyle = 1
  $start.Range("A5:F$($dashboardRow - 1)").HorizontalAlignment = -4108
  $start.Range('A:A').ColumnWidth = 30
  $start.Range('B:C').ColumnWidth = 16
  $start.Range('D:E').ColumnWidth = 18
  $start.Range('F:F').ColumnWidth = 22
  $start.Range("A1:F$($dashboardRow - 1)").WrapText = $true
  $firstSheet = $workbook.Worksheets.Item(1)
  if ([string]$firstSheet.Name -cne 'Start') {
    $start.Move($firstSheet)
    Remove-ComReference $start
    $start = $workbook.Worksheets.Item('Start')
  }
  $firstSheet = $null
  $start.Activate()
  $excel.CalculateFull()
  $workbook.Save()
  [pscustomobject]@{ Mode = 'Apply'; Dashboard = 'Start'; Views = @($views.Name); Saved = $workbook.Saved }
}
finally {
  Remove-ComReference $schedule
  if ($null -ne $workbook) { $workbook.Close($false); Remove-ComReference $workbook }
  if ($null -ne $excel) { $excel.Quit(); Remove-ComReference $excel }
  [GC]::Collect()
  [GC]::WaitForPendingFinalizers()
}
