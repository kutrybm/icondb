[CmdletBinding()]
param(
  [ValidateSet('Preview', 'Apply')]
  [string]$Mode = 'Preview',

  [string]$WorkbookUrl = 'https://pgone.sharepoint.com/sites/RTARELEASE/Shared Documents/General/IconDB Integration/Project alignment docs/Icon DB CPS new standard.xlsx'
)

$ErrorActionPreference = 'Stop'

$updates = @(
  [pscustomobject]@{ Row = 170; Expected = '[Recovery R134] API readiness for BVE -> IconDB connection'; Task = '[Recovery R134] Confirm AAC matching/tagging rules and Trident/SGX implementation owner'; Owner = 'Emilian / Rachel / AAC / Trident / SGX'; Start = '=WORKDAY(DATE(2026,8,24),0,Holidays!$C:$C)'; Duration = 6 },
  [pscustomobject]@{ Row = 205; Expected = '[Recovery R168] Migrate Rule Manager icon references from Graphics Library to production IconDB names/IDs'; Task = '[Recovery R168] Update Rule Manager icon rules for each BU after approved production icons; required before AAC testing'; Owner = 'Emilian / Lauren / Tommy'; Start = '=WORKDAY(K228,1,Holidays!$C:$C)'; Duration = 5 },
  [pscustomobject]@{ Row = 207; Expected = '[Recovery R169] Execute AAC E2E using migrated Rule Manager references and applicable Trident/SGX path'; Task = '[Recovery R169] Execute AAC E2E using updated Rule Manager references and applicable Trident/SGX path'; Owner = 'Emilian / Rachel / AAC / Trident / SGX'; Start = '=WORKDAY(K205,1,Holidays!$C:$C)'; Duration = 5 },
  [pscustomobject]@{ Row = 211; Expected = '[Recovery R172] Sign-off AAC techncial readiness'; Task = '[Recovery R172] Confirm AAC technical readiness and accountable sign-off'; Owner = 'Emilian / Rachel / AAC'; Start = '=WORKDAY(K207,1,Holidays!$C:$C)'; Duration = 2 },
  [pscustomobject]@{ Row = 217; Expected = '[Recovery R177] Obtain AAC tagging/readiness sign-off for Trident and SGX'; Task = '[Recovery R177] Obtain Trident and SGX confirmation of AAC tagging/readiness implementation'; Owner = 'Emilian / Rachel / Trident / SGX'; Start = '=WORKDAY(K211,1,Holidays!$C:$C)'; Duration = 5 },
  [pscustomobject]@{ Row = 231; Expected = '[Recovery R181] FC NA testing scenarios for UAT'; Task = '[Recovery R181] Confirm FC NA recovery sample and business acceptance owner'; Owner = 'FC NA / Tommy / Steve'; Start = '=WORKDAY(DATE(2026,8,18),0,Holidays!$C:$C)'; Duration = 5 },
  [pscustomobject]@{ Row = 235; Expected = '[Recovery R184] FC NA UAT (Canvas QA + Enovia SIT)'; Task = '[Recovery R184] Run controlled FC NA production recovery pilot and retain Enovia/MAE evidence'; Owner = 'Michal / FC NA / Tommy / Steve / Jyoti'; Start = '=WORKDAY(MAX(K228,K231,K265),1,Holidays!$C:$C)'; Duration = 2 },
  [pscustomobject]@{ Row = 237; Expected = '[Recovery R185] GO / NO GO for PROD'; Task = '[Recovery R185] Confirm FC NA production restart after recovery pilot'; Owner = 'Michal / FC NA / Tommy / Tripolina'; Start = '=WORKDAY(K235,1,Holidays!$C:$C)'; Duration = 1 },
  [pscustomobject]@{ Row = 265; Expected = '[Recovery R211] Plan for the transition from sharepoint to IDB PROD as a storage (no integration)'; Task = '[Recovery R211] Preserve FC NA upload pack and reconcile seven failed production records'; Owner = 'FC NA / Tommy / Steve / Jyoti'; Start = '=WORKDAY(DATE(2026,8,18),0,Holidays!$C:$C)'; Duration = 8 },
  [pscustomobject]@{ Row = 267; Expected = '[Recovery R212] FC NA uses IDB PROD instead of sharepoint (no integration)'; Task = '[Recovery R212] Resume FC NA use of IconDB production after approved recovery pilot'; Owner = 'FC NA / Michal'; Start = '=WORKDAY(K237,1,Holidays!$C:$C)'; Duration = 2 },
  [pscustomobject]@{ Row = 271; Expected = '[Recovery R215] FC EU data collection and cleanup'; Task = '[Recovery R215] Michal validates corrected FC EU template and confirms upload-ready pack'; Owner = 'Michal / Ewa / FC EU'; Start = '=WORKDAY(DATE(2026,8,24),0,Holidays!$C:$C)'; Duration = 2 },
  [pscustomobject]@{ Row = 273; Expected = '[Recovery R216] IDB Service team upload FC EU data in Canvas PROD'; Task = '[Recovery R216] Execute controlled FC EU production upload after restart gate'; Owner = 'Michal / IDB Team / FC EU'; Start = '=WORKDAY(MAX(K228,K271),1,Holidays!$C:$C)'; Duration = 2 },
  [pscustomobject]@{ Row = 275; Expected = '[Recovery R217] FC EU uses IDB PROD  instead of sharepoint'; Task = '[Recovery R217] Confirm FC EU production acceptance and repository transition'; Owner = 'FC EU / Michal'; Start = '=WORKDAY(K283,1,Holidays!$C:$C)'; Duration = 2 },
  [pscustomobject]@{ Row = 277; Expected = '[Recovery R218] FC EU testing scenarios for UAT'; Task = '[Recovery R218] Confirm FC EU acceptance scenarios and business signer'; Owner = 'Michal / FC EU / IDB Team'; Start = '=WORKDAY(DATE(2026,8,24),0,Holidays!$C:$C)'; Duration = 4 },
  [pscustomobject]@{ Row = 281; Expected = '[Recovery R221] FC EU UAT (Canvas QA + Enovia SIT)'; Task = '[Recovery R221] Execute controlled FC EU production validation'; Owner = 'Michal / FC EU / IDB Team'; Start = '=WORKDAY(MAX(K273,K277),1,Holidays!$C:$C)'; Duration = 3 },
  [pscustomobject]@{ Row = 283; Expected = '[Recovery R222] GO / NO GO for PROD'; Task = '[Recovery R222] Confirm FC EU production go/no-go'; Owner = 'Michal / FC EU / Tommy'; Start = '=WORKDAY(K281,1,Holidays!$C:$C)'; Duration = 1 },
  [pscustomobject]@{ Row = 293; Expected = '[Recovery R231] IDB Service team upload OC EU data in Canvas PROD'; Task = '[Recovery R231] Prepare OC EU production pack including OCEU_534 and OCEU_318'; Owner = 'Michal / Anna / Iga / OC EU'; Start = '=WORKDAY(DATE(2026,8,24),0,Holidays!$C:$C)'; Duration = 4 },
  [pscustomobject]@{ Row = 297; Expected = '[Recovery R233] OC EU testing scenarios for UAT'; Task = '[Recovery R233] Confirm OC EU acceptance scenarios, signer, and variable-text BVE/AAC decision'; Owner = 'Michal / Pamela / Hanif / Iga / Emilian'; Start = '=WORKDAY(DATE(2026,8,24),0,Holidays!$C:$C)'; Duration = 6 },
  [pscustomobject]@{ Row = 301; Expected = '[Recovery R236] OC EU UAT (Canvas QA + Enovia SIT)+ BVE'; Task = '[Recovery R236] Execute controlled OC EU production validation with applicable BVE/AAC path'; Owner = 'Michal / OC EU / Emilian / BVE'; Start = '=WORKDAY(MAX(K228,K293,K297),1,Holidays!$C:$C)'; Duration = 3 },
  [pscustomobject]@{ Row = 302; Expected = 'GO / NO GO for PROD'; Task = 'Confirm OC EU production go/no-go'; Owner = 'Michal / OC EU / Tommy'; Start = '=WORKDAY(K301,1,Holidays!$C:$C)'; Duration = 1 },
  [pscustomobject]@{ Row = 303; Expected = 'OC EU uses IDB PROD  and dispontinued other Icons repository'; Task = 'OC EU transitions to approved IconDB production use'; Owner = 'OC EU / Michal'; Start = '=WORKDAY(K302,1,Holidays!$C:$C)'; Duration = 2 },
  [pscustomobject]@{ Row = 379; Expected = '[Recovery R304] Enagage LA Baby Fem on IconDB and E2E Process'; Task = '[Recovery R304] Realign the LA IconDB plan with the Transformation Team and schedule the leadership session'; Owner = 'Michal / Dennis Mendez / Paula Diaz'; Start = '=WORKDAY(DATE(2026,8,24),0,Holidays!$C:$C)'; Duration = 5 }
)

