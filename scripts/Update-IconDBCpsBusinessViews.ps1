[CmdletBinding()]
param(
  [ValidateSet('Preview', 'Apply')]
  [string]$Mode = 'Preview',

  [string]$WorkbookUrl = 'https://pgone.sharepoint.com/sites/RTARELEASE/Shared Documents/General/IconDB Integration/Project alignment docs/Icon DB CPS new standard.xlsx'
)

& (Join-Path $PSScriptRoot 'Update-IconDBCpsBusinessViewsCore.ps1') @PSBoundParameters
return

$ErrorActionPreference = 'Stop'

$sharedPlanRows = @(205, 207)
$views = @(
  [pscustomobject]@{
    Name = 'View - FC NA'; Label = 'Fabric Care North America'; Short = 'FC NA'
    Delivered = @(193, 194, 198, 232, 233, 261, 262, 263)
    Planned = @(231, 265, 235, 237, 267) + $sharedPlanRows
    Groups = @{}
  },
  [pscustomobject]@{
    Name = 'View - FC EU'; Label = 'Fabric Care Europe'; Short = 'FC EU'
    Delivered = @(269, 278, 279)
    Planned = @(271, 277, 273, 281, 283, 275) + $sharedPlanRows
    Groups = @{}
  },
  [pscustomobject]@{
    Name = 'View - OC EU'; Label = 'Oral Care Europe'; Short = 'OC EU'
    Delivered = @(285, 288, 289, 290, 291, 298, 299)
    Planned = @(293, 297, 301, 302, 303) + $sharedPlanRows
    Groups = @{}
  },
  [pscustomobject]@{
    Name = 'View - Fem EU'; Label = 'FemCare Europe'; Short = 'Fem EU'
    Delivered = @(305, 308, 309, 320, 321)
    Planned = @(222, 224, 227, 228) + $sharedPlanRows
    Groups = @{}
  },
  [pscustomobject]@{
    Name = 'View - LA'; Label = 'Latin America'; Short = 'LA'
    Delivered = @(329, 346, 349, 362, 365)
    Planned = @(379, 334, 335, 336, 337, 341, 342, 343, 350, 351, 352, 353, 357, 358, 359, 366, 367, 368, 369, 373, 374, 375, 383, 384, 385, 386, 390, 391, 392) + $sharedPlanRows
    Groups = @{
      329 = 'LA Hair'; 334 = 'LA Hair'; 335 = 'LA Hair'; 336 = 'LA Hair'; 337 = 'LA Hair'; 341 = 'LA Hair'; 342 = 'LA Hair'; 343 = 'LA Hair'
      346 = 'LA SPC'; 349 = 'LA SPC'; 350 = 'LA SPC'; 351 = 'LA SPC'; 352 = 'LA SPC'; 353 = 'LA SPC'; 357 = 'LA SPC'; 358 = 'LA SPC'; 359 = 'LA SPC'
      362 = 'LA Oral'; 365 = 'LA Oral'; 366 = 'LA Oral'; 367 = 'LA Oral'; 368 = 'LA Oral'; 369 = 'LA Oral'; 373 = 'LA Oral'; 374 = 'LA Oral'; 375 = 'LA Oral'
      379 = 'LA Transformation'; 383 = 'LA Baby'; 384 = 'LA Baby'; 385 = 'LA Baby'; 386 = 'LA Baby'; 390 = 'LA Baby'; 391 = 'LA Baby'; 392 = 'LA Baby'
      205 = 'Shared AAC gate'; 207 = 'Shared AAC gate'
    }
  },
  [pscustomobject]@{
    Name = 'View - AAC'; Label = 'AAC readiness'; Short = 'AAC'
    Delivered = @(11, 161, 166, 168, 179, 213, 214, 215)
    Planned = @(170, 228, 205, 207, 211, 217)
    Groups = @{}
  }
)

$expectedTasks = @{
  205 = '[Recovery R168] Update Rule Manager icon rules for each BU after approved production icons; required before AAC testing'
  207 = '[Recovery R169] Execute AAC E2E using updated Rule Manager references and applicable Trident/SGX path'
  379 = '[Recovery R304] Realign the LA IconDB plan with the Transformation Team and schedule the leadership session'
}

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

