# Power Automate IconDB CPS Daily Refresh

The active human-reviewed procedure is [IconDB Morning Run](icondb-morning-run.md). The unattended design in this document remains unapproved.

## Purpose And Authority

The authoritative CPS workbook is maintained in SharePoint:

`https://pgone.sharepoint.com/sites/RTARELEASE/Shared Documents/General/IconDB Integration/Project alignment docs/Icon DB CPS new standard.xlsx`

The authoritative weekly PDCA is in the same SharePoint folder:

`https://pgone.sharepoint.com/sites/RTARELEASE/Shared Documents/General/IconDB Integration/Project alignment docs/IconDB weekly PDCA.xlsx`

The current approved path is a human-reviewed direct SharePoint update: read live Jira through Jira MCP, reconcile it with approved mail/formal evidence and explicit owner corrections, preview the exact workbook changes, apply to the CPS master, reopen read-only for verification, and then update the SharePoint PDCA from the verified result. The Microsoft Jira connector is blocked by the environment's `S - Personal Productivity` DLP policy; do not retry it or route Jira MCP credentials through Power Automate. No SharePoint status list is part of the current workflow.

Do not update repository, OneDrive/Desktop, or `_bmad-output` CPS/PDCA copies as part of daily operation. They are historical evidence or templates only. If either SharePoint workbook is unavailable or read-only when a write is required, report that coverage as unavailable and leave the last verified SharePoint version unchanged.

The unattended Excel Online design below remains a future option only. It must not be enabled or used to create supporting SharePoint data structures without a new explicit user decision. Dates determine lateness but never completion. No process may update Jira, mail, calendar, or any workbook other than the two SharePoint paths above. The reviewed morning run may create Outlook drafts, but it must not send or submit them.

## Workbook Contract

The existing `Project schedule` layout is preserved:

| Column | Meaning |
|---|---|
| E | Task |
| F | Status: `Done`, `In Progress`, `Not Started`, or `Late` |
| J | Start |
| K | End |
| L | Estimated workdays |
| M | Calculated elapsed schedule days |

Run `scripts/Update-IconDBCpsSchedule.ts` once in `initialize` mode. It creates:

- `Automation Map` and table `IconDBCpsAutomationMap`
- `Automation Log` and table `IconDBCpsAutomationLog`

Initialization preserves all existing worksheets and schedule rows. SharePoint version history must be enabled before initialization.

## Automation Map Approval

Each active map row requires reviewed values. Do not let the flow invent estimates or dependencies.

| Field | Rule |
|---|---|
| Recovery ID | Stable unique ID, for example `R01` |
| Jira Key | One CPM issue, for example `CPM-648` |
| Exact CPS Task | Exact column E baseline text |
| Baseline Start | Existing column J date from the baseline row |
| Baseline End | Existing column K date from the baseline row |
| Estimated Workdays | Integer 1-260, approved before apply |
| Predecessor Recovery IDs | Semicolon-separated IDs; blank means start next working day |
| Dependency Mode | `ANY` uses earliest predecessor end; `ALL` uses latest |
| Active | `Yes` only after row review |
| Notes | Evidence and approval reference |

Task name plus baseline start and end form the exact-match identity. This distinguishes repeated task text across delivery phases and remains stable when recovery rows shift worksheet row numbers. Do not silently normalize punctuation, spelling, spacing, or dates.

A late baseline remains unchanged as historical evidence. The script inserts one row named `[Recovery <ID>] <task>` immediately below it. A repeated run updates in place and inserts no duplicate. Start and end formulas use the `Holidays` sheet:

```text
No predecessor: =WORKDAY(TODAY()-1,1,Holidays!$C:$C)
ANY:            =WORKDAY(MIN(K<row>,K<row>),1,Holidays!$C:$C)
ALL:            =WORKDAY(MAX(K<row>,K<row>),1,Holidays!$C:$C)
End:            =WORKDAY(J<row>,L<row>-1,Holidays!$C:$C)
```

## Connections

In Power Automate environment `Default-3596192b-fdf5-4e2c-a6fa-acb706c963d8`, create or select:

1. **Excel Online (Business)** using the user's delegated P&G account.
2. **SharePoint** using the user's delegated P&G account.

Connection creation and authentication are human-gated. Do not paste tokens into chat, flow expressions, scripts, workbooks, or repository files. The Jira connector was verified blocked by DLP on 2026-08-11; do not substitute Copilot MCP credentials, an unmanaged HTTP token, or a custom connector.

## Unapproved Optional Status List

Do not create this list for the current workflow. If unattended CPS refresh is explicitly approved in the future, one possible governed design is a SharePoint list named `IconDB CPS Status Source` with these columns:

