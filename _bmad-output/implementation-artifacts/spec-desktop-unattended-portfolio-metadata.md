---
title: 'Desktop-Unattended Portfolio Metadata Completion'
type: 'feature'
created: '2026-08-27'
status: 'done'
baseline_commit: '21b81a286f38c1596127084d07ec87e20fa0cc4f'
context:
  - '{project-root}/docs/power-automate-icondb-control.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Tenant DLP blocks a Graph-capable Power Automate connection, so the cloud prototype cannot collect the required draft and task metadata or emit a contract-complete projection. Manual reruns must still be eliminated without waiting for a policy exception.

**Approach:** Use desktop-unattended execution while the user is signed into Windows. Power Automate remains responsible for cloud mail/calendar collection; a local Outlook COM collector supplies privacy-minimized draft/task metadata, finalizes the projection, invokes the existing strict builder, and optionally promotes state under Task Scheduler without user clicks.

## Boundaries & Constraints

**Always:** Read only the default Outlook Drafts and Tasks folders; emit only schema-approved metadata; use opaque deterministic stable IDs; filter by the projection window; reconcile source and retained counts; reject inaccessible, duplicate, malformed, stale, or colliding data; write through temporary files and atomic rename; preserve the existing validator and state-promotion boundaries; keep the Power Automate prototype stopped between controlled tests.

**Ask First:** Enabling the recurring scheduled task; enabling the Power Automate schedule; changing the authoritative state location; changing the privacy contract; touching production flow `277e018f-85cd-4917-9ab4-94e2bffed162`.

**Never:** Read or persist message/task bodies, recipient identities, attachment names, Outlook Entry IDs, credentials, or tokens; bypass tenant DLP; mark coverage complete when Outlook is unavailable or an item cannot be inspected; overwrite a projection, candidate, or state file; run as a Windows service or while logged out; modify production.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|---------------|----------------------------|----------------|
| Complete metadata | Valid cloud projection and signed-in Outlook profile | Draft/task arrays and coverage are finalized, then the existing builder validates the candidate | N/A |
| No changed items | Valid window with no qualifying drafts/tasks | Empty arrays with truthful zero retained counts and complete source scans | Continue |
| Outlook unavailable | No interactive profile or COM failure | No finalized projection or candidate | Fail with stage-specific nonzero exit |
| Partial item read | Any required metadata property cannot be read | No output mutation | Fail closed and report item ordinal/type only |
| Duplicate identity | Two retained items produce one stable ID | No output mutation | Fail closed |
| Existing output | Finalized projection or candidate path already exists | Existing file remains byte-identical | Fail closed |

</frozen-after-approval>

## Code Map

- `scripts/Collect-OutlookPortfolioMetadata.py` -- privacy-minimized Drafts/Tasks COM collector and projection finalizer.
- `scripts/Test-OutlookPortfolioMetadata.py` -- synthetic adapter tests for filtering, status conversion, privacy, duplicates, and atomic output behavior.
- `scripts/Invoke-PortfolioEvidenceDesktop.ps1` -- lock-protected orchestration of collection, delta conversion, and optional promotion.
- `scripts/Register-PortfolioEvidenceDesktopTask.ps1` -- reviewed Task Scheduler registration entry point; registration remains human-gated.
- `scripts/ConvertTo-PortfolioEvidenceDelta.ps1` -- existing strict projection-to-delta builder.
- `docs/power-automate-icondb-control.md` -- hybrid architecture and operating instructions.

## Tasks & Acceptance

**Execution:**
- [x] `scripts/Collect-OutlookPortfolioMetadata.py` -- implement injectable Outlook-folder collection and atomic projection finalization.
- [x] `scripts/Test-OutlookPortfolioMetadata.py` -- exercise all matrix branches without Outlook or private test content.
- [x] `scripts/Invoke-PortfolioEvidenceDesktop.ps1` -- add exclusive lock, deterministic paths, logging, builder invocation, and optional promotion.
- [x] `scripts/Register-PortfolioEvidenceDesktopTask.ps1` -- define logon/periodic scheduling with `RunOnlyIfLoggedOn`; do not register automatically.
- [x] `docs/power-automate-icondb-control.md` -- document prerequisites, missed-run-at-logon behavior, failure recovery, and activation gates.

