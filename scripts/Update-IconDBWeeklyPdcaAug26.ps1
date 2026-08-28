[CmdletBinding()]
param(
  [ValidateSet('Preview', 'Apply')]
  [string]$Mode = 'Preview',

  [string]$WorkbookUrl = 'https://pgone.sharepoint.com/sites/RTARELEASE/Shared Documents/General/IconDB Integration/Project alignment docs/IconDB weekly PDCA.xlsx'
)

$ErrorActionPreference = 'Stop'

$rows = @(
  @('IconDB Weekly PDCA - Current Control', '', '', '', ''),
  @('Status date', '26-Aug-2026', '', '', ''),
  @('Authority', 'This SharePoint workbook summarizes the verified SharePoint CPS. Project schedule remains the detailed schedule master.', '', '', ''),
  @('', '', '', '', ''),
  @('WEEKLY OUTCOME', '', '', '', ''),
  @('Use confirmed Enovia SIT success through 31 August to close evidence and mapping gaps. Keep production behind the 11 September deployment, 14-15 September controlled validation, and 16 September restart authority.', '', '', '', ''),
  @('', '', '', '', ''),
  @('GATE', 'DATE', 'OWNER / EVIDENCE', 'STATE', ''),
  @('Current Enovia SIT validation and evidence closure', '26-31 Aug 2026', 'Michal / Tommy / Steve / Jyoti / FemCare; input pack, created records, pass/fail and defects', 'In progress; creation and region/obsolescence behavior passed in SIT', ''),
  @('Enovia QA endpoint switch', '1-Sep-2026', 'Tommy / Enovia; confirmed endpoint and effective baseline', 'Planned; not a production release', ''),
  @('Enovia production deployment', '11-Sep-2026', 'Tommy; deployment evidence', 'Scheduled; deployment is not restart authority', ''),
  @('Controlled production validation', '14-15 Sep 2026', 'Tommy / Steve / Jyoti; retain rollback evidence', 'Planned', ''),
  @('Restart authority and AAC handoff criteria', '16-Sep-2026', 'Tommy / Tripolina', 'Decision gate; no BU restart before approval', ''),
  @('', '', '', '', ''),
  @('OU', 'NEAREST ACTION', 'DUE', 'DEPENDENCY / EVIDENCE', 'STATE'),
  @('FC NA', 'Confirm recovery sample/acceptance owner and reconcile seven failed production records', '26-Aug-2026', 'Restart gate; retained failed-record and pilot evidence', 'Open; overdue action carried forward'),
  @('FC EU', 'Validate current pack in Enovia SIT and decide three integration-type mappings', '31-Aug-2026', 'Current SIT endpoint; EECAR scope and pass/fail evidence', 'In progress'),
  @('Oral Care EU', 'Confirm OCEU_534/OCEU_318 naming, IDs, curation, acceptance and release route', '31-Aug-2026', 'Anna/Iga response and CPM-672 acceptance decision', 'In progress; request sent, confirmation pending'),
  @('FemCare EU', 'Complete scenarios by 28 August and retain SIT UAT evidence by 31 August', '31-Aug-2026', 'QA upload completed 26 August; current SIT result', 'In progress'),
  @('LA', 'Realign plan with Dennis Mendez and Transformation Team; schedule leadership session', '28-Aug-2026', 'Approved recovery path and accountable participants', 'Open'),
  @('AAC / Rule Manager', 'Confirm matching/tagging rules, sign-off owner and five-BU sequencing', '31-Aug-2026', 'Approved production IconDB names/IDs after restart; all five BU updates precede AAC E2E', 'Open'),
  @('', '', '', '', ''),
  @('PLAN VS ACTUAL', 'VARIANCE', 'OWNER / RESPONSE', '', ''),
  @('SIT readiness', 'Ahead of the former QA-first assumption: icon creation, region mapping and obsolescence behavior passed in Enovia SIT on 26 August.', 'Use SIT through 31 August; do not treat this as production evidence.', '', ''),
  @('FemCare sequence', 'QA upload completed 26 August and SIT scenarios moved into 26-31 August; former October SIT placement was stale.', 'FemCare / Michal / Jyoti retain scenario and UAT evidence.', '', ''),
  @('Production sequence', 'No acceleration: production remains 11 September deployment, 14-15 September validation, 16 September restart.', 'Tommy / Tripolina preserve the decision gate.', '', ''),
  @('', '', '', '', ''),
  @('OPEN DECISIONS / RISKS', 'ACCOUNTABLE OWNER', 'DUE', 'EVIDENCE REQUIRED', ''),
  @('QA refresh/no-refresh and effective baseline', 'Tommy / Enovia', 'Before 1-Sep-2026 switch', 'Written endpoint and baseline confirmation', ''),
  @('FC EU mapping and EECAR handling', 'Mubarak / Ewa / Enovia', '31-Aug-2026', 'Approve, remap or exclude each mapping; confirm EECAR scope', ''),
  @('OC EU acceptance and release route', 'Adrian / Anna / Iga / Steve', '31-Aug-2026', 'Approved names/IDs, curation, signer and CPM-672 route', ''),
  @('Claims Studio icon creation and curation ownership', 'Mateusz / Claims Family PO with BU Graphic Expert/BVE owners', '31-Aug-2026', 'Confirm creator by BU, curation guidance, high-resolution prerequisite and IconDB system-of-record handoff', ''),
  @('Restart authority and rollback criteria', 'Tommy / Tripolina', '16-Sep-2026', 'Passed production validation and retained rollback evidence', ''),
  @('', '', '', '', ''),
  @('EVIDENCE LOG', 'DATE', 'RESULT', '', ''),
  @('Jyoti SIT validation', '26-Aug-2026', 'Payload processed and icons created successfully in Enovia SIT; region mapping and obsolescence behavior passed. Production unchanged.', '', ''),
  @('FemCare QA upload', '26-Aug-2026', 'Existing CPS recovery row verified Done; scenarios and SIT UAT remain In Progress through 31 August.', '', ''),
  @('CPS and views', '26-Aug-2026', 'Six existing rows reconciled; all business/dependency views regenerated from Project schedule; no generic duplicate SIT block added.', '', ''),
  @('CPS validation', '26-Aug-2026', 'Package passed; zero formula errors, broken references or missing predecessors; 67 Late and 67 unique recovery rows in ordered one-to-one parity.', '', ''),
  @('', '', '', '', ''),
  @('MEETING PREPARATION', 'DISCUSS / DECIDE / LEAVE WITH', '', '', ''),
  @('SIT closeout', 'Bring created-record evidence and defect list; decide owners/dates for every remaining failure; leave with 31 August acceptance record.', '', '', ''),
  @('September production gate', 'Confirm 11 September deployment evidence, 14-15 September validation plan and 16 September restart authority; leave with named approvers and rollback criteria.', '', '', ''),
  @('Claims Studio', 'Decide Graphic Expert/BVE creation ownership, curation distribution and high-resolution handoff before IconDB ingestion.', '', '', ''),
  @('', '', '', '', ''),
  @('OUTLOOK DRAFT REGISTER', 'PURPOSE', 'STATE', '', ''),
  @('RE: Icon DB - Completed Fabric Care Template', 'FC EU SIT pack, EECAR and mapping confirmation through 31 August', 'Draft; 4 attachments; unsent/unsubmitted', '', ''),
  @('RE: Sample IconDB payload/ Action required: IconDB clean-state plan and FemCare SIT validation', 'Retain SIT evidence and preserve September production gates', 'Draft; 1 attachment; unsent/unsubmitted', '', ''),
  @('RE: Claims Studio - RTA Integration', 'Confirm BU creator, curation and high-resolution handoff ownership', 'Draft; 3 attachments; unsent/unsubmitted', '', ''),
  @('RE: Sample IconDB payload', 'Certificate/payload follow-up retained for review', 'Draft; 3 attachments; unsent/unsubmitted', '', ''),
  @('IconDB morning pre-read and weekly plan - 2026-08-26', 'Personal action plan; refreshed after PDCA and To Do reconciliation', 'Draft to Michal only; unsent/unsubmitted', '', ''),
  @('', '', '', '', ''),
  @('RUN HISTORY', 'COVERAGE / CHANGES', 'VALIDATION', '', ''),
  @('26-Aug-2026 morning control', '17-message/189-event snapshot plus live Outlook through late messages; Sent Items deduplication; weekly PDF and Jyoti conversation; live Jira; SharePoint CPS/PDCA; Outlook drafts; Microsoft To Do.', 'CPS passed read-only package, formula, dependency, view-link and 67/67 recovery checks. PDCA reopened read-only after save.', '', ''),
  @('Action register', 'Nine existing open IconDB tasks reviewed; overdue items carried forward without inferred completion. To Do and pre-read are reconciled after this PDCA save.', 'No task marked complete from email, attendance or elapsed date.', '', '')
)