function Set-Formula {
  param($Sheet, [int]$Row, [int]$Column, [string]$Formula)
  $cell = $null
  try {
    $cell = $Sheet.Cells.Item($Row, $Column)
    $cell.Formula = [string]$Formula
  }
  finally { Remove-ComReference $cell }
}

function Get-CleanTask {
  param([string]$Task)
  return ($Task -replace '^\[Recovery R\d{3}\]\s*', '').Trim()
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

function Get-MilestoneStatus {
  param($Schedule, [int[]]$Rows)
  $statuses = @($Rows | ForEach-Object { ([string]$Schedule.Cells.Item($_, 6).Text).Trim() })
  if ($statuses.Count -gt 0 -and @($statuses | Where-Object { $_ -ine 'Done' }).Count -eq 0) { return 'Delivered' }
  if (@($statuses | Where-Object { $_ -ieq 'In Progress' }).Count -gt 0) { return 'In progress' }
  if (@($statuses | Where-Object { $_ -ieq 'Done' }).Count -gt 0) { return 'Partially delivered' }
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
  if ($Mode -eq 'Apply' -and $workbook.ReadOnly) { throw 'The authoritative workbook opened read-only.' }
  $schedule = $workbook.Worksheets.Item('Project schedule')

  foreach ($entry in $expectedTasks.GetEnumerator()) {
    $actual = ([string]$schedule.Cells.Item([int]$entry.Key, 5).Text).Trim()
    if ($actual -cne [string]$entry.Value) {
      throw "CPS structural drift at row $($entry.Key). Expected '$($entry.Value)' but found '$actual'."
    }
  }

  $preview = foreach ($definition in $views) {
    [pscustomobject]@{
      View           = $definition.Name
      DeliveredRows  = $definition.Delivered.Count
      PlannedRows    = $definition.Planned.Count
      RuleManagerRow = ($definition.Planned -contains 205)
      AacTestRow     = ($definition.Planned -contains 207)
    }
  }
  if ($Mode -eq 'Preview') { $preview; return }

  $legacyBuView = $null
  try { $legacyBuView = $workbook.Worksheets.Item('View - BU') } catch { $legacyBuView = $null }
  if ($null -ne $legacyBuView) {
    $legacyBuView.Delete()
    Remove-ComReference $legacyBuView
  }

  foreach ($definition in $views) {
    $view = $null
    try { $view = $workbook.Worksheets.Item($definition.Name) } catch { $view = $workbook.Worksheets.Add(); $view.Name = $definition.Name }
    [void]$view.Cells.Clear()

    [void]$view.Range('A1:G1').Merge()
    Set-Text $view 1 1 "$($definition.Label) - delivered outcomes and current plan"
    [void]$view.Range('A2:G2').Merge()
    Set-Text $view 2 1 'This view shows completed outcomes and the current approved plan. Historical late baselines remain available in Project schedule.'
    [void]$view.Range('A3:G3').Merge()
    Set-Text $view 3 1 'Rule Manager icon rules must be updated after approved production icons are available; AAC testing depends on that update.'

    $headers = @('Workstream', 'Outcome / action', 'Owner', 'Status', 'Start', 'Finish', 'Depends on / next gate')
    for ($column = 1; $column -le $headers.Count; $column++) { Set-Text $view 5 $column $headers[$column - 1] }
    Set-Text $view 5 8 'CPS row'
    Set-Text $view 5 9 'Plan type'
    Set-Text $view 5 10 'Business days'

    $viewRow = 6
    foreach ($section in @('Delivered', 'Current plan')) {
      $rows = if ($section -eq 'Delivered') { @($definition.Delivered) } else { @($definition.Planned) }
      [void]$view.Range("A${viewRow}:G${viewRow}").Merge()
      Set-Text $view $viewRow 1 $section
      $view.Range("A${viewRow}:G${viewRow}").Font.Bold = $true
      $view.Range("A${viewRow}:G${viewRow}").Interior.Color = $(if ($section -eq 'Delivered') { 13434828 } else { 14277081 })
      $viewRow++

      foreach ($masterRow in $rows) {
        $task = Get-CleanTask ([string]$schedule.Cells.Item($masterRow, 5).Text)
        $group = if ($definition.Groups.ContainsKey($masterRow)) { [string]$definition.Groups[$masterRow] } elseif ($masterRow -in $sharedPlanRows) { 'Shared AAC gate' } else { $definition.Short }
        Set-Text $view $viewRow 1 $group
        Set-Formula $view $viewRow 2 "=IF(LEFT('Project schedule'!E$masterRow,10)=`"[Recovery `",MID('Project schedule'!E$masterRow,FIND(`"] `",'Project schedule'!E$masterRow)+2,999),'Project schedule'!E$masterRow)"
        Set-Formula $view $viewRow 3 "='Project schedule'!H$masterRow"
        Set-Formula $view $viewRow 4 "='Project schedule'!F$masterRow"
        Set-Formula $view $viewRow 5 "='Project schedule'!J$masterRow"
        Set-Formula $view $viewRow 6 "='Project schedule'!K$masterRow"
        Set-Text $view $viewRow 7 $(if ($masterRow -eq 205) { 'Required before AAC test below.' } elseif ($masterRow -eq 207) { 'Starts only after Rule Manager icon rules are updated.' } else { Get-DependencyText $schedule $masterRow })
        Set-Text $view $viewRow 8 ([string]$masterRow)
        Set-Text $view $viewRow 9 $section
        Set-Formula $view $viewRow 10 "='Project schedule'!L$masterRow"
        if ($definition.Name -eq 'View - LA') {
          $groupColor = switch ($group) {
            'LA Hair' { 15921906 }
            'LA SPC' { 14277081 }
            'LA Oral' { 13434828 }
            'LA Baby' { 14348258 }
            'LA Transformation' { 10092543 }
            'Shared AAC gate' { 15132390 }
            default { 16777215 }
          }
          $view.Range("A${viewRow}:G${viewRow}").Interior.Color = $groupColor
        }
        $viewRow++
      }
    }

    $timelineSourceStart = 15
    $timelineSourceEnd = 144
    $timelineTargetStart = 11
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
    for ($ganttRow = 6; $ganttRow -le $taskLastRow; $ganttRow++) {
      $startValue = $view.Cells.Item($ganttRow, 5).Value2
      $finishValue = $view.Cells.Item($ganttRow, 6).Value2
      $statusValue = [string]$view.Cells.Item($ganttRow, 4).Text
      if ($startValue -is [double] -and $finishValue -is [double]) {
        for ($ganttColumn = $timelineTargetStart; $ganttColumn -le $timelineLastColumn; $ganttColumn++) {
          $timelineValue = $view.Cells.Item(5, $ganttColumn).Value2
          if ($timelineValue -is [double] -and $timelineValue -ge $startValue -and $timelineValue -le $finishValue) {
            $view.Cells.Item($ganttRow, $ganttColumn).Interior.Color = $(if ($statusValue -eq 'Done') { 10079487 } else { 14277081 })
          }
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
    [void]$view.Range('H:J').Columns.Group()
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
  for ($chartIndex = $existingCharts.Count; $chartIndex -ge 1; $chartIndex--) {
    $existingCharts.Item($chartIndex).Delete()
  }
  Remove-ComReference $existingCharts
  [void]$start.Range('A1:H1').Merge()
  Set-Text $start 1 1 'IconDB activation overview'
  [void]$start.Range('A2:H2').Merge()
  Set-Text $start 2 1 'Choose a business view below. Milestones show delivery maturity, not calendar performance; Project schedule remains the detailed master.'
  $dashboardHeaders = @('Business / stream', 'Engaged', 'Data ready', 'Test ready', 'Production', 'Rule Manager', 'AAC test', 'Open view')
  for ($column = 1; $column -le $dashboardHeaders.Count; $column++) { Set-Text $start 4 $column $dashboardHeaders[$column - 1] }

  $milestoneRows = @{
    'FC NA'  = @(@(261), @(262, 263), @(231), @(235, 237, 267), @(205), @(207))
    'FC EU'  = @(@(269), @(271), @(277), @(273, 281, 283, 275), @(205), @(207))
    'OC EU'  = @(@(285), @(289, 291), @(297), @(293, 301, 302, 303), @(205), @(207))
    'Fem EU' = @(@(305), @(309), @(222, 224), @(227, 228), @(205), @(207))
    'LA'     = @(@(329, 346, 362, 379), @(334, 350, 366, 383), @(335, 351, 367, 384), @(337, 353, 369, 386), @(205), @(207))
    'AAC'    = @(@(11), @(170), @(170), @(228), @(205), @(207))
  }
  $dashboardRow = 5
  foreach ($definition in $views) {
    Set-Text $start $dashboardRow 1 $definition.Label
    $milestones = $milestoneRows[$definition.Short]
    $deliveredCount = 0
    for ($index = 0; $index -lt $milestones.Count; $index++) {
      $milestoneStatus = Get-MilestoneStatus $schedule @($milestones[$index])
      if ($milestoneStatus -eq 'Delivered') { $deliveredCount++ }
      Set-Text $start $dashboardRow ($index + 2) $milestoneStatus
    }
    Set-Formula $start $dashboardRow 8 "=HYPERLINK(\"#'$($definition.Name)'!A1\",\"Open $($definition.Short) plan\")"
    Set-Text $start $dashboardRow 9 ([string]$deliveredCount)
    $dashboardRow++
  }

  Set-Text $start 4 9 'Milestones delivered'
  $start.Range("I5:I$($dashboardRow - 1)").NumberFormat = '0'
  $chartObjects = $start.ChartObjects()
  $chartObject = $chartObjects.Add(20, 230, 720, 290)
  $chart = $chartObject.Chart
  $chart.ChartType = 51
  $seriesCollection = $chart.SeriesCollection()
  $series = $seriesCollection.NewSeries()
  $series.Name = 'Milestones delivered'
  $series.XValues = $start.Range("A5:A$($dashboardRow - 1)")
  $series.Values = $start.Range("I5:I$($dashboardRow - 1)")
  $chart.HasTitle = $true
  $chart.ChartTitle.Text = 'Activation milestones delivered (of 6)'
  $chart.HasLegend = $false
  $chart.Axes(2).MinimumScale = 0
  $chart.Axes(2).MaximumScale = 6
  Remove-ComReference $series
  Remove-ComReference $seriesCollection
  Remove-ComReference $chart
  Remove-ComReference $chartObject
  Remove-ComReference $chartObjects

  $start.Range('A1:H1').Interior.Color = 6569237
  $start.Range('A1').Font.Color = 16777215
  $start.Range('A1').Font.Bold = $true
  $start.Range('A1').Font.Size = 18
  $start.Range('A4:H4').Font.Bold = $true
  $start.Range('A4:H4').Interior.Color = 14277081
  $start.Range("A4:H$($dashboardRow - 1)").Borders.LineStyle = 1
  $start.Range("A5:H$($dashboardRow - 1)").HorizontalAlignment = -4108
  $start.Range('A:A').ColumnWidth = 30
  $start.Range('B:G').ColumnWidth = 16
  $start.Range('H:H').ColumnWidth = 22
  $start.Range('I:I').EntireColumn.Hidden = $true
  $start.Range("A1:H$($dashboardRow - 1)").WrapText = $true
  $start.Activate()
  $workbook.Save()
  [pscustomobject]@{ Mode = 'Apply'; Dashboard = 'Start'; Views = @($views.Name); Removed = 'View - BU'; Saved = $workbook.Saved }
}
finally {
  Remove-ComReference $schedule
  if ($null -ne $workbook) { $workbook.Close($false); Remove-ComReference $workbook }
  if ($null -ne $excel) { $excel.Quit(); Remove-ComReference $excel }
  [GC]::Collect()
  [GC]::WaitForPendingFinalizers()
}
