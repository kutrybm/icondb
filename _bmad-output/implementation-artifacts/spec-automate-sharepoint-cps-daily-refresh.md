---
title: 'Automate SharePoint CPS Daily Refresh'
type: 'feature'
created: '2026-08-11'
status: 'in-progress'
baseline_commit: '21b81a286f38c1596127084d07ec87e20fa0cc4f'
context:
  - '_bmad-output/implementation-artifacts/spec-refresh-cps-and-pdca-management-pack.md'
  - '_bmad-output/planning-artifacts/IconDB-recovery-baseline-2026-08-10.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The authoritative CPS workbook in SharePoint has stale statuses, dates, and implicit dependencies, so the daily control cannot show a credible current schedule without manual Excel maintenance.

**Approach:** Add a versioned Office Script and a separate scheduled Power Automate flow that read approved Jira-keyed status evidence from a controlled SharePoint list, update leaf-task statuses, insert one auditable recovery row per late task, and calculate dependency-driven working-day dates. Move the existing morning snapshot to 07:30 and run the CPS refresh at 08:00 Central European time without requiring the user's computer or login session.

## Boundaries & Constraints

**Always:** Target only the supplied SharePoint workbook and `Project schedule`; preserve all existing sheets, baseline late rows, formulas, formatting, merged cells, and Gantt behavior; use `Done`, `In Progress`, `Not Started`, and `Late` in column F; use only complete, current, approved Jira-keyed status records from the controlled SharePoint list; classify a non-done task as `Late` when its planned end is before the run date; use `WORKDAY`/the workbook holiday calendar; make insertion idempotent; record run time, source status, changed cells, inserted recovery IDs, and errors on a dedicated automation log sheet; keep the snapshot and CPS flows separate with concurrency one.

**Ask First:** Creating or authenticating Excel Online or SharePoint connections; changing the authoritative workbook/list URL; writing estimates not present in the approved automation map; changing owners, task text, baseline dates, source status, or dependencies outside the approved map; enabling the production schedule after the first-run preview.

**Never:** Store credentials in the workbook/repository; bypass the `S - Personal Productivity` DLP policy with HTTP or API tokens; use this Copilot MCP session as an unattended source; infer `Done` from dates, release mail, or `Approved for Prod Release`; identify a repeated task by worksheet row number or task text alone; insert duplicate recovery rows; overwrite an original late row; update summary/group rows; run against the local workbook as if it were SharePoint; continue after partial/stale status retrieval, workbook lock, formula error, or missing task identity.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|---------------|---------------------------|----------------|
| Mapped leaf task | Jira status plus valid CPS dates | `Done`, `In Progress`, or `Not Started`; `Late` overrides non-done status after planned end | Log unmapped Jira statuses and leave row unchanged |
| Late baseline task | Non-done task with end before run date | Preserve baseline row as `Late`; insert one `[Recovery]` row directly below with approved estimate and dependency formulas | Missing estimate/dependency identity blocks insertion and is logged |
| Repeated daily run | Recovery row already exists | Update status/dates in place; do not insert another row | Duplicate recovery IDs fail the run before writes |
| Dependency alternatives | `ANY` predecessor group | Start at earliest valid predecessor end; `ALL` starts after latest predecessor end | Missing/circular predecessor fails validation |
| Status list or workbook unavailable | Connector failure, stale evidence, cap, lock, or malformed response | No workbook mutation; flow run fails visibly | Preserve prior workbook version and log only when safe |

</frozen-after-approval>

## Code Map

- `scripts/Update-IconDBCpsSchedule.ts` -- repository source for the Office Script that validates mappings, updates statuses, inserts recovery rows, repairs formulas/styles, and writes the run log.
- `scripts/Test-IconDBCpsSchedule.ps1` -- static/package checks for workbook invariants and Office Script fixtures without modifying SharePoint.
- `docs/power-automate-icondb-cps-refresh.md` -- exact Jira/Excel connection, flow, first-run preview, enablement, rollback, and 07:30/08:00 schedule procedure.
- `.github/prompts/icondb-morning-control.prompt.md` -- consumes the CPS refresh run status during daily control without treating a failed refresh as current.

## Tasks & Acceptance

**Execution:**
- [ ] `scripts/Update-IconDBCpsSchedule.ts` -- implement preview and apply modes, explicit status mapping, stable recovery IDs, `ANY`/`ALL` dependencies, approved estimates, working-day formulas, idempotency, and structured results.
- [ ] `scripts/Test-IconDBCpsSchedule.ps1` -- validate no summary-row updates, no duplicate recovery rows, formula/reference integrity, allowed statuses, deterministic reruns, and fail-closed cases against a disposable workbook copy.
- [ ] `docs/power-automate-icondb-cps-refresh.md` -- document SharePoint status-list plus Excel Online/Office Scripts setup, pagination/freshness/completeness checks, one-time preview/apply, separate flow schedules, version-history rollback, and connection ownership.
- [ ] `.github/prompts/icondb-morning-control.prompt.md` -- require CPS refresh freshness/result reconciliation in the daily report.
- [ ] Power Automate -- change `IconDB Morning Snapshot` to 07:30 and create `IconDB CPS Daily Refresh` at 08:00, both Monday-Friday, Central European Standard Time, concurrency one; enable CPS only after approved preview.

**Acceptance Criteria:**
- Given complete Jira input and the authoritative SharePoint workbook, when preview then apply runs, then only mapped leaf rows change, every inserted recovery row has one stable ID, and a second run inserts zero duplicates.
- Given a late task with an approved estimate, when refreshed, then the original remains `Late` and the recovery start/end are formulas derived from the approved `ANY`/`ALL` predecessors and working-day duration.
- Given Jira retrieval or workbook validation fails, when the flow runs, then no schedule mutation occurs and the run is visibly failed.
- Given the cloud schedules are enabled, when the user's computer is off, then snapshot collection starts at 07:30 and CPS refresh starts at 08:00 on weekdays in the configured time zone.

## Spec Change Log

## Design Notes

Office Script cannot estimate work dynamically. Initial estimates and dependencies are reviewed values stored on an `Automation Map` sheet; daily runs apply them deterministically. Suggested seed estimates are based on existing column L and task evidence, with explicit review for missing values. `ANY` uses the earliest predecessor end; `ALL` uses the latest. End date is `WORKDAY(Start, EstimatedDays-1, Holidays)` so a one-day task starts and ends on the same working day.

## Verification

**Commands:**
- `powershell -NoProfile -File scripts/Test-IconDBCpsSchedule.ps1 -Path <disposable-copy>` -- expected: all status, recovery, dependency, idempotency, and workbook-integrity checks pass.

**Manual checks:**
- Power Automate preview reports planned changes without workbook mutation; approved apply changes only those rows; SharePoint version history can restore the pre-run version.
- Flow checker reports zero errors and the next weekday triggers are 07:30 and 08:00 Central European time.
