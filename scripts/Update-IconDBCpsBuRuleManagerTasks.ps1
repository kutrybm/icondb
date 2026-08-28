[CmdletBinding()]
param(
  [ValidateSet('Preview', 'Apply')]
  [string]$Mode = 'Preview',

  [string]$WorkbookUrl = 'https://pgone.sharepoint.com/sites/RTARELEASE/Shared Documents/General/IconDB Integration/Project alignment docs/Icon DB CPS new standard.xlsx'
)

$ErrorActionPreference = 'Stop'

$aacTask = '[Recovery R169] Execute AAC E2E using updated Rule Manager references and applicable Trident/SGX path'
$templateTask = '[Recovery R212] Resume FC NA use of IconDB production after approved recovery pilot'
$definitions = @(
  [pscustomobject]@{
    Business       = 'FC NA'
    Task           = 'Update Rule Manager icon rules for FC NA using approved production IconDB names/IDs'
    InsertBefore   = 'FC EU Trained on the IDB process, data required and Service Upload'
    Predecessors   = @('[Recovery R212] Resume FC NA use of IconDB production after approved recovery pilot')
    AllPredecessor = $null
  },
  [pscustomobject]@{
    Business       = 'FC EU'
    Task           = 'Update Rule Manager icon rules for FC EU using approved production IconDB names/IDs'
    InsertBefore   = 'Enagage OC EU on IconDB and E2E Process'
    Predecessors   = @('[Recovery R217] Confirm FC EU production acceptance and repository transition')
    AllPredecessor = $null
  },
  [pscustomobject]@{
    Business       = 'OC EU'
    Task           = 'Update Rule Manager icon rules for OC EU using approved production IconDB names/IDs'
    InsertBefore   = 'Fem Care EU'
    Predecessors   = @('OC EU transitions to approved IconDB production use')
    AllPredecessor = $null
  },
  [pscustomobject]@{
    Business       = 'Fem EU'
    Task           = 'Update Rule Manager icon rules for Fem EU using approved production IconDB names/IDs'
    InsertBefore   = 'LA Hair'
    Predecessors   = @('[Recovery R254] FEM EU uses IDB PROD  and dispontinued other Icons repository')
    AllPredecessor = $null
  },
  [pscustomobject]@{
    Business       = 'LA'
    Task           = 'Update Rule Manager icon rules for LA using approved production IconDB names/IDs'
    InsertBefore   = $null
    Predecessors   = @(
      'LA HAIR uses IDB PROD  and dispontinued other Icons repository',
      'LA SPC uses IDB PROD  and dispontinued other Icons repository',
      'LA Oral uses IDB PROD  and dispontinued other Icons repository'
    )
    AllPredecessor = 'LA Baby Fem uses IDB PROD  and dispontinued other Icons repository'
  }
)

