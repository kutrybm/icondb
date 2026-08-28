title: 'Refresh IconDB CPS and PDCA Management Pack'
type: 'feature'
created: '2026-08-10'
status: 'done'
baseline_commit: '21b81a286f38c1596127084d07ec87e20fa0cc4f'
superseded_by: 'docs/icondb-morning-run.md'
context:
  - '_bmad-output/planning-artifacts/IconDB-CPS-general-proposal.md'
  - '_bmad-output/implementation-artifacts/IconDB-weekly-PDCA.md'

> **Superseded operating rule (2026-08-13):** The requirement to keep repository and Desktop copies identical has been withdrawn by the user. This file remains historical implementation evidence. Current morning runs update only the CPS and PDCA in SharePoint `Project alignment docs`; `_bmad-output` and Desktop copies are not refreshed.

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The detailed CPS contains stale task statuses, while the simplified CPS and weekly PDCA are too text-heavy for rapid management review. This makes it difficult to distinguish completed work, lateness, the current critical path, and the decisions needed this week.

**Approach:** Reconcile the detailed schedule against its planned end dates and live Jira evidence, then redesign the simplified CPS as a visual timeline and the PDCA as a compact weekly dashboard with visual status summaries, concise card descriptions, and reusable update space.

## Boundaries & Constraints

**Always:** Preserve every existing worksheet in the detailed CPS; update only leaf-task status cells in column F and add/update concise current-state reporting without changing schedule dates or formulas. Treat 10-Aug-2026 as the status date. Preserve existing `Done`; promote a Jira-linked task to `Done` only when the live Jira status category is `Done`; mark any other unfinished leaf task `Late` when its planned end date is before 10-Aug-2026. Label proposed timeline dates as proposals. Keep repository and Desktop copies identical.

**Ask First:** Any change to agreed dates, owners, task names, dependencies, workbook formulas, or source workbook worksheets beyond status/dashboard presentation.

**Never:** Infer completion from an elapsed date, treat `Approved for Prod Release` as done, overwrite unrelated repository changes, use stale Jira exports, attach to or close the user's open Excel session, or remove the detailed legacy schedule.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|---------------|----------------------------|----------------|
| Completed card | Leaf task references a Jira issue whose category is `Done` | Column F is `Done` | Record the live Jira basis in the update summary |
| Overdue task | Non-done leaf task has a planned end before 10-Aug-2026 | Column F is `Late` | Preserve dates and owner; do not guess a replacement date |
| Future or undated task | Non-done leaf task ends on/after 10-Aug-2026 or has no usable end date | Existing status is retained | Exclude from automated late conversion |
| Summary row | Row has no task status or is a phase/group summary | Status remains untouched | Exclude from reconciliation counts |
| Visual management view | CPS/PDCA is opened without macros or Excel COM | Timeline, status visuals, and weekly update areas render from workbook cells | Fail generation if required sheets or source files are missing |

</frozen-after-approval>

## Code Map

- `_bmad-output/planning-artifacts/Icon-DB-CPS-updated-2026-08-10.xlsx` -- detailed legacy CPS; `Project schedule` column F is the controlled status surface.
- `_bmad-output/planning-artifacts/IconDB-CPS-general-proposal.xlsx` -- simplified management CPS to replace with a visual phase/timeline view.
- `_bmad-output/implementation-artifacts/IconDB-weekly-PDCA.xlsx` -- weekly dashboard, plan/check, update log, decisions, risks, and reusable reporting space.
- `_bmad-output/planning-artifacts/IconDB-CPS-general-proposal.md` -- management-level CPS content and phase definitions.
- `_bmad-output/implementation-artifacts/IconDB-weekly-PDCA.md` -- weekly outcomes, Jira baseline, decisions, risks, and update content.
- `scripts/build-management-excel-pack.js` -- temporary standalone generator/updater; deleted after successful validation.

## Tasks & Acceptance

**Execution:**
- [x] `_bmad-output/planning-artifacts/Icon-DB-CPS-updated-2026-08-10.xlsx` -- reconcile leaf statuses using schedule dates plus live Jira category evidence while preserving workbook structure.
- [x] `_bmad-output/planning-artifacts/IconDB-CPS-general-proposal.xlsx` -- create a simplified executive CPS with phase gates, a week-based visual Gantt, status legend, dependencies, and clearly marked proposed dates.
- [x] `_bmad-output/implementation-artifacts/IconDB-weekly-PDCA.xlsx` -- create a readable dashboard with KPI/status graphs, compact Plan/Check tables, one-sentence card descriptions, weekly trend, decisions/risks, and spacious update-log rows.
- [x] `scripts/build-management-excel-pack.js` -- implement standalone XLSX generation and direct detailed-workbook XML status updates without Excel COM; remove after validation.
- [x] Desktop management-pack copies -- refresh all three files and verify byte-identical SHA-256 hashes.

**Acceptance Criteria:**
- Given the detailed schedule, when reconciliation runs, then every Jira-category-`Done` leaf row is `Done`, every other overdue unfinished leaf row is `Late`, and future/undated or summary rows remain unchanged.
- Given the simplified CPS, when opened, then the current critical path and proposed weekly phase timing are understandable from the first two sheets without reading long paragraphs.
- Given the PDCA, when opened, then the weekly outcome, RAG/status distribution, due actions, named Jira cards with one-sentence descriptions, decisions, risks, and update space are visible through concise tables and visual bars.
- Given all three outputs, when reopened by an independent XLSX reader, then required sheets exist, workbook dimensions are non-empty, and repository/Desktop hashes match.

## Design Notes

Use cell-based visuals rather than embedded macros or Excel COM: colored timeline blocks for the Gantt, proportional status bars for graphs, frozen headers, restrained status colors, and wrapped concise text. Keep detail on supporting sheets; the first sheet in each proposed workbook must work as a one-screen management view at common laptop zoom.

## Verification

**Commands:**
- `node scripts/build-management-excel-pack.js` -- expected: all three workbooks generated/updated and copied without opening Excel.
- `node scripts/validate-management-excel-pack.js` -- expected: status invariants pass, required sheets and key labels exist, all workbooks reopen, and Desktop hashes match.

## Suggested Review Order

**Status Evidence**

- Start with the approved evidence and lateness rules before reviewing changed statuses.
  [spec:17](spec-refresh-cps-and-pdca-management-pack.md#L17)

- Verify reconciled statuses and the refresh result on the front two worksheets.
  [Icon-DB-CPS-updated-2026-08-10.xlsx](../planning-artifacts/Icon-DB-CPS-updated-2026-08-10.xlsx)

**Visual Critical Path**

- Review the dashboard first, then the proposed 14-week Gantt and gate ownership.
  [IconDB-CPS-general-proposal.xlsx](../planning-artifacts/IconDB-CPS-general-proposal.xlsx)

- Compare phase outcomes and evidence gates with the management source.
  [IconDB-CPS-general-proposal.md:17](../planning-artifacts/IconDB-CPS-general-proposal.md#L17)

**Weekly Operation**

- Review dashboard readability, Check descriptions, update space, decisions, risks, and trend bars.
  [IconDB-weekly-PDCA.xlsx](IconDB-weekly-PDCA.xlsx)

- Compare weekly actions and decision wording with the operating source.
  [IconDB-weekly-PDCA.md:10](IconDB-weekly-PDCA.md#L10)