function Release-ComObject {
  param($Value)
  if ($null -ne $Value -and [Runtime.InteropServices.Marshal]::IsComObject($Value)) {
    [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($Value)
  }
}

if ($Mode -eq 'Preview') {
  for ($index = 0; $index -lt $rows.Count; $index++) {
    [pscustomobject]@{ Row = $index + 1; A = $rows[$index][0]; B = $rows[$index][1]; C = $rows[$index][2]; D = $rows[$index][3]; E = $rows[$index][4] }
  }
  return
}

$excel = $null
$workbook = $null
$sheet = $null
try {
  $excel = New-Object -ComObject Excel.Application
  $excel.Visible = $false
  $excel.DisplayAlerts = $false
  $workbook = $excel.Workbooks.Open($WorkbookUrl, 0, $false)
  if ($workbook.ReadOnly) { throw 'The authoritative PDCA opened read-only; no changes were made.' }
  if ($workbook.Worksheets.Count -ne 1 -or $workbook.Worksheets.Item(1).Name -cne 'Current Control') {
    throw 'PDCA worksheet structure drifted; no changes were made.'
  }
  $sheet = $workbook.Worksheets.Item('Current Control')
  if (([string]$sheet.Cells.Item(1, 1).Text).Trim() -cne 'IconDB Weekly PDCA - Current Control') {
    throw 'PDCA title drifted; no changes were made.'
  }
  $sheet.Range('A1:E200').ClearContents()
  for ($row = 1; $row -le $rows.Count; $row++) {
    for ($column = 1; $column -le 5; $column++) {
      $sheet.Cells.Item($row, $column).Value2 = [string]$rows[$row - 1][$column - 1]
    }
  }
  $sheet.Range('A1:E200').WrapText = $true
  $sheet.Range('A1:E200').VerticalAlignment = -4160
  $sheet.Columns.Item(1).ColumnWidth = 38
  $sheet.Columns.Item(2).ColumnWidth = 54
  $sheet.Columns.Item(3).ColumnWidth = 42
  $sheet.Columns.Item(4).ColumnWidth = 36
  $sheet.Columns.Item(5).ColumnWidth = 22
  foreach ($headerRow in @(1, 5, 8, 15, 23, 28, 35, 41, 46, 53)) {
    $sheet.Range("A${headerRow}:E${headerRow}").Font.Bold = $true
  }
  $sheet.UsedRange.Rows.AutoFit()
  $workbook.Save()
  [pscustomobject]@{ Mode = $Mode; Saved = $workbook.Saved; Rows = $rows.Count; Sheet = $sheet.Name }
}
finally {
  if ($null -ne $workbook) { $workbook.Close($false) }
  Release-ComObject $sheet
  Release-ComObject $workbook
  if ($null -ne $excel) { $excel.Quit() }
  Release-ComObject $excel
  [GC]::Collect()
  [GC]::WaitForPendingFinalizers()
}