function Remove-ComReference {
  param($Value)
  if ($null -ne $Value -and [Runtime.InteropServices.Marshal]::IsComObject($Value)) {
    [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($Value)
  }
}

function Get-LastRow {
  param($Sheet)
  return [int]($Sheet.UsedRange.Row + $Sheet.UsedRange.Rows.Count - 1)
}

function Find-TaskRows {
  param($Sheet, [string]$Task, [int]$LastRow)
  return @(10..$LastRow | Where-Object { ([string]$Sheet.Cells.Item($_, 5).Text).Trim() -ceq $Task })
}

function Find-TaskRow {
  param($Sheet, [string]$Task, [int]$LastRow)
  $matches = @(Find-TaskRows -Sheet $Sheet -Task $Task -LastRow $LastRow)
  if ($Task -ceq $templateTask -and $matches.Count -gt 1) { return [int]($matches | Measure-Object -Minimum).Minimum }
  if ($matches.Count -gt 1) { throw "Task identity is not unique: $Task" }
  if ($matches.Count -eq 1) { return [int]$matches[0] }
  return $null
}

function Resolve-PredecessorRows {
  param($Sheet, $Definition, [int]$LastRow)
  $rows = foreach ($task in $Definition.Predecessors) {
    $row = Find-TaskRow -Sheet $Sheet -Task $task -LastRow $LastRow
    if ($null -eq $row) { throw "Required predecessor task was not found: $task" }
    $row
  }
  if ($null -ne $Definition.AllPredecessor) {
    $allMatches = @(Find-TaskRows -Sheet $Sheet -Task $Definition.AllPredecessor -LastRow $LastRow)
    if ($allMatches.Count -ne 2) {
      throw "Expected two LA Baby/Fem production predecessor rows but found $($allMatches.Count)."
    }
    $rows = @($rows) + $allMatches
  }
  return @($rows)
}

function New-StartFormula {
  param([int[]]$PredecessorRows)
  $references = @($PredecessorRows | ForEach-Object { "K$_" })
  $gate = if ($references.Count -eq 1) { $references[0] } else { "MAX($($references -join ','))" }
  return "=WORKDAY($gate,1,Holidays!`$C:`$C)"
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
  $lastRow = Get-LastRow $schedule

  $aacRow = Find-TaskRow -Sheet $schedule -Task $aacTask -LastRow $lastRow
  if ($null -eq $aacRow) { throw "AAC E2E task was not found: $aacTask" }

  $preview = foreach ($definition in $definitions) {
    $existingRow = Find-TaskRow -Sheet $schedule -Task $definition.Task -LastRow $lastRow
    $predecessorRows = Resolve-PredecessorRows -Sheet $schedule -Definition $definition -LastRow $lastRow
    $state = if ($null -ne $existingRow) { 'Update' } else { 'Insert' }
    $targetRow = if ($null -ne $existingRow) {
      $existingRow
    }
    elseif ($null -ne $definition.InsertBefore) {
      $anchorRow = Find-TaskRow -Sheet $schedule -Task $definition.InsertBefore -LastRow $lastRow
      if ($null -eq $anchorRow) { throw "Insertion anchor was not found for $($definition.Business): $($definition.InsertBefore)" }
      $candidateRow = $anchorRow - 1
      if (([string]$schedule.Cells.Item($candidateRow, 5).Text).Trim() -ceq $templateTask) {
        $state = 'Repair'
        $candidateRow
      }
      else { $anchorRow }
    }
    else {
      $candidateRow = ([int]($predecessorRows | Measure-Object -Maximum).Maximum) + 1
      if (([string]$schedule.Cells.Item($candidateRow, 5).Text).Trim() -ceq $templateTask) { $state = 'Repair' }
      $candidateRow
    }

    [pscustomobject]@{
      Business        = $definition.Business
      State           = $state
      TargetRow       = $targetRow
      Task            = $definition.Task
      PredecessorRows = ($predecessorRows -join ',')
      StartFormula    = New-StartFormula $predecessorRows
    }
  }
  if ($Mode -eq 'Preview') { $preview; return }

  $templateRow = Find-TaskRow -Sheet $schedule -Task $templateTask -LastRow $lastRow
  if ($null -eq $templateRow) { throw "Formatting template task was not found: $templateTask" }

  foreach ($item in @($preview | Where-Object State -eq 'Insert' | Sort-Object TargetRow -Descending)) {
    [void]$schedule.Rows.Item([int]$item.TargetRow).Insert()
    $schedule.Cells.Item([int]$item.TargetRow, 5).NumberFormat = '@'
    $schedule.Cells.Item([int]$item.TargetRow, 5).Value2 = [string]$item.Task
    [void]$schedule.Range("A$templateRow").Copy($schedule.Range("A$($item.TargetRow)"))
    [void]$schedule.Range("C${templateRow}:D$templateRow").Copy($schedule.Range("C$($item.TargetRow):D$($item.TargetRow)"))
    [void]$schedule.Range("F${templateRow}:FA$templateRow").Copy($schedule.Range("F$($item.TargetRow):FA$($item.TargetRow)"))
  }

  $lastRow = Get-LastRow $schedule
  $ruleManagerRows = @()
  foreach ($definition in $definitions) {
    $row = Find-TaskRow -Sheet $schedule -Task $definition.Task -LastRow $lastRow
    if ($null -eq $row) {
      if ($null -ne $definition.InsertBefore) {
        $anchorRow = Find-TaskRow -Sheet $schedule -Task $definition.InsertBefore -LastRow $lastRow
        if ($null -eq $anchorRow) { throw "Insertion anchor disappeared for $($definition.Business)." }
        $row = $anchorRow - 1
      }
      else {
        $predecessorRows = Resolve-PredecessorRows -Sheet $schedule -Definition $definition -LastRow $lastRow
        $row = ([int]($predecessorRows | Measure-Object -Maximum).Maximum) + 1
      }
    }
    $predecessorRows = Resolve-PredecessorRows -Sheet $schedule -Definition $definition -LastRow $lastRow
    $schedule.Cells.Item($row, 5).NumberFormat = '@'
    $schedule.Cells.Item($row, 5).Value2 = [string]$definition.Task
    $schedule.Cells.Item($row, 6).Value2 = [string]'Not Started'
    $schedule.Cells.Item($row, 8).Value2 = [string]'Emilian / Lauren / BU SPOC'
    $schedule.Cells.Item($row, 9).Formula = [string]"=IF(F$row=`"Done`",100%,`"`")"
    $schedule.Cells.Item($row, 10).Formula = [string](New-StartFormula $predecessorRows)
    $schedule.Cells.Item($row, 11).Formula = [string]"=WORKDAY(J$row,L$row-1,Holidays!`$C:`$C)"
    $schedule.Cells.Item($row, 12).Value2 = [double]3
    $schedule.Cells.Item($row, 13).Formula = [string]"=K$row-J$row+1"
    $ruleManagerRows += $row
  }

  $aacRow = Find-TaskRow -Sheet $schedule -Task $aacTask -LastRow $lastRow
  if ($null -eq $aacRow) { throw 'AAC E2E task disappeared after insertion.' }
  $schedule.Cells.Item($aacRow, 10).Formula = [string](New-StartFormula $ruleManagerRows)

  $excel.CalculateFull()
  $workbook.Save()
  [pscustomobject]@{
    Mode            = 'Apply'
    RuleManagerRows = ($ruleManagerRows -join ',')
    AacRow          = $aacRow
    AacStartFormula = [string]$schedule.Cells.Item($aacRow, 10).Formula
    Saved           = $workbook.Saved
  }
}
finally {
  Remove-ComReference $schedule
  if ($null -ne $workbook) { $workbook.Close($false); Remove-ComReference $workbook }
  if ($null -ne $excel) { $excel.Quit(); Remove-ComReference $excel }
  [GC]::Collect()
  [GC]::WaitForPendingFinalizers()
}
