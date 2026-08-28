---
title: 'Repair CPS Business Views and BU Rule Manager Dependencies'
type: 'bugfix'
created: '2026-08-13'
status: 'done'
baseline_commit: '21b81a286f38c1596127084d07ec87e20fa0cc4f'
context:
  - '_bmad-output/implementation-artifacts/IconDB-daily-control.md'
---

<frozen-after-approval reason="human-owned intent - do not modify unless human renegotiates">

## Intent

**Problem:** The LA view appears empty, Start hyperlinks are saved as broken formulas, the milestone chart has no numeric source, and IconDB/Enovia still use the legacy view format. A single shared Rule Manager action also hides BU-specific accountability and dependencies.

**Approach:** Make one generator own all eight role views and Start, resolve master rows by task identity/status instead of fixed row numbers, use native workbook hyperlinks and numeric chart data, and add one Rule Manager task under each top-level BU plan with BU-specific production predecessors. AAC E2E will depend on all five BU Rule Manager tasks.

## Boundaries & Constraints

**Always:** Keep `Project schedule` as the single master. Add separate Rule Manager tasks for FC NA, FC EU, OC EU, Fem EU, and LA. Place each task inside its BU block; make FC/OC/Fem tasks depend on that BU's production transition gate and make LA depend on all five LA stream production gates. Keep the historical shared recovery row 205 for 67/67 audit parity, but do not use it as the BU execution task. Rebuild FC NA, FC EU, OC EU, Fem EU, LA, AAC, IconDB, and Enovia in the same Delivered/Current plan format. Preserve formula links to the master and reopen read-only after save.

**Ask First:** Changing the five top-level BU interpretation, deleting historical baseline/recovery rows, or changing agreed production dates/statuses beyond formulas needed for the new dependency chain.

**Never:** Create a competing schedule, expose historical Late baselines in business views, use fixed master row numbers as durable identities, send Outlook mail, or overwrite unrelated repository changes.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|---------------|---------------------------|----------------|
| First apply | No BU-specific Rule Manager tasks | Insert exactly five tasks in their BU blocks and update AAC dependency | Fail closed when a BU anchor or production predecessor is missing/ambiguous |
| Reapply | Five tasks already exist | Update in place with no duplicate rows, charts, or links | Fail on duplicate task identities |
| View generation | Rows shift after insertion | Resolve rows from exact task identity and status; populate all eight views | Fail before save if a required view has no selected data |
| Start navigation | Eight generated views | Native internal hyperlinks open each target; chart uses numeric milestone counts | Reopen read-only and verify link subaddresses and chart series values |

</frozen-after-approval>

## Code Map

- `scripts/Update-IconDBCpsBuRuleManagerTasks.ps1` -- fail-closed, idempotent master insertion and AAC dependency migration.
- `scripts/Update-IconDBCpsBusinessViews.ps1` -- unified business-view and Start generator.
- `scripts/Update-IconDBCpsOuPlans.ps1` -- existing master updater whose row identities must remain compatible after insertions.
- `scripts/Test-IconDBCpsSchedule.ps1` -- structural parity validator.

## Tasks & Acceptance

**Execution:**
- [x] `scripts/Update-IconDBCpsBuRuleManagerTasks.ps1` -- insert/update five BU Rule Manager tasks and make AAC E2E depend on all five.
- [x] `scripts/Update-IconDBCpsBusinessViews.ps1` -- replace fixed row maps, add IconDB/Enovia, repair LA, native hyperlinks, and numeric chart data.
- [x] `scripts/Update-IconDBCpsOuPlans.ps1` -- resolve controlled updates by task identity so row insertion cannot redirect later updates.
- [x] SharePoint workbook -- preview, apply master migration, apply views, reopen read-only, and validate invariants.

**Acceptance Criteria:**
- Given the authoritative workbook, when migration is applied twice, then exactly five BU Rule Manager tasks exist in their correct BU blocks and AAC E2E depends on all five without duplicates.
- Given any inserted-row shifts, when views regenerate, then LA contains populated task data and all eight views use the same Delivered/Current plan schema with no visible Late rows.
- Given Start, when opened, then each native hyperlink targets the correct view and the chart displays numeric milestone completion.
- Given the saved workbook, when reopened read-only, then `Project schedule` remains authoritative, formulas point to valid master tasks, and late/recovery parity remains 67/67.

## Spec Change Log

## Design Notes

The master migration must insert from the bottom upward and avoid copying merged column B. Task names are durable identities; row numbers are runtime outputs only. The Start chart must use numeric `Value2` cells and set `PlotVisibleOnly` appropriately if its source column is hidden.

## Verification

**Commands:**
- `& '.\scripts\Update-IconDBCpsBuRuleManagerTasks.ps1' -Mode Preview` -- expected: five unambiguous insertions or five existing tasks.
- `& '.\scripts\Update-IconDBCpsBusinessViews.ps1' -Mode Preview` -- expected: eight non-empty view selections and resolved BU Rule Manager rows.
- Apply both scripts, reopen the SharePoint workbook read-only, and run deterministic COM checks -- expected: working links/chart, populated LA, uniform schemas, five BU tasks, valid AAC predecessors, and 67/67 parity.

## Suggested Review Order

**Unified Entry Point**

- Delegates the public command to the task-identity-driven generator.
  [Update-IconDBCpsBusinessViews.ps1:9](../../scripts/Update-IconDBCpsBusinessViews.ps1#L9)

**Master Dependencies**

- Defines five BU-owned Rule Manager tasks and their production gates.
  [Update-IconDBCpsBuRuleManagerTasks.ps1:13](../../scripts/Update-IconDBCpsBuRuleManagerTasks.ps1#L13)

- Resolves LA's multi-stream production predecessors explicitly.
  [Update-IconDBCpsBuRuleManagerTasks.ps1:81](../../scripts/Update-IconDBCpsBuRuleManagerTasks.ps1#L81)

- Inserts bottom-up and identifies rows before copying surrounding formatting.
  [Update-IconDBCpsBuRuleManagerTasks.ps1:158](../../scripts/Update-IconDBCpsBuRuleManagerTasks.ps1#L158)

- Makes AAC E2E wait for all five BU Rule Manager tasks.
  [Update-IconDBCpsBuRuleManagerTasks.ps1:197](../../scripts/Update-IconDBCpsBuRuleManagerTasks.ps1#L197)

**Views And Navigation**

- Declares one consistent schema for all eight role views.
  [Update-IconDBCpsBusinessViewsCore.ps1:19](../../scripts/Update-IconDBCpsBusinessViewsCore.ps1#L19)

- Selects live master rows by task identity, owner, and current status.
  [Update-IconDBCpsBusinessViewsCore.ps1:141](../../scripts/Update-IconDBCpsBusinessViewsCore.ps1#L141)

- Creates native internal hyperlinks that survive save and reopen.
  [Update-IconDBCpsBusinessViewsCore.ps1:311](../../scripts/Update-IconDBCpsBusinessViewsCore.ps1#L311)

- Feeds the dashboard chart with explicit numeric action counts.
  [Update-IconDBCpsBusinessViewsCore.ps1:322](../../scripts/Update-IconDBCpsBusinessViewsCore.ps1#L322)

**Future Update Safety**

- Resolves shifted OU rows by current task identity.
  [Update-IconDBCpsOuPlans.ps1:68](../../scripts/Update-IconDBCpsOuPlans.ps1#L68)

- Preserves Excel-adjusted formulas after master row insertion.
  [Update-IconDBCpsOuPlans.ps1:83](../../scripts/Update-IconDBCpsOuPlans.ps1#L83)
