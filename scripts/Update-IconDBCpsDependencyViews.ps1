[CmdletBinding()]
param(
  [ValidateSet('Preview', 'Apply')]
  [string]$Mode = 'Preview',

  [string]$WorkbookUrl = 'https://pgone.sharepoint.com/sites/RTARELEASE/Shared Documents/General/IconDB Integration/Project alignment docs/Icon DB CPS new standard.xlsx',

  [datetime]$AsOf = [datetime]'2026-08-12',

  [string[]]$ViewName
)

$ErrorActionPreference = 'Stop'

$missingActions = @(
  [pscustomobject]@{
    Task            = 'Validate corrected production integration after deployment and retain rollback evidence'
    Owner           = 'Michal / Tommy / Steve / Jyoti'
    Duration        = 2
    PredecessorTask = $null
    ReplanningNote  = 'Rebaselined after Enovia confirmed the production correction for 11 September; testing starts on the next business day and requires retained rollback evidence.'
  },
  [pscustomobject]@{
    Task            = 'Confirm production restart authority and AAC Rule Manager handoff criteria'
    Owner           = 'Tommy / Tripolina / Emilian, accountability to confirm'
    Duration        = 1
    PredecessorTask = 'Validate corrected production integration after deployment and retain rollback evidence'
    ReplanningNote  = 'Production restart follows passed validation; AAC then requires final IconDB names/IDs and Rule Manager migration from Graphics Library references before E2E.'
  }
)

$viewDefinitions = @(
  [pscustomobject]@{ Name = 'View - BU'; Role = 'BU Activation'; Pattern = '(?i)\bBU\b|FC NA|FC EU|OC EU|FEM EU|Fem EU|LA |UAT|GO / NO GO|activation|upload|training|trained|business case' },
  [pscustomobject]@{ Name = 'View - FC NA'; Role = 'FC NA Activation'; Pattern = '(?i)FC NA' },
  [pscustomobject]@{ Name = 'View - FC EU'; Role = 'FC EU Activation'; Pattern = '(?i)FC EU' },
  [pscustomobject]@{ Name = 'View - OC EU'; Role = 'OC EU Activation'; Pattern = '(?i)OC EU' },
  [pscustomobject]@{ Name = 'View - Fem EU'; Role = 'Fem EU Activation'; Pattern = '(?i)FEM EU|Fem EU|FemCare' },
  [pscustomobject]@{ Name = 'View - LA'; Role = 'LA Activation'; Pattern = '(?i)(^|\W)LA($|\W)|Latin America' },
  [pscustomobject]@{ Name = 'View - AAC'; Role = 'AAC'; Pattern = '(?i)AAC|Trident|SGX|SGK|SGS|Smart PDF' },
  [pscustomobject]@{ Name = 'View - IconDB'; Role = 'IconDB'; Pattern = '(?i)IconDB|Icon DB|IDB|Canvas|Family|Duplicate|Approval|Logging|API readiness' },
  [pscustomobject]@{ Name = 'View - Enovia'; Role = 'Enovia'; Pattern = '(?i)Enovia|MAE|Integration Type|mapping|routing|Jyoti' }
)
if ($ViewName) {
  $unknownViewNames = @($ViewName | Where-Object { $_ -notin $viewDefinitions.Name })
  if ($unknownViewNames.Count -gt 0) { throw "Unknown role view: $($unknownViewNames -join ', ')" }
  $viewDefinitions = @($viewDefinitions | Where-Object { $_.Name -in $ViewName })
}