function Remove-ComReference {
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
  $lastRow = [int]($schedule.UsedRange.Row + $schedule.UsedRange.Rows.Count - 1)
  foreach ($update in $updates) {
    $matches = @(10..$lastRow | Where-Object { ([string]$schedule.Cells.Item($_, 5).Text).Trim() -ceq $update.Task })
    $isCurrentTask = $matches.Count -eq 1
    if ($matches.Count -eq 0) {
      $matches = @(10..$lastRow | Where-Object { ([string]$schedule.Cells.Item($_, 5).Text).Trim() -ceq $update.Expected })
    }
    if ($matches.Count -ne 1) {
      throw "Expected one CPS task matching '$($update.Expected)' or '$($update.Task)' but found $($matches.Count)."
    }
    $update | Add-Member -NotePropertyName ResolvedRow -NotePropertyValue ([int]$matches[0]) -Force
    $update | Add-Member -NotePropertyName PreserveStartFormula -NotePropertyValue $isCurrentTask -Force
    if (-not $isCurrentTask -and [int]$matches[0] -ne $update.Row) {
      throw "Legacy task '$($update.Expected)' shifted from row $($update.Row) to $($matches[0]); apply OU updates before inserting new master rows."
    }
  }

  $updates | Select-Object Row, ResolvedRow, PreserveStartFormula, Expected, Task, Owner, Start, Duration
  if ($Mode -eq 'Preview') { return }

  foreach ($update in $updates) {
    $row = $update.ResolvedRow
    $schedule.Cells.Item($row, 5).Value2 = [string]$update.Task
    $schedule.Cells.Item($row, 6).Value2 = [string]'Not Started'
    $schedule.Cells.Item($row, 8).Value2 = [string]$update.Owner
    $schedule.Cells.Item($row, 9).Formula = [string]"=IF(F$row=`"Done`",100%,`"`")"
    if (-not $update.PreserveStartFormula) {
      $schedule.Cells.Item($row, 10).Formula = [string]$update.Start
    }
    $schedule.Cells.Item($row, 11).Formula = [string]"=WORKDAY(J$row,L$row-1,Holidays!`$C:`$C)"
    $schedule.Cells.Item($row, 12).Value2 = [double]$update.Duration
    $schedule.Cells.Item($row, 13).Formula = [string]"=K$row-J$row+1"
  }

  $excel.CalculateFull()
  $workbook.Save()
  [pscustomobject]@{ Mode = $Mode; UpdatedRows = $updates.Count; Saved = $workbook.Saved }
}
finally {
  Remove-ComReference $schedule
  if ($null -ne $workbook) {
    $workbook.Close($false)
    Remove-ComReference $workbook
  }
  if ($null -ne $excel) {
    $excel.Quit()
    Remove-ComReference $excel
  }
  [GC]::Collect()
  [GC]::WaitForPendingFinalizers()
}