**Acceptance Criteria:**
- Given a valid incomplete cloud projection and available Outlook profile, when desktop orchestration runs, then exactly one validated complete projection and candidate are produced without content-bearing metadata.
- Given any failed collection or validation stage, when orchestration exits, then predecessor state and all final outputs remain unchanged.
- Given a successful isolated promotion, when the next run starts, then it uses the promoted `latest-state.json` generation.
- Given Task Scheduler registration parameters, when preview mode runs, then no task is created; creation requires explicit user approval.

## Spec Change Log

- 2026-08-27: Explicit approval received for first and incremental state promotion, recurring cloud activation, and signed-in-user Task Scheduler registration.
- 2026-08-27: Power Automate authoritative-state parsing, BOM-less state serialization, zero-change promotion, seven-trigger scheduler registration, and no-pending scheduled execution were runtime-proven. Cloud recurrence is active; desktop task is `Ready` with last result `0`.
- 2026-08-27: Evidence collection was aligned to the four business-control windows. Cloud recurrence is active at 07:15, 11:15, 13:15, and 14:15 on weekdays; desktop processing runs at :30 with a :45 retry for each window plus logon.

## Design Notes

Outlook COM `LastModificationTime`, `Subject`, `ConversationID`, recipient/attachment counts, task `Status`, and `DueDate` were runtime-proven on the signed-in profile without printing values. Stable IDs must hash the Outlook Entry ID with a type prefix so raw mailbox identifiers never leave process memory. The cloud artifact may report draft/task coverage as incomplete; only the local finalizer may change those flags to true after a complete scan.

## Verification

**Commands:**
- `.\.venv\Scripts\python.exe .\scripts\Test-OutlookPortfolioMetadata.py` -- all synthetic collector/finalizer cases pass.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Test-PortfolioEvidenceDeltaBuilder.ps1` -- existing builder suite remains green.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Test-PortfolioControlStateIntegration.ps1` -- state continuity and atomic promotion remain green.
- `git diff --check -- scripts docs _bmad-output/implementation-artifacts/spec-desktop-unattended-portfolio-metadata.md` -- no whitespace errors.

**Activation Evidence:**
- Cloud flow `Portfolio Evidence Delta` is `Started`, Monday-Friday at 07:15, 11:15, 13:15, and 14:15 `Central European Standard Time`, recurrence concurrency `1`, reading authoritative `latest-state.json`.
- Task `IconDB Portfolio Evidence Desktop` is `Ready`, uses an interactive limited principal, has eight weekday triggers plus logon, and its no-pending smoke run returned `0` without changing state.
- Final promoted run `6e4c1781-0bef-4403-9cf5-da7378c0353a` retained 67 thread heads and 307 calendar fingerprints after a validated zero-change delta.

## Suggested Review Order

**Fail-Closed Orchestration**

- Exclusive creation prevents overlapping desktop runs before any Outlook access.
  [Invoke-PortfolioEvidenceDesktop.ps1:55](../../scripts/Invoke-PortfolioEvidenceDesktop.ps1#L55)

- Child stages reserve output ownership and reuse integrated validated state promotion.
  [Invoke-PortfolioEvidenceDesktop.ps1:83](../../scripts/Invoke-PortfolioEvidenceDesktop.ps1#L83)

**Privacy And Completeness**

- Two identical full-folder scans reject live Outlook source drift.
  [Collect-OutlookPortfolioMetadata.py:163](../../scripts/Collect-OutlookPortfolioMetadata.py#L163)

- Cloud incompleteness becomes complete only after privacy-minimized local collection.
  [Collect-OutlookPortfolioMetadata.py:227](../../scripts/Collect-OutlookPortfolioMetadata.py#L227)

- Exclusive temporary creation and rename preserve append-only projection outputs.
  [Collect-OutlookPortfolioMetadata.py:275](../../scripts/Collect-OutlookPortfolioMetadata.py#L275)

**Activation Controls**

- Registration defaults to preview and requires an explicit switch.
  [Register-PortfolioEvidenceDesktopTask.ps1:50](../../scripts/Register-PortfolioEvidenceDesktopTask.ps1#L50)

- Interactive principal and dual triggers implement signed-in catch-up behavior.
  [Register-PortfolioEvidenceDesktopTask.ps1:59](../../scripts/Register-PortfolioEvidenceDesktopTask.ps1#L59)

- The runbook records the approved hybrid boundary and activation gates.
  [power-automate-icondb-control.md:424](../../docs/power-automate-icondb-control.md#L424)

**Regression Evidence**

- Synthetic tests cover privacy, statuses, boundaries, collisions, and source drift.
  [Test-OutlookPortfolioMetadata.py:95](../../scripts/Test-OutlookPortfolioMetadata.py#L95)