function Remove-ComReference {
  param($Value)
  if ($null -ne $Value -and [Runtime.InteropServices.Marshal]::IsComObject($Value)) {
    [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($Value)
  }
}

function Find-TaskRow {
  param($Sheet, [string]$Task, [int]$LastRow)

  $taskRows = @(
    10..$LastRow | Where-Object { ([string]$Sheet.Cells.Item($_, 5).Text).Trim() -ceq $Task }
  )
  if ($taskRows.Count -gt 1) { throw "Task identity is not unique: $Task" }
  if ($taskRows.Count -eq 1) { return [int]$taskRows[0] }
  return $null
}

function Get-PredecessorIds {
  param($Sheet, [int]$Row)

  $formula = [string]$Sheet.Cells.Item($Row, 10).Formula
  $references = @([regex]::Matches($formula, '(?i)K(\d+)') | ForEach-Object { [int]$_.Groups[1].Value } | Select-Object -Unique)
  $labels = foreach ($reference in $references) {
    $task = ([string]$Sheet.Cells.Item($reference, 5).Text).Trim()
    if ($task -match '^\[Recovery (R\d{3})\]\s*(.+)$') {
      "$($Matches[1]): $($Matches[2])"
    }
    elseif ($task) {
      "CPS ${reference}: $task"
    }
  }
  return ($labels -join '; ')
}

function Set-CellText {
  param($Sheet, [int]$Row, [int]$Column, [AllowEmptyString()][string]$Value)

  $cell = $null
  try {
    $cell = $Sheet.Cells.Item($Row, $Column)
    $cell.Value2 = [string]$Value
  }
  finally {
    Remove-ComReference $cell
  }
}

function Set-CellFormula {
  param($Sheet, [int]$Row, [int]$Column, [string]$Formula)

  $cell = $null
  try {
    $cell = $Sheet.Cells.Item($Row, $Column)
    $cell.Formula = [string]$Formula
  }
  finally {
    Remove-ComReference $cell
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
  $lastRow = $schedule.UsedRange.Row + $schedule.UsedRange.Rows.Count - 1
  $actionsToAdd = @($missingActions | Where-Object { $null -eq (Find-TaskRow -Sheet $schedule -Task $_.Task -LastRow $lastRow) })

  $preview = [pscustomobject]@{
    Mode                = $Mode
    MasterSheet         = 'Project schedule'
    MissingActionsToAdd = $actionsToAdd.Count
    MissingActions      = @($actionsToAdd | Select-Object Task, Owner, Duration, PredecessorTask)
    RoleViews           = @($viewDefinitions.Name)
  }
  if ($Mode -eq 'Preview') {
    $preview
    return
  }

  if ($actionsToAdd.Count -gt 0) {
    $anchorMatches = @(10..$lastRow | Where-Object { ([string]$schedule.Cells.Item($_, 5).Text).Trim() -ceq 'Lead OU Pilot Technical Readiness' })
    if ($anchorMatches.Count -ne 1) { throw 'Expected one Lead OU Pilot Technical Readiness anchor row.' }
    $insertAt = [int]$anchorMatches[0]

    $existingActionRows = @($missingActions | ForEach-Object { Find-TaskRow -Sheet $schedule -Task $_.Task -LastRow $lastRow })
    $existingActionRows = @($existingActionRows | Where-Object { $null -ne $_ })
    if ($existingActionRows.Count -eq 0) {
      for ($index = $missingActions.Count - 1; $index -ge 0; $index--) {
        [void]$schedule.Rows.Item($insertAt).Insert()
      }
      $blockStart = $insertAt
    }
    else {
      $blockStart = $insertAt - $missingActions.Count
      for ($index = 0; $index -lt $missingActions.Count; $index++) {
        $currentTask = ([string]$schedule.Cells.Item($blockStart + $index, 5).Text).Trim()
        if ($currentTask -and $currentTask -cne $missingActions[$index].Task) {
          throw "The partially reserved action block contains an unexpected task at row $($blockStart + $index): $currentTask"
        }
      }
    }

    $lastRow = $schedule.UsedRange.Row + $schedule.UsedRange.Rows.Count - 1
    $templateRow = Find-TaskRow -Sheet $schedule -Task 'FC NA testing scenarios for UAT' -LastRow $lastRow
    if ($null -eq $templateRow) { throw 'The action-row formatting template was not found.' }

    for ($index = 0; $index -lt $missingActions.Count; $index++) {
      $action = $missingActions[$index]
      $row = $blockStart + $index
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
  $lastRow = $schedule.UsedRange.Row + $schedule.UsedRange.Rows.Count - 1
  $actionNotes = @{}
  foreach ($action in $missingActions) { $actionNotes[$action.Task] = $action.ReplanningNote }

  foreach ($definition in $viewDefinitions) {
    $existing = $null
    try { $existing = $workbook.Worksheets.Item($definition.Name) } catch { $existing = $null }
    if ($null -eq $existing) {
      $view = $workbook.Worksheets.Add()
      $view.Name = $definition.Name
    }
    else {
      $view = $existing
      [void]$view.Cells.Clear()
    }

    [void]$view.Range('A1:J1').Merge()
    $view.Range('A1').Value2 = "$($definition.Role) dependency view - generated from Project schedule"
    [void]$view.Range('A2:J2').Merge()
    $view.Range('A2').Value2 = 'Dates, owners, and status update live from Project schedule. Make changes there; this view is for review and coordination.'
    [void]$view.Range('A3:J3').Merge()
    $view.Range('A3').Value2 = 'Gantt legend: blue = planned or in progress; green = done; red = late; yellow = today. A dependency point requires an approval, validation, or go/no-go before following work can proceed.'
    $headers = @('CPS row', 'Rescheduled?', 'Action', 'Owner', 'Status', 'Start', 'Finish', 'Business days', 'Depends on', 'Why this date / what happens next')
    for ($column = 1; $column -le $headers.Count; $column++) {
      Set-CellText -Sheet $view -Row 5 -Column $column -Value $headers[$column - 1]
    }

    $viewRow = 6
    for ($row = 10; $row -le $lastRow; $row++) {
      $task = ([string]$schedule.Cells.Item($row, 5).Text).Trim()
      $owner = ([string]$schedule.Cells.Item($row, 8).Text).Trim()
      $status = ([string]$schedule.Cells.Item($row, 6).Text).Trim()
      if (-not $task -or $status -ieq 'Done' -or "$task $owner" -notmatch $definition.Pattern) { continue }

      $recoveryId = ''
      $displayTask = $task
      if ($task -match '^\[Recovery (R\d{3})\]\s*(.+)$') {
        $recoveryId = $Matches[1]
        $displayTask = $Matches[2]
      }
      $isDependencyGate = $task -match '(?i)UAT|GO / NO GO|E2E|sign-off|validation|restart|mapping|MAE|upload|training|readiness'
      $note = if ($actionNotes.ContainsKey($task)) {
        $actionNotes[$task]
      }
      elseif ($task -match '^\[Recovery ') {
        $baselineRow = $row - 1
        $baselineStart = ([string]$schedule.Cells.Item($baselineRow, 10).Text).Trim()
        $baselineEnd = ([string]$schedule.Cells.Item($baselineRow, 11).Text).Trim()
        "Rescheduled because the original plan slipped (original dates $baselineStart to $baselineEnd). New dates follow the actions listed in Depends on."
      }
      else {
        'Planned action. Confirm the owner and required prior actions before changing dates in Project schedule.'
      }

      Set-CellText -Sheet $view -Row $viewRow -Column 1 -Value ([string]$row)
      Set-CellText -Sheet $view -Row $viewRow -Column 2 -Value $(if ($recoveryId) { 'Yes' } else { '' })
      Set-CellText -Sheet $view -Row $viewRow -Column 3 -Value ([string]$displayTask)
      Set-CellFormula -Sheet $view -Row $viewRow -Column 4 -Formula "='Project schedule'!H$row"
      Set-CellFormula -Sheet $view -Row $viewRow -Column 5 -Formula "='Project schedule'!F$row"
      Set-CellFormula -Sheet $view -Row $viewRow -Column 6 -Formula "='Project schedule'!J$row"
      Set-CellFormula -Sheet $view -Row $viewRow -Column 7 -Formula "='Project schedule'!K$row"
      Set-CellFormula -Sheet $view -Row $viewRow -Column 8 -Formula "='Project schedule'!L$row"
      Set-CellText -Sheet $view -Row $viewRow -Column 9 -Value ([string](Get-PredecessorIds -Sheet $schedule -Row $row))
      Set-CellText -Sheet $view -Row $viewRow -Column 10 -Value ([string]"$(if ($isDependencyGate) { 'Approval or validation required here. ' })$note")
      $viewRow++
    }

    $timelineSourceStart = 15
    $timelineSourceEnd = 144
    $timelineTargetStart = 11
    for ($offset = 0; $offset -le ($timelineSourceEnd - $timelineSourceStart); $offset++) {
      $sourceColumn = $timelineSourceStart + $offset
      $targetColumn = $timelineTargetStart + $offset
      $sourceAddress = ([string]$schedule.Cells.Item(8, $sourceColumn).Address($false, $false))
      Set-CellFormula -Sheet $view -Row 4 -Column $targetColumn -Formula "='Project schedule'!$sourceAddress"
      Set-CellFormula -Sheet $view -Row 5 -Column $targetColumn -Formula "='Project schedule'!$sourceAddress"
    }

    $timelineLastColumn = $timelineTargetStart + ($timelineSourceEnd - $timelineSourceStart)
    $timelineLastLetter = ([string]$view.Cells.Item(1, $timelineLastColumn).Address($false, $false)) -replace '\d', ''
    $taskLastRow = [Math]::Max(6, $viewRow - 1)
    $timelineRange = $view.Range("K6:${timelineLastLetter}$taskLastRow")
    [void]$timelineRange.FormatConditions.Delete()
    $doneRule = $timelineRange.FormatConditions.Add(2, 0, '=AND(K$5>=$F6;K$5<=$G6;$E6="Done")')
    $doneRule.Interior.Color = 4944944
    $lateRule = $timelineRange.FormatConditions.Add(2, 0, '=AND(K$5>=$F6;K$5<=$G6;$E6="Late")')
    $lateRule.Interior.Color = 13551615
    $activeRule = $timelineRange.FormatConditions.Add(2, 0, '=AND(K$5>=$F6;K$5<=$G6;$E6<>"Done";$E6<>"Late")')
    $activeRule.Interior.Color = 14277081
    $todayRule = $view.Range("K5:${timelineLastLetter}$taskLastRow").FormatConditions.Add(2, 0, '=K$5=TODAY()')
    $todayRule.Interior.Color = 65535

    $view.Range('A1:J1').Font.Bold = $true
    $view.Range('A1:J1').Font.Size = 14
    $view.Range("A1:${timelineLastLetter}1").Interior.Color = 6569237
    $view.Range('A1').Font.Color = 16777215
    $view.Range('A5:J5').Font.Bold = $true
    $view.Range('A5:J5').Interior.Color = 14277081
    $view.Range("A5:${timelineLastLetter}$taskLastRow").Borders.LineStyle = 1
    [void]$view.Range("A5:J$taskLastRow").AutoFilter()
    $view.Range("K4:${timelineLastLetter}4").NumberFormat = 'mmm d'
    $view.Range("K5:${timelineLastLetter}5").NumberFormat = 'ddd d'
    $view.Range("K4:${timelineLastLetter}5").HorizontalAlignment = -4108
    $view.Range("K4:${timelineLastLetter}5").Font.Bold = $true
    $view.Range("K4:${timelineLastLetter}5").Interior.Color = 15921906
    $view.Range("F6:G$taskLastRow").NumberFormat = 'dd-mmm-yy'
    [void]$view.Range('A:J').EntireColumn.AutoFit()
    $view.Range('C:C').ColumnWidth = 48
    $view.Range('I:I').ColumnWidth = 48
    $view.Range('J:J').ColumnWidth = 58
    $view.Range("K:${timelineLastLetter}").ColumnWidth = 4.5
    $view.Range("A1:J$taskLastRow").WrapText = $true
    $view.Activate()
    $excel.ActiveWindow.FreezePanes = $false
    $excel.ActiveWindow.SplitRow = 0
    $excel.ActiveWindow.SplitColumn = 0
    $excel.ActiveWindow.SplitRow = 5
    $excel.ActiveWindow.SplitColumn = 9
    $excel.ActiveWindow.FreezePanes = $true
    Remove-ComReference $todayRule
    Remove-ComReference $activeRule
    Remove-ComReference $lateRule
    Remove-ComReference $doneRule
    Remove-ComReference $timelineRange
    Remove-ComReference $view
  }

  $schedule.Activate()
  $excel.CalculateFull()
  $workbook.Save()
  [pscustomobject]@{
    Mode           = 'Apply'
    AddedActions   = @($actionsToAdd | ForEach-Object { $_.Task })
    RefreshedViews = @($viewDefinitions.Name)
  }
}
finally {
  if ($null -ne $workbook) { $workbook.Close($false) }
  Remove-ComReference $schedule
  Remove-ComReference $workbook
  if ($null -ne $excel) { $excel.Quit() }
  Remove-ComReference $excel
  [GC]::Collect()
  [GC]::WaitForPendingFinalizers()
}
