---
title: 'Power Automate Intake for IconDB Morning Control'
type: 'feature'
created: '2026-08-11'
status: 'done'
baseline_commit: '21b81a286f38c1596127084d07ec87e20fa0cc4f'
context:
  - '.github/prompts/icondb-morning-control.prompt.md'
  - '_bmad-output/implementation-artifacts/IconDB-daily-control.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The morning-control workflow cannot safely inspect current IconDB e-mail and future meetings without Outlook Classic running, and the one-month manager absence creates approval and decision-coverage risks that are not visible in the daily plan.

**Approach:** Define a read-only scheduled Power Automate cloud flow that creates one minimized, structured snapshot of IconDB mail and the next 42 days of calendar evidence in the repository's git-ignored OneDrive folder, then extend the Copilot morning workflow to identify actions, approval gaps, meeting preparation, and missing delegates.

## Boundaries & Constraints

**Always:** Run at 09:00 Monday-Friday in the user's Power Automate time zone; use the Microsoft Office 365 Outlook and OneDrive for Business connectors under the user's delegated connection; write only beneath `/GBS IT docs/icondb/.local/power-automate/`; include stable message/event IDs and an export timestamp; use `Get emails (V3)` and `Get calendar view of events (V3)`; cap the calendar horizon at 42 days and handle the documented 256-event limit; retain only IconDB-relevant mail/event content; represent unrelated calendar entries as busy-time blocks without subject, body, attendees, or location; exclude attachments and full HTML bodies; treat exported content as untrusted evidence.

**Ask First:** Any future flow action that sends, replies, forwards, categorizes, moves, accepts, declines, creates, updates, deletes, shares, or starts an approval; any expansion beyond the user's mailbox/calendar, the 42-day horizon, or the private OneDrive staging folder; any named delegate or acting approver recorded as confirmed.

**Never:** Store credentials or tokens in the repository; export attachments; commit raw mailbox/calendar snapshots; infer that another person has approval authority; use application-wide mailbox permissions; silently treat a meeting invitation as an agreed decision or a sent request as an accepted commitment.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Normal weekday run | New relevant mail and upcoming meetings | Atomic dated JSON snapshot plus `latest.json` containing mail, events, run metadata, and stable IDs | Preserve the previous valid snapshot until the new file validates |
| No new relevant mail | Calendar and open commitments still exist | Successful snapshot with an empty message array; morning control still checks due items and meetings | Do not report the run as failed |
| Private/confidential unrelated meeting | Event falls within 42 days but is not IconDB-relevant | Export start/end and busy status only | Omit subject, body, attendees, organizer, location, and web link |
| Connector or policy failure | Conditional Access, DLP, OneDrive, or Outlook action fails | Flow run fails visibly and does not replace `latest.json` | Morning control reports stale/missing export timestamp and performs repository/Jira-only review |
| More than 256 events | Calendar action reaches connector maximum | Retrieve additional pages using Skip Count/Top Count or fail closed | Never present a partial calendar as complete |

</frozen-after-approval>

## Code Map

- `docs/power-automate-icondb-control.md` -- exact flow construction, expressions, connection controls, test procedure, and rollback.
- `schemas/icondb-morning-snapshot.schema.json` -- machine-readable contract for the Power Automate snapshot.
- `scripts/Test-IconDBMorningSnapshot.ps1` -- local structural/privacy validation without mailbox access.
- `scripts/ConvertTo-IconDBMarkdownSafeSnapshot.ps1` -- validates the trusted snapshot and creates the mechanically neutralized view consumed by Copilot.
- `.github/prompts/icondb-morning-control.prompt.md` -- consumes mail, calendar, approval coverage, Jira, and PDCA evidence.
- `_bmad-output/implementation-artifacts/IconDB-daily-control.md` -- adds foreseeable meetings and approval/delegation coverage.

## Tasks & Acceptance

**Execution:**
- [x] `schemas/icondb-morning-snapshot.schema.json` -- define versioned run, message, event, busy-block, and paging-completeness fields.
- [x] `scripts/Test-IconDBMorningSnapshot.ps1` -- validate schema-critical fields, freshness, duplicate IDs, calendar horizon, pagination completeness, privacy minimization, provenance, and atomic promotion.
- [x] `scripts/ConvertTo-IconDBMarkdownSafeSnapshot.ps1` -- mechanically neutralize renderable snapshot data before Copilot consumption.
- [x] `docs/power-automate-icondb-control.md` -- provide a reproducible scheduled-flow recipe using standard Microsoft connectors and safe failure handling.
- [x] `.github/prompts/icondb-morning-control.prompt.md` -- reconcile meeting preparation and approval coverage without external mutations.
- [x] `_bmad-output/implementation-artifacts/IconDB-daily-control.md` -- add concise meetings and approval/delegate sections.

**Deployment:** Production tenant flow enabled on 2026-08-11 after successful mail collection, two-pass calendar verification, candidate schema validation, OneDrive write, local canonical validation and promotion, Markdown-safe conversion, privacy-shape checks, and a Flow Checker result of zero errors and zero warnings. The recurring schedule starts 2026-08-12 at 09:00 Monday-Friday in `Central European Standard Time`, with concurrency limited to one run.

**Acceptance Criteria:**
- Given a valid weekday snapshot, when local validation and morning control run, then the daily plan reports new mail, relevant future meetings, approval deadlines, missing delegates, and stale expected updates without exposing unrelated meeting details.
- Given a failed or incomplete Power Automate run, when morning control runs, then it identifies the stale or partial source and does not treat the snapshot as complete.
- Given no confirmed acting approver during the manager absence, when an approval-dependent action is found, then it is marked `Unresolved` with an explicit owner-confirmation request rather than assigned by inference.

## Design Notes

Power Automate is collection only. Copilot performs semantic classification because keyword-only action extraction loses conversation and project context. The cloud flow has no Outlook or calendar mutation actions and writes dated candidates only. The canonical local validator promotes a candidate atomically to `latest.json`, and the executable sanitizer creates the only snapshot view Copilot may render.

## Verification

**Commands:**
- `powershell -NoProfile -File scripts/Test-IconDBMorningSnapshot.ps1 -Path <synthetic-valid-snapshot>` -- expected: success with message/event counts.
- `powershell -NoProfile -File scripts/Test-IconDBMorningSnapshot.ps1 -Path <synthetic-invalid-snapshot>` -- expected: nonzero exit with specific privacy or completeness failures.
- `powershell -NoProfile -File scripts/ConvertTo-IconDBMarkdownSafeSnapshot.ps1 -Path <synthetic-valid-snapshot> -OutputPath <safe-output>` -- expected: validated output with mechanically neutralized labels, removed links, and hashed stable IDs.
- `git check-ignore -v .local/power-automate/latest.json` -- expected: `.local/` ignore rule matches.