| Column | Type | Rule |
|---|---|---|
| Title | Single line | Jira key; unique and required |
| Status Category | Choice | `To Do`, `In Progress`, `Done` |
| Status Name | Single line | Source status label for audit context |
| Evidence At | Date/time | Required; must be current within the approved freshness window |
| Evidence Source | Hyperlink or single line | Jira URL, approved export reference, or owner evidence |
| Approved By | Person or single line | Required accountable reviewer |
| Active | Yes/No | Only active records are consumed |

The daily flow is read-only against this list. Status maintenance is a separate governed action. For initial operation, require `Evidence At` within 24 hours; later changes to this freshness window require approval.

## Existing Snapshot Schedule

Keep `IconDB Morning Snapshot` as a separate flow. Do not change its approved production recurrence to accommodate this unapproved future design:

| Setting | Value |
|---|---|
| Frequency | Day |
| Interval | 1 |
| Time | 09:00 |
| Time zone | `Central European Standard Time` |
| Concurrency | 1 |

Do not add CPS actions to the snapshot flow. Its existing Outlook/OneDrive safety boundary remains unchanged.

## Create The CPS Flow

If unattended CPS refresh is explicitly approved in the future, create a scheduled cloud flow named `IconDB CPS Daily Refresh` with a Monday-Friday recurrence after the 09:00 snapshot has completed, in `Central European Standard Time`, and concurrency one. Approve the exact time against observed snapshot duration before enablement; do not let CPS refresh race the evidence snapshot.

### Collect Approved Map Rows

1. Use **Excel Online (Business) - List rows present in a table**.
2. Select the authoritative workbook and `IconDBCpsAutomationMap`.
3. Enable pagination and set a threshold above the reviewed map size, initially `500`.
4. Filter to `Active` equal to `Yes`.
5. Fail if zero active rows, any required map value is empty, a Recovery ID/Jira key repeats, or the connector reports truncation.

### Collect Approved Statuses

Use **SharePoint - Get items** against `IconDB CPS Status Source`, filter `Active eq 1`, enable pagination, and set a threshold above the controlled list size, initially `500`. Retain only:

- issue key
- status category: `To Do`, `In Progress`, or `Done`
- status name for audit context

Fail before calling the Office Script if any mapped key is missing, duplicated, inactive, older than 24 hours, lacks approval/evidence, or has no recognized status category. Set `statusSourceComplete` to `true` only after counts and unique keys exactly match the active map.

### Build Script Input

Compose a native JSON object and pass `string(<object>)` as `inputJson` to **Excel Online (Business) - Run script**:

```json
{
  "mode": "preview",
  "runId": "<flow run name>",
  "exportedAt": "<utcNow()>",
  "statusSourceComplete": true,
  "issues": [
    { "key": "CPM-648", "statusCategory": "In Progress", "statusName": "Approved for Prod Release" }
  ]
}
```

The Office Script returns JSON. Parse it and terminate as Failed unless `status` is `complete` and `errors` is empty.

## First Run And Approval Gate

1. Confirm SharePoint version history and record the current workbook version.
2. Run `initialize` once and verify the two control sheets/tables.
3. Populate the Automation Map from reviewed Jira/task mappings, estimates, and dependencies.
4. Run the CPS flow manually with script mode `preview`.
5. Review every proposed status change and recovery row with the owner. Preview must not change the schedule or log.
6. After explicit approval, change mode to `apply` and run manually once.
7. Run `preview` again. It must propose no duplicate recovery insertions.
8. Check formulas, formatting, merged ranges, and Gantt behavior through column `FA`.
9. Run Flow Checker; require zero errors. If this future flow is approved, schedule it only after the 09:00 evidence snapshot has completed and its duration is understood.

## Failure And Rollback

The flow fails without calling apply mode when status-list/map retrieval is incomplete or stale. The Office Script validates all mappings, exact task/start/end matches, duplicate recovery IDs, missing predecessors, cycles, allowed statuses, and formulas before writing.

If apply produces an unacceptable workbook version:

1. Turn off `IconDB CPS Daily Refresh`.
2. Restore the pre-run workbook version in SharePoint version history.
3. Correct the Automation Map or script in preview mode.
4. Repeat the approval gate before re-enabling.

Never delete the original late row or silently replace baseline dates. Do not call a partial or failed run current in the morning control.

## Daily Control Evidence

For the active reviewed workflow, the morning control reports the direct SharePoint CPS/PDCA update and its read-only validation. If the future unattended flow is approved, it also reads the newest `Automation Log` apply row and reports:

- run timestamp and status
- changed-cell count
- inserted recovery IDs
- warnings/errors

If the latest approved apply is missing, failed, or older than the current morning cycle, mark CPS coverage unavailable and continue with live Jira and repository evidence. Do not infer that the CPS is current.

The active reviewed run also records every created Outlook draft by subject and purpose in the SharePoint PDCA. Validate each item as saved in Drafts with `Sent=False` and `Submitted=False`; never call `Send()`.
